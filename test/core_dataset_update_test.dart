import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/core_dataset_update.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/database_schema.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled dataset metadata matches the current database schema', () async {
    final metadata = await CoreDatasetMetadata.loadBundled();

    expect(metadata.datasetVersion, greaterThan(0));
    expect(metadata.databaseSchemaVersion, DatabaseSchema.currentVersion);
  });

  test('newer compatible dataset is offered as an update', () async {
    const installed = CoreDatasetMetadata(
      datasetVersion: 3,
      databaseSchemaVersion: DatabaseSchema.currentVersion,
    );
    final checker = CoreDatasetUpdateChecker(
      _FakeSource(_manifest(datasetVersion: 4)),
    );

    final result = await checker.check(installed);

    expect(result.disposition, CoreDatasetUpdateDisposition.updateAvailable);
    expect(result.latest.datasetVersion, 4);
  });

  test('same or older dataset never causes a downgrade', () async {
    const installed = CoreDatasetMetadata(
      datasetVersion: 3,
      databaseSchemaVersion: DatabaseSchema.currentVersion,
    );

    for (final version in [3, 2]) {
      final result = await CoreDatasetUpdateChecker(
        _FakeSource(_manifest(datasetVersion: version)),
      ).check(installed);
      expect(result.disposition, CoreDatasetUpdateDisposition.upToDate);
    }
  });

  test('newer dataset for another database schema is incompatible', () async {
    const installed = CoreDatasetMetadata(
      datasetVersion: 3,
      databaseSchemaVersion: DatabaseSchema.currentVersion,
    );
    final result = await CoreDatasetUpdateChecker(
      _FakeSource(
        _manifest(
          datasetVersion: 4,
          databaseSchemaVersion: DatabaseSchema.currentVersion + 1,
        ),
      ),
    ).check(installed);

    expect(result.disposition, CoreDatasetUpdateDisposition.incompatibleSchema);
  });

  test('manifest requires HTTPS integrity metadata and UTC publication time', () {
    final base = _decodedManifest();

    expect(
      () => CoreDatasetUpdateManifest.fromDecoded({
        ...base,
        'package_url': 'http://updates.example.org/core.zip',
      }),
      throwsFormatException,
    );
    expect(
      () => CoreDatasetUpdateManifest.fromDecoded({
        ...base,
        'package_sha256': 'ABC123',
      }),
      throwsFormatException,
    );
    expect(
      () => CoreDatasetUpdateManifest.fromDecoded({
        ...base,
        'package_size_bytes': 0,
      }),
      throwsFormatException,
    );
    expect(
      () => CoreDatasetUpdateManifest.fromDecoded({
        ...base,
        'published_at': '2026-09-05T03:00:00+02:00',
      }),
      throwsFormatException,
    );
  });

  test('core update manifest rejects observation and user-owned data', () {
    for (final forbidden in [
      'observations',
      'locations',
      'training_progress',
      'entitlements',
      'unknown_component',
    ]) {
      expect(
        () => CoreDatasetUpdateManifest.fromDecoded({
          ..._decodedManifest(),
          'components': ['species_catalog', forbidden],
        }),
        throwsFormatException,
      );
    }
  });

  test('recognized public core data components are accepted', () {
    final manifest = CoreDatasetUpdateManifest.fromDecoded({
      ..._decodedManifest(),
      'components': coreDatasetComponents.toList()..sort(),
    });

    expect(manifest.components, coreDatasetComponents);
    expect(manifest.packageUri.scheme, 'https');
  });
}

CoreDatasetUpdateManifest _manifest({
  required int datasetVersion,
  int databaseSchemaVersion = DatabaseSchema.currentVersion,
}) {
  return CoreDatasetUpdateManifest.fromDecoded(
    _decodedManifest(
      datasetVersion: datasetVersion,
      databaseSchemaVersion: databaseSchemaVersion,
    ),
  );
}

Map<String, dynamic> _decodedManifest({
  int datasetVersion = 2,
  int databaseSchemaVersion = DatabaseSchema.currentVersion,
}) {
  return {
    'manifest_version': 1,
    'dataset_key': coreDatasetKey,
    'dataset_version': datasetVersion,
    'database_schema_version': databaseSchemaVersion,
    'published_at': '2026-09-05T03:00:00Z',
    'package_url': 'https://updates.example.org/core-v$datasetVersion.zip',
    'package_sha256': '0123456789abcdef' * 4,
    'package_size_bytes': 123456,
    'components': [
      'species_catalog',
      'identification_traits',
      'training_content',
    ],
  };
}

class _FakeSource implements CoreDatasetUpdateSource {
  const _FakeSource(this.manifest);

  final CoreDatasetUpdateManifest manifest;

  @override
  Future<CoreDatasetUpdateManifest> loadLatestManifest() async => manifest;
}
