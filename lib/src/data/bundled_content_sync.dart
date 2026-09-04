import 'package:sqflite/sqflite.dart';

typedef BundledContentSyncRunner = Future<List<String>> Function();

class BundledContentSync {
  const BundledContentSync._();

  static const contentKey = 'reference-content';
  static const revision = 4;

  static Future<List<String>> runIfNeeded(
    Database db,
    BundledContentSyncRunner sync,
  ) async {
    final rows = await db.query(
      'bundled_content_state',
      columns: const ['revision'],
      where: 'content_key=?',
      whereArgs: const [contentKey],
      limit: 1,
    );
    if (rows.isNotEmpty && rows.single['revision'] == revision) {
      return const [];
    }

    final failures = await sync();
    if (failures.isNotEmpty) return failures;

    await db.insert(
      'bundled_content_state',
      {
        'content_key': contentKey,
        'revision': revision,
        'synced_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return const [];
  }
}
