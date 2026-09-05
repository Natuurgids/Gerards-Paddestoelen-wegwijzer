import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_commerce.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_commerce_bootstrap.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_in_app_purchase.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_offering.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseSchema.create(db);
  });

  tearDown(() => db.close());

  Future<LearningCommerceBootstrapResult> bootstrap({
    LearningCommerceProvider? provider = LearningCommerceProvider.googlePlay,
    bool withSession = true,
    Map<String, String>? productIds,
    String verifyUrl = 'https://commerce.example.test/verify',
    String entitlementsUrl = 'https://commerce.example.test/entitlements',
  }) =>
      LearningCommerceBootstrap.fromEnvironment(
        platformProvider: () => provider,
        sessionHeadersProvider:
            withSession ? () async => const {'Authorization': 'Bearer test'} : null,
        offeringLoader: () async => LearningOfferingCatalog([_offering]),
        databaseProvider: () async => db,
        productIds: LearningStoreProductIds(
          provider: provider ?? LearningCommerceProvider.googlePlay,
          productIds: productIds ??
              const {'learning_pack_boletes_pores': 'store.boletes'},
        ),
        purchaseClient: const _PurchaseClient(),
        verifyUrl: verifyUrl,
        entitlementsUrl: entitlementsUrl,
      );

  test('unsupported platform stays fail-closed', () async {
    final result = await bootstrap(provider: null);

    expect(result.status, LearningCommerceBootstrapStatus.unsupportedPlatform);
    expect(result.configured, isFalse);
    expect(result.runtime, isNull);
    expect((await result.service.loadLocal()).purchasesConfigured, isFalse);
  });

  test('missing runtime session provider stays fail-closed', () async {
    final result = await bootstrap(withSession: false);

    expect(
      result.status,
      LearningCommerceBootstrapStatus.missingSessionHeadersProvider,
    );
    expect(result.runtime, isNull);
    expect((await result.service.loadLocal()).purchasesConfigured, isFalse);
  });

  test('missing store product IDs stay fail-closed', () async {
    final result = await bootstrap(productIds: const {});

    expect(result.status, LearningCommerceBootstrapStatus.missingStoreProductIds);
    expect((await result.service.loadLocal()).purchasesConfigured, isFalse);
  });

  test('incomplete logical store mapping stays fail-closed', () async {
    final result = await bootstrap(
      productIds: const {'different_product': 'store.boletes'},
    );

    expect(
      result.status,
      LearningCommerceBootstrapStatus.incompleteStoreProductIds,
    );
    expect((await result.service.loadLocal()).purchasesConfigured, isFalse);
  });

  test('missing verifier endpoint stays fail-closed', () async {
    final result = await bootstrap(verifyUrl: '');

    expect(
      result.status,
      LearningCommerceBootstrapStatus.missingVerifierEndpoints,
    );
    expect((await result.service.loadLocal()).purchasesConfigured, isFalse);
  });

  test('invalid verifier endpoint stays fail-closed', () async {
    final result = await bootstrap(
      verifyUrl: 'http://commerce.example.test/verify',
      entitlementsUrl: 'http://commerce.example.test/entitlements',
    );

    expect(
      result.status,
      LearningCommerceBootstrapStatus.invalidVerifierConfiguration,
    );
    expect((await result.service.loadLocal()).purchasesConfigured, isFalse);
  });

  test('complete configuration assembles and starts verified runtime', () async {
    final result = await bootstrap();
    addTearDown(result.close);

    expect(result.status, LearningCommerceBootstrapStatus.configured);
    expect(result.configured, isTrue);
    expect(result.runtime, isNotNull);
    expect(result.runtime!.started, isTrue);

    final local = await result.service.loadLocal();
    expect(local.purchasesConfigured, isTrue);
    expect(local.materials.single.entitlementGranted, isFalse);
  });

  test('store mapping must target the selected platform provider', () async {
    final result = await LearningCommerceBootstrap.fromEnvironment(
      platformProvider: () => LearningCommerceProvider.appStore,
      sessionHeadersProvider: () async => const {'Authorization': 'Bearer test'},
      offeringLoader: () async => LearningOfferingCatalog([_offering]),
      databaseProvider: () async => db,
      productIds: LearningStoreProductIds(
        provider: LearningCommerceProvider.googlePlay,
        productIds: const {'learning_pack_boletes_pores': 'store.boletes'},
      ),
      purchaseClient: const _PurchaseClient(),
      verifyUrl: 'https://commerce.example.test/verify',
      entitlementsUrl: 'https://commerce.example.test/entitlements',
    );

    expect(
      result.status,
      LearningCommerceBootstrapStatus.incompleteStoreProductIds,
    );
    expect((await result.service.loadLocal()).purchasesConfigured, isFalse);
  });
}

const _offering = LearningOffering(
  packageKey: 'boletes-pores',
  courseKey: 'specialist-boletes-pores',
  entitlementKey: 'learning.specialist.boletes-pores',
  productKey: 'learning_pack_boletes_pores',
  groupKey: 'specializations',
  sortOrder: 110,
  texts: {
    'nl': LearningOfferingText(title: 'Boleten', summary: 'Verdieping'),
    'en': LearningOfferingText(title: 'Boletes', summary: 'Specialization'),
    'de': LearningOfferingText(title: 'Röhrlinge', summary: 'Vertiefung'),
  },
);

class _PurchaseClient implements LearningInAppPurchaseClient {
  const _PurchaseClient();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream =>
      const Stream<List<PurchaseDetails>>.empty();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) =>
      throw UnimplementedError();

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) =>
      throw UnimplementedError();

  @override
  Future<void> restorePurchases() => throw UnimplementedError();

  @override
  Future<void> completePurchase(PurchaseDetails purchase) =>
      throw UnimplementedError();
}
