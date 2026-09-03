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

  test('failed dependency skips dependents but not independent steps', () async {
    final failures = await ManifestSyncCoordinator.run(db, [
      (
        name: 'catalogue',
        sync: (database) async {
          throw const FormatException('malformed test manifest');
        },
        dependsOn: const [],
      ),
      (
        name: 'traits',
        sync: (database) async {
          await database.insert('sync_probe', {'name': 'traits'});
        },
        dependsOn: const ['catalogue'],
      ),
      (
        name: 'field-data',
        sync: (database) async {
          await database.insert('sync_probe', {'name': 'field-data'});
        },
        dependsOn: const ['catalogue'],
      ),
      (
        name: 'training',
        sync: (database) async {
          await database.insert('sync_probe', {'name': 'training'});
        },
        dependsOn: const [],
      ),
    ]);

    expect(failures, ['catalogue', 'traits', 'field-data']);
    final rows = await db.query('sync_probe', orderBy: 'name');
    expect(rows.map((row) => row['name']), ['training']);
  });

  test('unknown dependency is reported without running the step', () async {
    final failures = await ManifestSyncCoordinator.run(db, [
      (
        name: 'field-data',
        sync: (database) async {
          await database.insert('sync_probe', {'name': 'field-data'});
        },
        dependsOn: const ['catalogue'],
      ),
      (
        name: 'training',
        sync: (database) async {
          await database.insert('sync_probe', {'name': 'training'});
        },
        dependsOn: const [],
      ),
    ]);

    expect(failures, ['field-data']);
    final rows = await db.query('sync_probe', orderBy: 'name');
    expect(rows.map((row) => row['name']), ['training']);
  });

  test('duplicate step names are reported without running either duplicate',
      () async {
    final failures = await ManifestSyncCoordinator.run(db, [
      (
        name: 'catalogue',
        sync: (database) async {
          await database.insert('sync_probe', {'name': 'catalogue-a'});
        },
        dependsOn: const [],
      ),
      (
        name: 'catalogue',
        sync: (database) async {
          await database.insert('sync_probe', {'name': 'catalogue-b'});
        },
        dependsOn: const [],
      ),
      (
        name: 'field-data',
        sync: (database) async {
          await database.insert('sync_probe', {'name': 'field-data'});
        },
        dependsOn: const ['catalogue'],
      ),
      (
        name: 'training',
        sync: (database) async {
          await database.insert('sync_probe', {'name': 'training'});
        },
        dependsOn: const [],
      ),
    ]);

    expect(failures, ['catalogue', 'field-data']);
    final rows = await db.query('sync_probe', orderBy: 'name');
    expect(rows.map((row) => row['name']), ['training']);
  });

  test('runDetailed returns structured status and dependency diagnostics',
      () async {
    final results = await ManifestSyncCoordinator.runDetailed(db, [
      (
        name: 'catalogue',
        sync: (database) async {
          throw const FormatException('malformed catalogue');
        },
        dependsOn: const [],
      ),
      (
        name: 'traits',
        sync: (database) async {},
        dependsOn: const ['catalogue'],
      ),
      (
        name: 'field-data',
        sync: (database) async {},
        dependsOn: const ['missing-catalogue'],
      ),
      (
        name: 'training',
        sync: (database) async {
          await database.insert('sync_probe', {'name': 'training'});
        },
        dependsOn: const [],
      ),
    ]);

    expect(results, hasLength(4));
    expect(results[0].name, 'catalogue');
    expect(results[0].status, ManifestSyncStatus.failed);
    expect(results[0].error, isA<FormatException>());

    expect(results[1].name, 'traits');
    expect(
      results[1].status,
      ManifestSyncStatus.skippedUnavailableDependency,
    );
    expect(results[1].dependencies, ['catalogue']);

    expect(results[2].name, 'field-data');
    expect(results[2].status, ManifestSyncStatus.skippedUnknownDependency);
    expect(results[2].dependencies, ['missing-catalogue']);

    expect(results[3].name, 'training');
    expect(results[3].status, ManifestSyncStatus.success);
    expect(results[3].unavailable, isFalse);
  });

  test('runDetailed reports each duplicate while run keeps unique names',
      () async {
    final steps = <ManifestSyncTask>[
      (
        name: 'catalogue',
        sync: (database) async {},
        dependsOn: const [],
      ),
      (
        name: 'catalogue',
        sync: (database) async {},
        dependsOn: const [],
      ),
    ];

    final results = await ManifestSyncCoordinator.runDetailed(db, steps);
    expect(results, hasLength(2));
    expect(
      results.map((result) => result.status),
      everyElement(ManifestSyncStatus.skippedDuplicateName),
    );

    expect(await ManifestSyncCoordinator.run(db, steps), ['catalogue']);
  });
}
