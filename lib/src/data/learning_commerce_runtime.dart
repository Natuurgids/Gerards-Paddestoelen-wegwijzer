import 'dart:async';

import 'learning_commerce.dart';
import 'verified_entitlement_cache.dart';

/// Long-lived processor for store purchase updates.
///
/// Store updates are serialized so trusted verification, durable entitlement
/// persistence and store completion cannot race each other. Failed events are
/// reported without terminating the subscription; later store updates can still
/// be processed.
class LearningCommerceRuntime {
  LearningCommerceRuntime({required this.controller});

  final LearningVerifiedEntitlementController controller;
  final StreamController<void> _entitlementChanges =
      StreamController<void>.broadcast();
  final StreamController<Object> _errors = StreamController<Object>.broadcast();

  StreamSubscription<LearningPurchaseEvidence>? _subscription;
  Future<void> _tail = Future<void>.value();
  bool _closed = false;

  LearningCommerceCoordinator get commerce => controller.commerce;

  Stream<void> get entitlementChanges => _entitlementChanges.stream;

  Stream<Object> get errors => _errors.stream;

  bool get started => _subscription != null;

  void start() {
    if (_closed) {
      throw StateError('Learning commerce runtime is closed');
    }
    if (_subscription != null) return;
    _subscription = commerce.provider.purchaseUpdates.listen(
      _handleEvidence,
      onError: (Object error, StackTrace stackTrace) {
        if (!_errors.isClosed) _errors.add(error);
      },
    );
  }

  Future<void> restoreAndReconcile() async {
    await _serialize(() async {
      await controller.restoreAndReconcile();
      _notifyEntitlementChange();
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) await subscription.cancel();
    await _tail;
    await _entitlementChanges.close();
    await _errors.close();
  }

  void _handleEvidence(LearningPurchaseEvidence evidence) {
    if (evidence.state != LearningPurchaseState.purchased &&
        evidence.state != LearningPurchaseState.restored) {
      return;
    }
    unawaited(
      _serialize(() async {
        await controller.processEvidence(evidence);
        _notifyEntitlementChange();
      }).catchError((Object error, StackTrace stackTrace) {
        if (!_errors.isClosed) _errors.add(error);
      }),
    );
  }

  Future<void> _serialize(Future<void> Function() action) {
    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        await action();
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  void _notifyEntitlementChange() {
    if (!_entitlementChanges.isClosed) _entitlementChanges.add(null);
  }
}
