import 'package:sqflite/sqflite.dart';

import 'learning_access.dart';
import 'learning_commerce.dart';

const verifiedLearningEntitlementPrefix = 'learning-entitlement:';

abstract interface class WritableEntitlementRepository
    implements EntitlementRepository {
  Future<void> setEntitlement(String entitlementKey, bool active);

  Future<void> replaceEntitlements(Iterable<String> activeEntitlementKeys);
}

class SqliteVerifiedEntitlementRepository
    implements WritableEntitlementRepository {
  const SqliteVerifiedEntitlementRepository({required this.databaseProvider});

  final Future<Database> Function() databaseProvider;

  @override
  Future<EntitlementSnapshot> loadEntitlements() async {
    final db = await databaseProvider();
    final rows = await db.query(
      'bundled_content_state',
      columns: ['content_key'],
      where: 'content_key LIKE ?',
      whereArgs: ['$verifiedLearningEntitlementPrefix%'],
      orderBy: 'content_key',
    );
    return EntitlementSnapshot(
      rows.map((row) => row['content_key'] as String).map(_decodeKey),
    );
  }

  @override
  Future<void> setEntitlement(String entitlementKey, bool active) async {
    final key = _validatedKey(entitlementKey);
    final db = await databaseProvider();
    await db.transaction((txn) async {
      if (active) {
        await txn.insert(
          'bundled_content_state',
          {
            'content_key': _encodeKey(key),
            'revision': 1,
            'synced_at': DateTime.now().toUtc().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await txn.delete(
          'bundled_content_state',
          where: 'content_key = ?',
          whereArgs: [_encodeKey(key)],
        );
      }
    });
  }

  @override
  Future<void> replaceEntitlements(Iterable<String> activeEntitlementKeys) async {
    final keys = activeEntitlementKeys.map(_validatedKey).toSet();
    final db = await databaseProvider();
    final syncedAt = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'bundled_content_state',
        where: 'content_key LIKE ?',
        whereArgs: ['$verifiedLearningEntitlementPrefix%'],
      );
      for (final key in keys) {
        await txn.insert('bundled_content_state', {
          'content_key': _encodeKey(key),
          'revision': 1,
          'synced_at': syncedAt,
        });
      }
    });
  }

  static String _validatedKey(String entitlementKey) {
    final key = entitlementKey.trim();
    if (key.isEmpty || key.contains('\n') || key.contains('\r')) {
      throw const FormatException('Learning entitlement key is invalid');
    }
    return key;
  }

  static String _encodeKey(String entitlementKey) =>
      '$verifiedLearningEntitlementPrefix$entitlementKey';

  static String _decodeKey(String storedKey) {
    if (!storedKey.startsWith(verifiedLearningEntitlementPrefix)) {
      throw StateError('Stored learning entitlement key has invalid namespace');
    }
    return storedKey.substring(verifiedLearningEntitlementPrefix.length);
  }
}

/// Applies trusted verification results to the durable offline entitlement
/// snapshot without allowing store receipts to grant access directly.
class LearningVerifiedEntitlementController {
  const LearningVerifiedEntitlementController({
    required this.commerce,
    required this.entitlements,
  });

  final LearningCommerceCoordinator commerce;
  final WritableEntitlementRepository entitlements;

  Future<VerifiedLearningPurchase> processEvidence(
    LearningPurchaseEvidence evidence,
  ) async {
    final verified = await commerce.verifyEvidence(evidence);
    await entitlements.setEntitlement(
      verified.entitlementKey,
      verified.active,
    );
    await commerce.provider.completeVerifiedPurchase(evidence);
    return verified;
  }

  /// Replace the locally cached entitlement namespace from the verifier's
  /// authoritative active snapshot.
  ///
  /// Entitlements unknown to this app version are ignored for forward
  /// compatibility; they cannot grant access to any bundled offering.
  Future<EntitlementSnapshot> reconcileVerifiedEntitlements() async {
    final verified = await commerce.verifier.restoreVerifiedEntitlements();
    final knownEntitlements = commerce.catalog.bindings.values
        .map((binding) => binding.entitlementKey)
        .toSet();
    final active = verified.keys.where(knownEntitlements.contains).toSet();
    await entitlements.replaceEntitlements(active);
    return EntitlementSnapshot(active);
  }

  Future<EntitlementSnapshot> restoreAndReconcile() async {
    await commerce.restorePurchases();
    return reconcileVerifiedEntitlements();
  }
}
