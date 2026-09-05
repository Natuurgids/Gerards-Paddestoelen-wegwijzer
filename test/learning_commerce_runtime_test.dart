import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_access.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_commerce.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_commerce_runtime.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_offering.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/verified_entitlement_cache.dart';

void main() {
  test('purchase updates are processed serially and emit entitlement changes', () async {
    final provider = _Provider();
    final firstGate = Completer<void>();
    final verifier = _Verifier(firstGate: firstGate);
    final entitlements = _Entitlements();
    final runtime = _runtime(
      provider: provider,
      verifier: verifier,
      entitlements: entitlements,
    );
    final changes = <void>[];
    final changeSubscription = runtime.entitlementChanges.listen(changes.add);
    runtime.start();

    provider.emit([
      _evidence('learning_pack_boletes_pores', 'token-1'),
      _evidence('learning_pack_gilled_mushrooms', 'token-2'),
    ]);
    await Future<void>.delayed(Duration.zero);

    expect(verifier.started, ['learning_pack_boletes_pores']);
    expect(provider.completed, isEmpty);

    firstGate.complete();
    await _eventually(() => provider.completed.length == 2);

    expect(verifier.started, [
      'learning_pack_boletes_pores',
      'learning_pack_gilled_mushrooms',
    ]);
    expect(entitlements.operations, [
      'learning.specialist.boletes-pores=true',
      'learning.specialist.gilled-mushrooms=true',
    ]);
    expect(provider.completed.map((item) => item.productKey), [
      'learning_pack_boletes_pores',
      'learning_pack_gilled_mushrooms',
    ]);
    expect(changes, hasLength(2));

    await changeSubscription.cancel();
    await runtime.close();
    await provider.close();
  });

  test('failed verification is reported and later purchase still succeeds', () async {
    final provider = _Provider();
    final verifier = _Verifier(failProduct: 'learning_pack_boletes_pores');
    final entitlements = _Entitlements();
    final runtime = _runtime(
      provider: provider,
      verifier: verifier,
      entitlements: entitlements,
    );
    final errors = <Object>[];
    final changes = <void>[];
    final errorSubscription = runtime.errors.listen(errors.add);
    final changeSubscription = runtime.entitlementChanges.listen(changes.add);
    runtime.start();

    provider.emit([
      _evidence('learning_pack_boletes_pores', 'bad-token'),
      _evidence('learning_pack_gilled_mushrooms', 'good-token'),
    ]);

    await _eventually(() => provider.completed.length == 1);

    expect(errors, hasLength(1));
    expect(provider.completed.single.productKey, 'learning_pack_gilled_mushrooms');
    expect(entitlements.operations, [
      'learning.specialist.gilled-mushrooms=true',
    ]);
    expect(changes, hasLength(1));

    await errorSubscription.cancel();
    await changeSubscription.cancel();
    await runtime.close();
    await provider.close();
  });

  test('pending cancelled and failed store states do not reach verifier', () async {
    final provider = _Provider();
    final verifier = _Verifier();
    final runtime = _runtime(
      provider: provider,
      verifier: verifier,
      entitlements: _Entitlements(),
    );
    runtime.start();

    provider.emit([
      _evidence(
        'learning_pack_boletes_pores',
        '',
        state: LearningPurchaseState.pending,
      ),
      _evidence(
        'learning_pack_boletes_pores',
        '',
        state: LearningPurchaseState.canceled,
      ),
      _evidence(
        'learning_pack_boletes_pores',
        '',
        state: LearningPurchaseState.failed,
      ),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(verifier.started, isEmpty);
    expect(provider.completed, isEmpty);

    await runtime.close();
    await provider.close();
  });

  test('restore is serialized and reconciles authoritative snapshot', () async {
    final provider = _Provider();
    final verifier = _Verifier(
      restored: EntitlementSnapshot([
        'learning.specialist.gilled-mushrooms',
      ]),
    );
    final entitlements = _Entitlements();
    final runtime = _runtime(
      provider: provider,
      verifier: verifier,
      entitlements: entitlements,
    );
    final changes = <void>[];
    final changeSubscription = runtime.entitlementChanges.listen(changes.add);
    runtime.start();

    await runtime.restoreAndReconcile();

    expect(provider.restoreCalls, 1);
    expect(verifier.restoreCalls, 1);
    expect(entitlements.replacements, [
      {'learning.specialist.gilled-mushrooms'},
    ]);
    expect(changes, hasLength(1));

    await changeSubscription.cancel();
    await runtime.close();
    await provider.close();
  });

  test('start is idempotent and closed runtime cannot restart', () async {
    final provider = _Provider();
    final runtime = _runtime(
      provider: provider,
      verifier: _Verifier(),
      entitlements: _Entitlements(),
    );

    runtime.start();
    runtime.start();
    expect(runtime.started, isTrue);

    await runtime.close();
    expect(() => runtime.start(), throwsA(isA<StateError>()));
    await provider.close();
  });
}

LearningCommerceRuntime _runtime({
  required _Provider provider,
  required _Verifier verifier,
  required _Entitlements entitlements,
}) {
  final offerings = [
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
  ];
  final commerce = LearningCommerceCoordinator(
    catalog: LearningCommerceCatalog.fromOfferings(offerings),
    provider: provider,
    verifier: verifier,
  );
  return LearningCommerceRuntime(
    controller: LearningVerifiedEntitlementController(
      commerce: commerce,
      entitlements: entitlements,
    ),
  );
}

LearningOffering _offering({
  required String packageKey,
  required String productKey,
  required String entitlementKey,
}) =>
    LearningOffering(
      packageKey: packageKey,
      courseKey: 'specialist-$packageKey',
      entitlementKey: entitlementKey,
      productKey: productKey,
      groupKey: 'specializations',
      sortOrder: 1,
      texts: const {
        'nl': LearningOfferingText(title: 'Titel', summary: 'Samenvatting'),
        'en': LearningOfferingText(title: 'Title', summary: 'Summary'),
        'de': LearningOfferingText(title: 'Titel', summary: 'Zusammenfassung'),
      },
    );

LearningPurchaseEvidence _evidence(
  String productKey,
  String payload, {
  LearningPurchaseState state = LearningPurchaseState.purchased,
}) =>
    LearningPurchaseEvidence(
      provider: LearningCommerceProvider.googlePlay,
      productKey: productKey,
      transactionId: 'transaction-$productKey',
      verificationPayload: payload,
      state: state,
    );

Future<void> _eventually(bool Function() predicate) async {
  for (var i = 0; i < 100; i++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Condition was not reached');
}

class _Provider implements LearningCommerceProviderAdapter {
  final StreamController<List<LearningPurchaseEvidence>> _batches =
      StreamController<List<LearningPurchaseEvidence>>.broadcast();
  final List<LearningPurchaseEvidence> completed = [];
  int restoreCalls = 0;

  void emit(List<LearningPurchaseEvidence> evidence) => _batches.add(evidence);

  Future<void> close() => _batches.close();

  @override
  bool get configured => true;

  @override
  Stream<LearningPurchaseEvidence> get purchaseUpdates =>
      _batches.stream.expand((batch) => batch);

  @override
  Future<Map<String, LearningProductQuote>> loadProductQuotes(
    Set<String> productKeys,
  ) async =>
      const <String, LearningProductQuote>{};

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
    this.firstGate,
    this.failProduct,
    EntitlementSnapshot? restored,
  }) : restored = restored ?? EntitlementSnapshot(const <String>[]);

  final Completer<void>? firstGate;
  final String? failProduct;
  final EntitlementSnapshot restored;
  final List<String> started = [];
  int restoreCalls = 0;

  @override
  Future<VerifiedLearningPurchase> verify(
    LearningPurchaseEvidence evidence,
  ) async {
    started.add(evidence.productKey);
    if (started.length == 1 && firstGate != null) await firstGate!.future;
    if (evidence.productKey == failProduct) {
      throw StateError('verification failed');
    }
    return VerifiedLearningPurchase(
      productKey: evidence.productKey,
      entitlementKey: evidence.productKey == 'learning_pack_boletes_pores'
          ? 'learning.specialist.boletes-pores'
          : 'learning.specialist.gilled-mushrooms',
      active: true,
    );
  }

  @override
  Future<EntitlementSnapshot> restoreVerifiedEntitlements() async {
    restoreCalls++;
    return restored;
  }
}

class _Entitlements implements WritableEntitlementRepository {
  final Set<String> active = {};
  final List<String> operations = [];
  final List<Set<String>> replacements = [];

  @override
  Future<EntitlementSnapshot> loadEntitlements() async =>
      EntitlementSnapshot(active);

  @override
  Future<void> setEntitlement(String entitlementKey, bool enabled) async {
    operations.add('$entitlementKey=$enabled');
    if (enabled) {
      active.add(entitlementKey);
    } else {
      active.remove(entitlementKey);
    }
  }

  @override
  Future<void> replaceEntitlements(Iterable<String> activeEntitlementKeys) async {
    final replacement = activeEntitlementKeys.toSet();
    replacements.add(replacement);
    active
      ..clear()
      ..addAll(replacement);
  }
}
