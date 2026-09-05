import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import 'core_dataset_transport.dart';
import 'learning_access.dart';
import 'learning_package.dart';
import 'training_manifest_importer.dart';

const learningPackageCatalogUrl = String.fromEnvironment(
  'LEARNING_PACKAGE_CATALOG_URL',
);
const _learningPackageStatePrefix = 'learning-package:';
const _maxLearningCatalogBytes = 256 * 1024;

enum LearningPackageInstallOutcome {
  notConfigured,
  packageNotFound,
  notEntitled,
  alreadyCurrent,
  installed,
}

class LearningPackageInstallResult {
  const LearningPackageInstallResult({
    required this.outcome,
    required this.packageKey,
    this.contentVersion,
  });

  final LearningPackageInstallOutcome outcome;
  final String packageKey;
  final int? contentVersion;
}

class InstalledLearningPackageState {
  const InstalledLearningPackageState({
    required this.packageKey,
    required this.contentVersion,
    required this.installedAt,
  });

  final String packageKey;
  final int contentVersion;
  final DateTime installedAt;

  static Future<InstalledLearningPackageState?> load(
    DatabaseExecutor db,
    String packageKey,
  ) async {
    final rows = await db.query(
      'bundled_content_state',
      columns: const ['revision', 'synced_at'],
      where: 'content_key=?',
      whereArgs: ['$_learningPackageStatePrefix$packageKey'],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final revision = rows.single['revision'];
    final installedAtRaw = rows.single['synced_at'];
    final installedAt = installedAtRaw is String
        ? DateTime.tryParse(installedAtRaw)
        : null;
    if (revision is! int || revision <= 0 || installedAt == null) {
      throw StateError('Installed learning package state is invalid for $packageKey');
    }
    return InstalledLearningPackageState(
      packageKey: packageKey,
      contentVersion: revision,
      installedAt: installedAt.toUtc(),
    );
  }
}

class RemoteLearningPackageCatalogSource {
  const RemoteLearningPackageCatalogSource({
    required this.catalogUri,
    required this.byteSource,
  });

  final Uri catalogUri;
  final CoreDatasetByteSource byteSource;

  Future<LearningPackageCatalog> load() async {
    _requireTrustedHttps(catalogUri, 'Learning package catalog');
    final bytes = await byteSource.fetch(
      catalogUri,
      maxBytes: _maxLearningCatalogBytes,
    );
    return LearningPackageCatalog.fromDecoded(
      _decodeJsonObject(bytes, 'Learning package catalog'),
    );
  }

  Uri packageUri(LearningPackageDescriptor descriptor) {
    final uri = catalogUri.resolve(descriptor.packagePath);
    _requireTrustedHttps(uri, 'Learning package');
    if (!_sameOrigin(catalogUri, uri)) {
      throw const FormatException(
        'Learning package URL must use the trusted catalog origin',
      );
    }
    return uri;
  }
}

class LearningPackageInstaller {
  const LearningPackageInstaller({
    required this.catalogUrl,
    required this.entitlements,
    this.byteSource = const HttpCoreDatasetByteSource(),
  });

  final String catalogUrl;
  final EntitlementRepository entitlements;
  final CoreDatasetByteSource byteSource;

  Future<LearningPackageCatalog?> loadCatalog() async {
    final configured = catalogUrl.trim();
    if (configured.isEmpty) return null;
    final uri = Uri.tryParse(configured);
    if (uri == null) {
      throw const FormatException('Learning package catalog URL is invalid');
    }
    return RemoteLearningPackageCatalogSource(
      catalogUri: uri,
      byteSource: byteSource,
    ).load();
  }

  Future<LearningPackageInstallResult> install(
    Database db,
    String packageKey, {
    DateTime? installedAt,
  }) async {
    final configured = catalogUrl.trim();
    if (configured.isEmpty) {
      return LearningPackageInstallResult(
        outcome: LearningPackageInstallOutcome.notConfigured,
        packageKey: packageKey,
      );
    }
    final catalogUri = Uri.tryParse(configured);
    if (catalogUri == null) {
      throw const FormatException('Learning package catalog URL is invalid');
    }
    final source = RemoteLearningPackageCatalogSource(
      catalogUri: catalogUri,
      byteSource: byteSource,
    );
    final catalog = await source.load();
    LearningPackageDescriptor? descriptor;
    for (final candidate in catalog.packages) {
      if (candidate.packageKey == packageKey) {
        descriptor = candidate;
        break;
      }
    }
    if (descriptor == null) {
      return LearningPackageInstallResult(
        outcome: LearningPackageInstallOutcome.packageNotFound,
        packageKey: packageKey,
      );
    }

    final snapshot = await entitlements.loadEntitlements();
    if (!snapshot.grants(descriptor.entitlementKey)) {
      return LearningPackageInstallResult(
        outcome: LearningPackageInstallOutcome.notEntitled,
        packageKey: packageKey,
        contentVersion: descriptor.contentVersion,
      );
    }

    final installed = await InstalledLearningPackageState.load(db, packageKey);
    if (installed != null && installed.contentVersion >= descriptor.contentVersion) {
      return LearningPackageInstallResult(
        outcome: LearningPackageInstallOutcome.alreadyCurrent,
        packageKey: packageKey,
        contentVersion: installed.contentVersion,
      );
    }

    final packageBytes = await byteSource.fetch(
      source.packageUri(descriptor),
      maxBytes: descriptor.packageSizeBytes,
    );
    if (packageBytes.length != descriptor.packageSizeBytes) {
      throw FormatException(
        'Learning package size mismatch: expected '
        '${descriptor.packageSizeBytes}, received ${packageBytes.length}',
      );
    }
    if (sha256.convert(packageBytes).toString() != descriptor.packageSha256) {
      throw const FormatException('Learning package SHA-256 mismatch');
    }

    final decoded = _decodeJsonObject(packageBytes, 'Learning package');
    final package = DownloadableLearningPackage.fromDecoded(
      decoded,
      expected: descriptor,
    );

    await db.transaction((txn) async {
      final current = await InstalledLearningPackageState.load(txn, packageKey);
      if (current != null && current.contentVersion >= package.contentVersion) {
        return;
      }
      await TrainingManifestImporter.syncDecoded(txn, package.trainingContent);
      await txn.insert(
        'bundled_content_state',
        {
          'content_key': '$_learningPackageStatePrefix$packageKey',
          'revision': package.contentVersion,
          'synced_at': (installedAt ?? DateTime.now()).toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    final installedAfter = await InstalledLearningPackageState.load(db, packageKey);
    return LearningPackageInstallResult(
      outcome: LearningPackageInstallOutcome.installed,
      packageKey: packageKey,
      contentVersion: installedAfter?.contentVersion ?? package.contentVersion,
    );
  }
}

Map<String, dynamic> _decodeJsonObject(Uint8List bytes, String context) {
  Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException catch (error) {
    throw FormatException('$context is not valid UTF-8 JSON: ${error.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('$context root must be an object');
  }
  return decoded;
}

void _requireTrustedHttps(Uri uri, String context) {
  if (uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw FormatException('$context requires HTTPS without user info');
  }
}

bool _sameOrigin(Uri first, Uri second) =>
    first.scheme == second.scheme &&
    first.host.toLowerCase() == second.host.toLowerCase() &&
    _effectivePort(first) == _effectivePort(second);

int _effectivePort(Uri uri) {
  if (uri.hasPort) return uri.port;
  return uri.scheme == 'https' ? 443 : 80;
}
