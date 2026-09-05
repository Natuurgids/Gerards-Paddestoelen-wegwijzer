import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_commerce.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_in_app_purchase.dart';

void main() {
  const logicalProduct = 'learning_pack_boletes_pores';
  const storeProduct = 'nl.natuurgids.learning.boletes_pores';

  LearningInAppPurchaseAdapter adapter(_Client client) =>
      LearningInAppPurchaseAdapter(
        providerType: LearningCommerceProvider.googlePlay,
        productIds: LearningStoreProductIds(
          provider: LearningCommerceProvider.googlePlay,
          productIds: const {logicalProduct: storeProduct},
        ),
        client: client,
      );

  test('store product IDs must be unique and provider-specific', () {
    expect(
      () => LearningStoreProductIds(
        provider: LearningCommerceProvider.googlePlay,
        productIds: const {'a': 'same', 'b': 'same'},
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => LearningInAppPurchaseAdapter(
        providerType: LearningCommerceProvider.appStore,
        productIds: LearningStoreProductIds(
          provider: LearningCommerceProvider.googlePlay,
          productIds: const {'a': 'store.a'},
        ),
        client: _Client(),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('provider-formatted price maps back to logical product key', () async {
    final client = _Client(
      products: [_product(storeProduct, price: '€ 2,99', currency: 'EUR')],
    );

    final quotes = await adapter(client).loadProductQuotes({logicalProduct});

    expect(quotes.keys, [logicalProduct]);
    expect(quotes[logicalProduct]?.displayPrice, '€ 2,99');
    expect(quotes[logicalProduct]?.currencyCode, 'EUR');
    expect(client.queries.single, {storeProduct});
  });

  test('missing store product produces no fallback quote', () async {
    final client = _Client(products: const []);

    final quotes = await adapter(client).loadProductQuotes({logicalProduct});

    expect(quotes, isEmpty);
  });

  test('unmapped logical product fails before store query', () async {
    final client = _Client();

    await expectLater(
      adapter(client).loadProductQuotes({'unknown'}),
      throwsA(isA<StateError>()),
    );
    expect(client.queries, isEmpty);
  });

  test('purchase queries exact product and launches non-consumable flow', () async {
    final client = _Client(products: [_product(storeProduct)]);

    await adapter(client).purchase(logicalProduct);

    expect(client.queries, [{storeProduct}]);
    expect(client.purchasedProductIds, [storeProduct]);
  });

  test('purchase fails when store declines to launch flow', () async {
    final client = _Client(
      products: [_product(storeProduct)],
      purchaseLaunchResult: false,
    );

    await expectLater(
      adapter(client).purchase(logicalProduct),
      throwsA(isA<StateError>()),
    );
  });

  test('purchase stream maps known evidence and ignores unknown products', () async {
    final client = _Client();
    final storeAdapter = adapter(client);
    final updates = storeAdapter.purchaseUpdates.take(2).toList();

    client.emit([
      _purchase(
        storeProduct,
        PurchaseStatus.pending,
        purchaseId: null,
        payload: '',
      ),
      _purchase('other.product', PurchaseStatus.purchased),
    ]);
    client.emit([
      _purchase(
        storeProduct,
        PurchaseStatus.restored,
        purchaseId: null,
        payload: 'server-token',
      ),
    ]);

    final evidence = await updates;

    expect(evidence, hasLength(2));
    expect(evidence.first.state, LearningPurchaseState.pending);
    expect(evidence.first.transactionId, isEmpty);
    expect(evidence.last.state, LearningPurchaseState.restored);
    expect(evidence.last.verificationPayload, 'server-token');
  });

  test('verified completion acknowledges only retained exact evidence', () async {
    final client = _Client();
    final storeAdapter = adapter(client);
    final updates = storeAdapter.purchaseUpdates.take(1).toList();
    final purchase = _purchase(
      storeProduct,
      PurchaseStatus.purchased,
      payload: 'server-token',
      pendingComplete: true,
    );

    client.emit([purchase]);
    final evidence = (await updates).single;
    const reconstructed = LearningPurchaseEvidence(
      provider: LearningCommerceProvider.googlePlay,
      productKey: logicalProduct,
      transactionId: 'purchase-1',
      verificationPayload: 'server-token',
      state: LearningPurchaseState.purchased,
    );

    await storeAdapter.completeVerifiedPurchase(reconstructed);
    expect(client.completed, isEmpty);

    await storeAdapter.completeVerifiedPurchase(evidence);
    expect(client.completed, [purchase]);

    await storeAdapter.completeVerifiedPurchase(evidence);
    expect(client.completed, [purchase]);
  });

  test('restore requires available configured store', () async {
    final client = _Client();

    await adapter(client).restorePurchases();

    expect(client.restoreCalls, 1);
  });
}

ProductDetails _product(
  String id, {
  String price = r'$2.99',
  String currency = 'USD',
}) =>
    ProductDetails(
      id: id,
      title: 'Course',
      description: 'Specialist course',
      price: price,
      rawPrice: 2.99,
      currencyCode: currency,
    );

PurchaseDetails _purchase(
  String productId,
  PurchaseStatus status, {
  String? purchaseId = 'purchase-1',
  String payload = 'server-token',
  bool pendingComplete = false,
}) {
  final purchase = PurchaseDetails(
    purchaseID: purchaseId,
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local-token',
      serverVerificationData: payload,
      source: 'google_play',
    ),
    transactionDate: '1',
    status: status,
  );
  purchase.pendingCompletePurchase = pendingComplete;
  return purchase;
}

class _Client implements LearningInAppPurchaseClient {
  _Client({
    this.available = true,
    this.products = const [],
    this.purchaseLaunchResult = true,
  });

  final bool available;
  final List<ProductDetails> products;
  final bool purchaseLaunchResult;
  final StreamController<List<PurchaseDetails>> _controller =
      StreamController<List<PurchaseDetails>>.broadcast();
  final List<Set<String>> queries = [];
  final List<String> purchasedProductIds = [];
  final List<PurchaseDetails> completed = [];
  int restoreCalls = 0;

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async {
    queries.add(Set<String>.from(identifiers));
    return ProductDetailsResponse(
      productDetails: products.where((item) => identifiers.contains(item.id)).toList(),
      notFoundIDs: identifiers.where(
        (id) => !products.any((item) => item.id == id),
      ).toList(),
    );
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    purchasedProductIds.add(purchaseParam.productDetails.id);
    return purchaseLaunchResult;
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }
}
