import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/bundled_content_sync.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('''CREATE TABLE bundled_content_state (
      content_key TEXT PRIMARY KEY,
      revision INTEGER NOT NULL,
      synced_at TEXT NOT NULL
    )''');
  });

  tearDown(() => db.close());

  test('successful bundled content sync runs once per revision', () async {
    var calls = 0;

    Future<List<String>> sync() async {
      calls++;
      return const [];
    }

    expect(await BundledContentSync.runIfNeeded(db, sync), isEmpty);
    expect(await BundledContentSync.runIfNeeded(db, sync), isEmpty);
    expect(calls, 1);

    final rows = await db.query('bundled_content_state');
    expect(rows, hasLength(1));
    expect(rows.single['revision'], BundledContentSync.revision);
  });

  test('older bundled content revision is resynced and upgraded', () async {
    await db.insert('bundled_content_state', {
      'content_key': BundledContentSync.contentKey,
      'revision': BundledContentSync.revision - 1,
      'synced_at': '2026-09-03T00:00:00Z',
    });
    var calls = 0;

    Future<List<String>> sync() async {
      calls++;
      return const [];
    }

    expect(await BundledContentSync.runIfNeeded(db, sync), isEmpty);
    expect(calls, 1);

    final rows = await db.query(
      'bundled_content_state',
      where: 'content_key=?',
      whereArgs: const [BundledContentSync.contentKey],
    );
    expect(rows, hasLength(1));
    expect(rows.single['revision'], BundledContentSync.revision);
  });

  test('failed bundled content sync is retried', () async {
    var calls = 0;

    Future<List<String>> sync() async {
      calls++;
      return calls == 1 ? const ['training-content'] : const [];
    }

    expect(
      await BundledContentSync.runIfNeeded(db, sync),
      const ['training-content'],
    );
    expect(await db.query('bundled_content_state'), isEmpty);

    expect(await BundledContentSync.runIfNeeded(db, sync), isEmpty);
    expect(calls, 2);
    expect(await db.query('bundled_content_state'), hasLength(1));
  });

  test('v6 to v7 adds bundled content revision state', () async {
    await db.execute('DROP TABLE bundled_content_state');

    await DatabaseSchema.upgrade(db, 6, 7);

    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    );
    expect(
      tables.map((row) => row['name']),
      contains('bundled_content_state'),
    );
  });
}
