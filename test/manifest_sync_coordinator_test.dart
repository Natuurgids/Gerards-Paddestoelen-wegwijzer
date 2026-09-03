import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/manifest_sync_coordinator.dart';

void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute('CREATE TABLE sync_probe (name TEXT PRIMARY KEY)');
  });

  tearDown(() async {
    await db.close();
  });

  test('one failed manifest does not prevent later sync steps', () async {
    final failures = await ManifestSyncCoordinator.run(db, [
      (
        name: 'catalogue',
        sync: (database) => database.insert('sync_probe', {'name': 'catalogue'}),
      ),
      (
        name: 'traits',
        sync: (database) async {
          throw const FormatException('malformed test manifest');
        },
      ),
      (
        name: 'field-data',
        sync: (database) => database.insert('sync_probe', {'name': 'field-data'}),
      ),
    ]);

    expect(failures, ['traits']);
    final rows = await db.query('sync_probe', orderBy: 'name');
    expect(rows.map((row) => row['name']), ['catalogue', 'field-data']);
  });
}
