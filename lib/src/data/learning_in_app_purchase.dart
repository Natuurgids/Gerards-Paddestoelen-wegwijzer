import 'dart:convert';

import 'package:in_app_purchase/in_app_purchase.dart';

import 'learning_commerce.dart';

const googlePlayLearningProductIds = String.fromEnvironment(
  'LEARNING_GOOGLE_PLAY_PRODUCT_IDS',
);
const appStoreLearningProductIds = String.fromEnvironment(
  'LEARNING_APP_STORE_PRODUCT_IDS',
);

class LearningStoreProductIds {
  LearningStoreProductIds({
    required this.provider,
    required Map<String, String> productIds,
  }) : productIds = Map.unmodifiable(_validate(productIds));

  factory LearningStoreProductIds.fromEnvironment(
    LearningCommerceProvider provider,
  ) {
    final encoded = switch (provider) {
      LearningCommerceProvider.googlePlay => googlePlayLearningProductIds,
      LearningCommerceProvider.appStore => appStoreLearningProductIds,
    };
    if (encoded.trim().isEmpty) {
      return LearningStoreProductIds(
        provider: provider,
        productIds: const <String, String>{},
      );
    }
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Learning store product mapping must be a JSON object');
    }
    return LearningStoreProductIds(
      provider: provider,
      productIds: decoded.map(
        (key, value) => MapEntry(key, value is String ? value : ''),
      ),
    );
  }

  final LearningCommerceProvider provider;
  final Map<String, String> productIds;

  bool get configured => productIds.isNotEmpty;

  String? storeIdFor(String productKey) => productIds[productKey];

  String? productKeyFor(String storeProductId) {
    for (final entry in productIds.entries) {
      if (entry.value == storeProductId) return entry.key;
    }
    return null;
  }

  static Map<String, String> _validate(Map<String, String> productIds) {
    final validated = <String, String>{};
    final storeIds = <String>{};
    for (final entry in productIds.entries) {
      final logical = entry.key.trim();
      final store = entry.value.trim();
      if (logical.isEmpty || store.isEmpty) {
        throw const FormatException('Learning store product IDs must be non-empty');
      }
      if (!storeIds.add(store)) {
        throw const FormatException('Learning store product IDs must be unique');
      }
      validated[logical] = store;
    }
    return validated;
  }
}

abstract interface class LearningInAppPurchaseClient {
  Stream<List<PurchaseDetails>> get purchaseStream;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);

  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam});

  Future<void> restorePurchases();

  Future<void> completePurchase(PurchaseDetails purchase);
}

class FlutterInAppPurchaseClient implements LearningInAppPurchaseClient {
  FlutterInAppPurchaseClient([InAppPurchase? instance])
      : _instance = instance ?? InAppPurchase.instance;

  final InAppPurchase _instance;

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _instance.purchaseStream;

  @override
  Future<bool> isAvailable() => _instance.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      _instance.queryProductDetails(identifiers);

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      _instance.buyNonConsumable(purchaseParam: purchaseParam);

  @override
  Future<void> restorePurchases() => _instance.restorePurchases();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      _instance.completePurchase(purchase);
}

class LearningInAppPurchaseAdapter implements LearningCommerceProviderAdapter {
  LearningInAppPurchaseAdapter({
    required this.providerType,
    required LearningStoreProductIds productIds,
    LearningInAppPurchaseClient? client,
  })  : _productIds = productIds,
        _client = client ?? FlutterInAppPurchaseClient() {
    if (_productIds.provider != providerType) {
      throw ArgumentError('Store product mapping provider does not match adapter');
    }
  }

  final LearningCommerceProvider providerType;
  final LearningStoreProductIds _productIds;
  final LearningInAppPurchaseClient _client;
  final Expando<PurchaseDetails> _pendingCompletion =
      Expando<PurchaseDetails>('learning-purchase');

  @override
  bool get configured => _productIds.configured;

  @override
  Stream<LearningPurchaseEvidence> get purchaseUpdates =>
      _client.purchaseStream.expand(_mapPurchaseBatch);

  @override
  Future<Map<String, LearningProductQuote>> loadProductQuotes(
    Set<String> productKeys,
  ) async {
    _requireConfiguredKeys(productKeys);
    if (!await _client.isAvailable()) {
      throw StateError('In-app purchase store is unavailable');
    }
    final storeIds = productKeys.map(_requiredStoreId).toSet();
    final response = await _client.queryProductDetails(storeIds);
    if (response.error != null) {
      throw StateError('Store product query failed: ${response.error!.code}');
    }

    final quotes = <String, LearningProductQuote>{};
    for (final details in response.productDetails) {
      final productKey = _productIds.productKeyFor(details.id);
      if (productKey == null || !productKeys.contains(productKey)) continue;
      if (quotes.containsKey(productKey)) {
        throw StateError('Store returned duplicate learning product details');
      }
      quotes[productKey] = LearningProductQuote(
        productKey: productKey,
        displayPrice: details.price,
        currencyCode: details.currencyCode,
      );
    }
    return Map.unmodifiable(quotes);
  }

  @override
  Future<void> purchase(String productKey) async {
    final storeId = _requiredStoreId(productKey);
    if (!await _client.isAvailable()) {
      throw StateError('In-app purchase store is unavailable');
    }
    final response = await _client.queryProductDetails(<String>{storeId});
    if (response.error != null) {
      throw StateError('Store product query failed: ${response.error!.code}');
    }
    final matches = response.productDetails.where((item) => item.id == storeId).toList();
    if (matches.length != 1) {
      throw StateError('Store product is unavailable: $productKey');
    }
    final launched = await _client.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: matches.single),
    );
    if (!launched) {
      throw StateError('Store did not launch the purchase flow');
    }
  }

  @override
  Future<void> restorePurchases() async {
    if (!configured) {
      throw StateError('Learning store product IDs are not configured');
    }
    if (!await _client.isAvailable()) {
      throw StateError('In-app purchase store is unavailable');
    }
    await _client.restorePurchases();
  }

  @override
  Future<void> completeVerifiedPurchase(LearningPurchaseEvidence evidence) async {
    final purchase = _pendingCompletion[evidence];
    if (purchase == null) return;
    if (purchase.pendingCompletePurchase) {
      await _client.completePurchase(purchase);
    }
    _pendingCompletion[evidence] = null;
  }

  Iterable<LearningPurchaseEvidence> _mapPurchaseBatch(
    List<PurchaseDetails> purchases,
  ) sync* {
    for (final purchase in purchases) {
      final productKey = _productIds.productKeyFor(purchase.productID);
      if (productKey == null) continue;
      final evidence = LearningPurchaseEvidence(
        provider: providerType,
        productKey: productKey,
        transactionId: purchase.purchaseID ?? '',
        verificationPayload: purchase.verificationData.serverVerificationData,
        state: _mapStatus(purchase.status),
      );
      if (purchase.pendingCompletePurchase) {
        _pendingCompletion[evidence] = purchase;
      }
      yield evidence;
    }
  }

  LearningPurchaseState _mapStatus(PurchaseStatus status) => switch (status) {
        PurchaseStatus.pending => LearningPurchaseState.pending,
        PurchaseStatus.purchased => LearningPurchaseState.purchased,
        PurchaseStatus.restored => LearningPurchaseState.restored,
        PurchaseStatus.canceled => LearningPurchaseState.canceled,
        PurchaseStatus.error => LearningPurchaseState.failed,
      };

  void _requireConfiguredKeys(Set<String> productKeys) {
    if (!configured) {
      throw StateError('Learning store product IDs are not configured');
    }
    for (final key in productKeys) {
      _requiredStoreId(key);
    }
  }

  String _requiredStoreId(String productKey) {
    final id = _productIds.storeIdFor(productKey);
    if (id == null) {
      throw StateError('No store product ID configured for $productKey');
    }
    return id;
  }
}
