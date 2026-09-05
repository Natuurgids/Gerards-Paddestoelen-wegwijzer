import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_access.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_commerce.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_materials_service.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_offering.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_package_installer.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('PRAGMA foreign_keys = ON');
    await DatabaseSchema.create(db);
  });

  tearDown(() => db.close());

  test('matching commerce catalogue exposes provider quote', () async {
    final offering = _offering(
      entitlementKey: 'learning.specialist.boletes-pores',
    );
    final provider = _Provider();
    final service = _service(
      db,
      offering: offering,
      commerceOffering: offering,
      provider: provider,
    );

    final local = await service.loadLocal();
    final quotes = await service.loadProductQuotes(
      local.materials.map((item) => item.offering),
    );

    expect(local.purchasesConfigured, isTrue);
    expect(quotes.values.single.displayPrice, '€ 2,99');
  });

  test('commerce entitlement mismatch fails closed before store use', () async {
    final publicOffering = _offering(
      entitlementKey: 'learning.specialist.boletes-pores',
    );
    final commerceOffering = _offering(
      entitlementKey: 'learning.specialist.gilled-mushrooms',
    );
    final provider = _Provider();
    final service = _service(
      db,
      offering: publicOffering,
      commerceOffering: commerceOffering,
      provider: provider,
    );

    expect(service.loadLocal, throwsA(isA<StateError>()));
    expect(provider.quoteCalls, 0);
  });
}

DefaultLearningMaterialsService _service(
  Database db, {
  required LearningOffering offering,
  required LearningOffering commerceOffering,
  required _Provider provider,
}) {
  const entitlements = EmptyEntitlementRepository();
  final commerce = LearningCommerceCoordinator(
    catalog: LearningCommerceCatalog.fromOfferings([commerceOffering]),
    provider: provider,
    verifier: const _Verifier(),
  );
  return DefaultLearningMaterialsService(
    entitlements: entitlements,
    installer: const LearningPackageInstaller(
      catalogUrl: '',
      entitlements: entitlements,
    ),
    databaseProvider: () async => db,
    offeringLoader: () async => LearningOfferingCatalog([offering]),
    commerce: commerce,
  );
}

LearningOffering _offering({required String entitlementKey}) => LearningOffering(
      packageKey: 'boletes-pores',
      courseKey: 'specialist-boletes-pores',
      entitlementKey: entitlementKey,
      productKey: 'learning_pack_boletes_pores',
      groupKey: 'specializations',
      sortOrder: 110,
      texts: const {
        'nl': LearningOfferingText(title: 'Boleten', summary: 'Verdieping'),
        'en': LearningOfferingText(title: 'Boletes', summary: 'Specialization'),
        'de': LearningOfferingText(title: 'Röhrlinge', summary: 'Vertiefung'),
      },
    );

class _Provider implements LearningCommerceProviderAdapter {
  int quoteCalls = 0;

  @override
  bool get configured => true;

  @override
  Stream<LearningPurchaseEvidence> get purchaseUpdates =>
      const Stream<LearningPurchaseEvidence>.empty();

  @override
  Future<Map<String, LearningProductQuote>> loadProductQuotes(
    Set<String> productKeys,
  ) async {
    quoteCalls++;
    return const {
      'learning_pack_boletes_pores': LearningProductQuote(
        productKey: 'learning_pack_boletes_pores',
        displayPrice: '€ 2,99',
        currencyCode: 'EUR',
      ),
    };
  }

  @override
  Future<void> purchase(String productKey) async {}

  @override
  Future<void> restorePurchases() async {}
}

class _Verifier implements LearningPurchaseVerifier {
  const _Verifier();

  @override
  Future<VerifiedLearningPurchase> verify(
    LearningPurchaseEvidence evidence,
  ) =>
      throw UnimplementedError();

  @override
  Future<EntitlementSnapshot> restoreVerifiedEntitlements() async =>
      EntitlementSnapshot(const <String>[]);
}
