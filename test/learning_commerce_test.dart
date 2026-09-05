import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_access.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_commerce.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_offering.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled seven offerings map one-to-one to logical entitlements', () async {
    final offerings = await LearningOfferingCatalog.loadBundled();
    final catalog = LearningCommerceCatalog.fromOfferings(offerings.offerings);

    expect(catalog.bindings, hasLength(7));
    expect(catalog.productKeys, {
      'learning_pack_boletes_pores',
      'learning_pack_gilled_mushrooms',
      'learning_pack_amanitas_lookalikes',
      'learning_pack_russulas_milkcaps',
      'learning_pack_brackets_wood_decay',
      'learning_pack_small_brown_mushrooms',
      'learning_pack_field_microscopy_spores',
    });
    expect(
      catalog.bindingForProduct('learning_pack_boletes_pores')?.entitlementKey,
      'learning.specialist.boletes-pores',
    );
  });

  test('unconfigured commerce never exposes prices or launches purchase', () async {
    final coordinator = _coordinator(configured: false);

    expect(await coordinator.loadQuotes(), isEmpty);
    expect(
      () => coordinator.purchase('learning_pack_boletes_pores'),
      throwsA(isA<StateError>()),
    );
  });

  test('provider supplied localized price is returned without content fallback', () async {
    final provider = _Provider(
      configured: true,
      quotes: const {
        'learning_pack_boletes_pores': LearningProductQuote(
          productKey: 'learning_pack_boletes_pores',
          displayPrice: '€ 2,99',
          currencyCode: 'EUR',
        ),
      },
    );
    final coordinator = _coordinator(provider: provider);

    final quotes = await coordinator.loadQuotes();
    final quote = quotes.values.single;

    expect(quote.displayPrice, '€ 2,99');
    expect(quote.currencyCode, 'EUR');
  });

  test('provider cannot inject an unknown product quote', () async {
    final provider = _Provider(
      configured: true,
      quotes: const {
        'unknown': LearningProductQuote(
          productKey: 'unknown',
          displayPrice: '€ 0,01',
          currencyCode: 'EUR',
        ),
      },
    );

    expect(
      () => _coordinator(provider: provider).loadQuotes(),
      throwsA(isA<StateError>()),
    );
  });

  test('purchase only accepts a known logical product key', () async {
    final provider = _Provider(configured: true);
    final coordinator = _coordinator(provider: provider);

    await coordinator.purchase('learning_pack_boletes_pores');
    expect(provider.purchases, ['learning_pack_boletes_pores']);
    expect(
      () => coordinator.purchase('not-a-learning-product'),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('restore delegates to configured provider', () async {
    final provider = _Provider(configured: true);

    await _coordinator(provider: provider).restorePurchases();

    expect(provider.restoreCalls, 1);
  });

  test('pending evidence never reaches verifier', () async {
    final verifier = _Verifier();
    final coordinator = _coordinator(verifier: verifier);

    expect(
      () => coordinator.verifyEvidence(
        const LearningPurchaseEvidence(
          provider: LearningCommerceProvider.googlePlay,
          productKey: 'learning_pack_boletes_pores',
          transactionId: 'order-1',
          verificationPayload: 'signed-payload',
          state: LearningPurchaseState.pending,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(verifier.evidence, isEmpty);
  });

  test('completed evidence must verify to matching product and entitlement', () async {
    final verifier = _Verifier(
      result: const VerifiedLearningPurchase(
        productKey: 'learning_pack_boletes_pores',
        entitlementKey: 'learning.specialist.boletes-pores',
        active: true,
      ),
    );
    final coordinator = _coordinator(verifier: verifier);
    const evidence = LearningPurchaseEvidence(
      provider: LearningCommerceProvider.appStore,
      productKey: 'learning_pack_boletes_pores',
      transactionId: 'transaction-1',
      verificationPayload: 'signed-payload',
      state: LearningPurchaseState.purchased,
    );

    final verified = await coordinator.verifyEvidence(evidence);

    expect(verified.active, isTrue);
    expect(verifier.evidence, [evidence]);
  });

  test('mismatched verifier result is rejected', () async {
    final verifier = _Verifier(
      result: const VerifiedLearningPurchase(
        productKey: 'learning_pack_boletes_pores',
        entitlementKey: 'learning.specialist.gilled-mushrooms',
        active: true,
      ),
    );

    expect(
      () => _coordinator(verifier: verifier).verifyEvidence(
        const LearningPurchaseEvidence(
          provider: LearningCommerceProvider.googlePlay,
          productKey: 'learning_pack_boletes_pores',
          transactionId: 'order-1',
          verificationPayload: 'signed-payload',
          state: LearningPurchaseState.restored,
        ),
      ),
      throwsA(isA<StateError>()),
    );
  });
}

LearningCommerceCoordinator _coordinator({
  bool configured = true,
  _Provider? provider,
  _Verifier? verifier,
}) {
  final offerings = LearningOfferingCatalog.fromDecoded({
    'catalog_version': 1,
    'offerings': [
      _offering(
        packageKey: 'boletes-pores',
        productKey: 'learning_pack_boletes_pores',
        entitlementKey: 'learning.specialist.boletes-pores',
      ),
      _offering(
        packageKey: 'gilled-mushrooms',
        productKey: 'learning_pack_gilled_mushrooms',
        entitlementKey: 'learning.specialist.gilled-mushrooms',
      ),
    ],
  });
  return LearningCommerceCoordinator(
    catalog: LearningCommerceCatalog.fromOfferings(offerings.offerings),
    provider: provider ?? _Provider(configured: configured),
    verifier: verifier ?? _Verifier(),
  );
}

Map<String, dynamic> _offering({
  required String packageKey,
  required String productKey,
  required String entitlementKey,
}) =>
    {
      'package_key': packageKey,
      'course_key': 'specialist-$packageKey',
      'entitlement_key': entitlementKey,
      'product_key': productKey,
      'group_key': 'specializations',
      'sort_order': 1,
      'texts': {
        'nl': {'title': packageKey, 'summary': 'Samenvatting'},
        'en': {'title': packageKey, 'summary': 'Summary'},
        'de': {'title': packageKey, 'summary': 'Zusammenfassung'},
      },
    };

class _Provider implements LearningCommerceProviderAdapter {
  _Provider({
    required this.configured,
    this.quotes = const <String, LearningProductQuote>{},
  });

  @override
  final bool configured;
  final Map<String, LearningProductQuote> quotes;
  final List<String> purchases = [];
  int restoreCalls = 0;

  @override
  Stream<LearningPurchaseEvidence> get purchaseUpdates =>
      const Stream<LearningPurchaseEvidence>.empty();

  @override
  Future<Map<String, LearningProductQuote>> loadProductQuotes(
    Set<String> productKeys,
  ) async =>
      quotes;

  @override
  Future<void> purchase(String productKey) async {
    purchases.add(productKey);
  }

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
  }
}

class _Verifier implements LearningPurchaseVerifier {
  _Verifier({this.result});

  final VerifiedLearningPurchase? result;
  final List<LearningPurchaseEvidence> evidence = [];

  @override
  Future<VerifiedLearningPurchase> verify(
    LearningPurchaseEvidence purchaseEvidence,
  ) async {
    evidence.add(purchaseEvidence);
    return result ??
        VerifiedLearningPurchase(
          productKey: purchaseEvidence.productKey,
          entitlementKey: purchaseEvidence.productKey ==
                  'learning_pack_boletes_pores'
              ? 'learning.specialist.boletes-pores'
              : 'learning.specialist.gilled-mushrooms',
          active: true,
        );
  }

  @override
  Future<EntitlementSnapshot> restoreVerifiedEntitlements() async =>
      EntitlementSnapshot(const <String>[]);
}
