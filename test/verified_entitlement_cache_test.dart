import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_access.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_commerce.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_offering.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/verified_entitlement_cache.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  late SqliteVerifiedEntitlementRepository repository;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await DatabaseSchema.create(db);
    repository = SqliteVerifiedEntitlementRepository(
      databaseProvider: () async => db,
    );
  });

  tearDown(() => db.close());

  test('grant and revoke persist verified entitlement offline', () async {
    await repository.setEntitlement('learning.specialist.boletes-pores', true);

    expect(
      (await repository.loadEntitlements())
          .grants('learning.specialist.boletes-pores'),
      isTrue,
    );

    await repository.setEntitlement('learning.specialist.boletes-pores', false);

    expect((await repository.loadEntitlements()).keys, isEmpty);
  });

  test('full reconciliation replaces only entitlement namespace', () async {
    await db.insert('bundled_content_state', {
      'content_key': 'reference-content',
      'revision': 7,
      'synced_at': '2026-09-05T00:00:00Z',
    });
    await db.insert('bundled_content_state', {
      'content_key': 'learning-package:boletes-pores',
      'revision': 2,
      'synced_at': '2026-09-05T00:00:00Z',
    });
    await repository.replaceEntitlements([
      'learning.specialist.boletes-pores',
      'learning.specialist.gilled-mushrooms',
    ]);
    await repository.replaceEntitlements([
      'learning.specialist.gilled-mushrooms',
    ]);

    expect(
      (await repository.loadEntitlements()).keys,
      {'learning.specialist.gilled-mushrooms'},
    );
    expect(
      await db.query(
        'bundled_content_state',
        where: 'content_key = ?',
        whereArgs: ['reference-content'],
      ),
      hasLength(1),
    );
    expect(
      await db.query(
        'bundled_content_state',
        where: 'content_key = ?',
        whereArgs: ['learning-package:boletes-pores'],
      ),
      hasLength(1),
    );
  });

  test('verified evidence persists access before store completion', () async {
    final provider = _Provider();
    final verifier = _Verifier(
      verifyResult: const VerifiedLearningPurchase(
        productKey: 'learning_pack_boletes_pores',
        entitlementKey: 'learning.specialist.boletes-pores',
        active: true,
      ),
    );
    final controller = LearningVerifiedEntitlementController(
      commerce: _commerce(provider: provider, verifier: verifier),
      entitlements: repository,
    );
    const evidence = LearningPurchaseEvidence(
      provider: LearningCommerceProvider.googlePlay,
      productKey: 'learning_pack_boletes_pores',
      transactionId: '',
      verificationPayload: 'server-token',
      state: LearningPurchaseState.purchased,
    );

    await controller.processEvidence(evidence);

    expect(
      (await repository.loadEntitlements())
          .grants('learning.specialist.boletes-pores'),
      isTrue,
    );
    expect(provider.completed, [evidence]);
  });

  test('verification failure never persists or completes purchase', () async {
    final provider = _Provider();
    final verifier = _Verifier(
      verifyResult: const VerifiedLearningPurchase(
        productKey: 'learning_pack_boletes_pores',
        entitlementKey: 'learning.specialist.gilled-mushrooms',
        active: true,
      ),
    );
    final controller = LearningVerifiedEntitlementController(
      commerce: _commerce(provider: provider, verifier: verifier),
      entitlements: repository,
    );

    await expectLater(
      controller.processEvidence(
        const LearningPurchaseEvidence(
          provider: LearningCommerceProvider.googlePlay,
          productKey: 'learning_pack_boletes_pores',
          transactionId: 'order-1',
          verificationPayload: 'server-token',
          state: LearningPurchaseState.purchased,
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect((await repository.loadEntitlements()).keys, isEmpty);
    expect(provider.completed, isEmpty);
  });

  test('persistence failure leaves verified purchase incomplete', () async {
    final provider = _Provider();
    final controller = LearningVerifiedEntitlementController(
      commerce: _commerce(
        provider: provider,
        verifier: _Verifier(
          verifyResult: const VerifiedLearningPurchase(
            productKey: 'learning_pack_boletes_pores',
            entitlementKey: 'learning.specialist.boletes-pores',
            active: true,
          ),
        ),
      ),
      entitlements: _FailingRepository(),
    );

    await expectLater(
      controller.processEvidence(
        const LearningPurchaseEvidence(
          provider: LearningCommerceProvider.appStore,
          productKey: 'learning_pack_boletes_pores',
          transactionId: 'transaction-1',
          verificationPayload: 'server-token',
          state: LearningPurchaseState.purchased,
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(provider.completed, isEmpty);
  });

  test('authoritative reconciliation revokes stale and ignores future keys', () async {
    await repository.replaceEntitlements([
      'learning.specialist.boletes-pores',
      'learning.specialist.gilled-mushrooms',
    ]);
    final verifier = _Verifier(
      restored: EntitlementSnapshot([
        'learning.specialist.gilled-mushrooms',
        'learning.future.not-in-this-build',
      ]),
    );
    final controller = LearningVerifiedEntitlementController(
      commerce: _commerce(provider: _Provider(), verifier: verifier),
      entitlements: repository,
    );

    final snapshot = await controller.reconcileVerifiedEntitlements();

    expect(snapshot.keys, {'learning.specialist.gilled-mushrooms'});
    expect(
      (await repository.loadEntitlements()).keys,
      {'learning.specialist.gilled-mushrooms'},
    );
  });

  test('restore delegates to store before authoritative reconciliation', () async {
    final provider = _Provider();
    final verifier = _Verifier(
      restored: EntitlementSnapshot(['learning.specialist.boletes-pores']),
    );
    final controller = LearningVerifiedEntitlementController(
      commerce: _commerce(provider: provider, verifier: verifier),
      entitlements: repository,
    );

    final snapshot = await controller.restoreAndReconcile();

    expect(provider.restoreCalls, 1);
    expect(snapshot.keys, {'learning.specialist.boletes-pores'});
  });
}

LearningCommerceCoordinator _commerce({
  required _Provider provider,
  required _Verifier verifier,
}) {
  final offerings = LearningOfferingCatalog.fromDecoded({
    'catalog_version': 1,
    'offerings': [
      _offering(
        'boletes-pores',
        'learning_pack_boletes_pores',
        'learning.specialist.boletes-pores',
      ),
      _offering(
        'gilled-mushrooms',
        'learning_pack_gilled_mushrooms',
        'learning.specialist.gilled-mushrooms',
      ),
    ],
  });
  return LearningCommerceCoordinator(
    catalog: LearningCommerceCatalog.fromOfferings(offerings.offerings),
    provider: provider,
    verifier: verifier,
  );
}

Map<String, dynamic> _offering(
  String packageKey,
  String productKey,
  String entitlementKey,
) =>
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
  final List<LearningPurchaseEvidence> completed = [];
  int restoreCalls = 0;

  @override
  bool get configured => true;

  @override
  Stream<LearningPurchaseEvidence> get purchaseUpdates =>
      const Stream<LearningPurchaseEvidence>.empty();

  @override
  Future<Map<String, LearningProductQuote>> loadProductQuotes(
    Set<String> productKeys,
  ) async =>
      const {};

  @override
  Future<void> purchase(String productKey) async {}

  @override
  Future<void> restorePurchases() async {
    restoreCalls++;
  }

  @override
  Future<void> completeVerifiedPurchase(LearningPurchaseEvidence evidence) async {
    completed.add(evidence);
  }
}

class _Verifier implements LearningPurchaseVerifier {
  _Verifier({
    this.verifyResult,
    EntitlementSnapshot? restored,
  }) : restored = restored ?? EntitlementSnapshot(const <String>[]);

  final VerifiedLearningPurchase? verifyResult;
  final EntitlementSnapshot restored;

  @override
  Future<VerifiedLearningPurchase> verify(
    LearningPurchaseEvidence evidence,
  ) async =>
      verifyResult ??
      VerifiedLearningPurchase(
        productKey: evidence.productKey,
        entitlementKey: evidence.productKey == 'learning_pack_boletes_pores'
            ? 'learning.specialist.boletes-pores'
            : 'learning.specialist.gilled-mushrooms',
        active: true,
      );

  @override
  Future<EntitlementSnapshot> restoreVerifiedEntitlements() async => restored;
}

class _FailingRepository implements WritableEntitlementRepository {
  @override
  Future<EntitlementSnapshot> loadEntitlements() async =>
      EntitlementSnapshot(const <String>[]);

  @override
  Future<void> replaceEntitlements(Iterable<String> activeEntitlementKeys) async {
    throw StateError('disk full');
  }

  @override
  Future<void> setEntitlement(String entitlementKey, bool active) async {
    throw StateError('disk full');
  }
}
