import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import 'core_dataset_package.dart';
import 'core_dataset_update.dart';

abstract interface class CoreDatasetByteSource {
  Future<Uint8List> fetch(Uri uri, {required int maxBytes});
}

class HttpCoreDatasetByteSource implements CoreDatasetByteSource {
  const HttpCoreDatasetByteSource({
    this.connectionTimeout = const Duration(seconds: 15),
  });

  final Duration connectionTimeout;

  @override
  Future<Uint8List> fetch(Uri uri, {required int maxBytes}) async {
    if (!_isTrustedHttpsUri(uri)) {
      throw const FormatException('Core dataset transport requires HTTPS without user info');
    }
    if (maxBytes <= 0) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'must be positive');
    }

    final client = HttpClient()..connectionTimeout = connectionTimeout;
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Core dataset request failed with HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      if (response.contentLength > maxBytes) {
        throw FormatException(
          'Core dataset response exceeds the allowed size of $maxBytes bytes',
        );
      }

      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response) {
        received += chunk.length;
        if (received > maxBytes) {
          throw FormatException(
            'Core dataset response exceeds the allowed size of $maxBytes bytes',
          );
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }
}

class RemoteCoreDatasetUpdateSource implements CoreDatasetUpdateSource {
  RemoteCoreDatasetUpdateSource({
    required Uri manifestUri,
    required CoreDatasetByteSource byteSource,
    this.maxManifestBytes = 256 * 1024,
  })  : _manifestUri = manifestUri,
        _byteSource = byteSource {
    if (!_isTrustedHttpsUri(manifestUri)) {
      throw const FormatException(
        'Core dataset manifest endpoint requires HTTPS without user info',
      );
    }
    if (maxManifestBytes <= 0) {
      throw ArgumentError.value(
        maxManifestBytes,
        'maxManifestBytes',
        'must be positive',
      );
    }
  }

  final Uri _manifestUri;
  final CoreDatasetByteSource _byteSource;
  final int maxManifestBytes;

  Uri get manifestUri => _manifestUri;

  @override
  Future<CoreDatasetUpdateManifest> loadLatestManifest() async {
    final bytes = await _byteSource.fetch(
      _manifestUri,
      maxBytes: maxManifestBytes,
    );
    final decoded = _decodeJsonObject(bytes, 'Core dataset manifest');
    final manifest = CoreDatasetUpdateManifest.fromDecoded(decoded);
    if (!_sameOrigin(_manifestUri, manifest.packageUri)) {
      throw const FormatException(
        'Core dataset package URL must use the trusted manifest origin',
      );
    }
    return manifest;
  }
}

enum CoreDatasetUpdateOutcome {
  upToDate,
  incompatibleSchema,
  updated,
}

class CoreDatasetUpdateResult {
  const CoreDatasetUpdateResult({
    required this.outcome,
    required this.installedBefore,
    required this.latest,
    required this.installedAfter,
  });

  final CoreDatasetUpdateOutcome outcome;
  final CoreDatasetMetadata installedBefore;
  final CoreDatasetUpdateManifest latest;
  final CoreDatasetMetadata installedAfter;
}

class CoreDatasetUpdater {
  const CoreDatasetUpdater({
    required CoreDatasetUpdateSource manifestSource,
    required CoreDatasetByteSource byteSource,
  })  : _manifestSource = manifestSource,
        _byteSource = byteSource;

  final CoreDatasetUpdateSource _manifestSource;
  final CoreDatasetByteSource _byteSource;

  Future<CoreDatasetUpdateResult> checkAndApply(Database db) async {
    final installedBefore = await CoreDatasetInstalledState.load(db);
    final check = await CoreDatasetUpdateChecker(_manifestSource).check(
      installedBefore,
    );

    switch (check.disposition) {
      case CoreDatasetUpdateDisposition.upToDate:
        return CoreDatasetUpdateResult(
          outcome: CoreDatasetUpdateOutcome.upToDate,
          installedBefore: installedBefore,
          latest: check.latest,
          installedAfter: installedBefore,
        );
      case CoreDatasetUpdateDisposition.incompatibleSchema:
        return CoreDatasetUpdateResult(
          outcome: CoreDatasetUpdateOutcome.incompatibleSchema,
          installedBefore: installedBefore,
          latest: check.latest,
          installedAfter: installedBefore,
        );
      case CoreDatasetUpdateDisposition.updateAvailable:
        break;
    }

    final packageBytes = await _byteSource.fetch(
      check.latest.packageUri,
      maxBytes: check.latest.packageSizeBytes,
    );
    if (packageBytes.length != check.latest.packageSizeBytes) {
      throw FormatException(
        'Core dataset package size mismatch: expected '
        '${check.latest.packageSizeBytes}, received ${packageBytes.length}',
      );
    }

    final actualSha256 = sha256.convert(packageBytes).toString();
    if (actualSha256 != check.latest.packageSha256) {
      throw const FormatException('Core dataset package SHA-256 mismatch');
    }

    final decodedPackage = _decodeJsonObject(
      packageBytes,
      'Core dataset package',
    );
    await CoreDatasetPackageApplier.apply(
      db,
      check.latest,
      decodedPackage,
    );
    final installedAfter = await CoreDatasetInstalledState.load(db);
    return CoreDatasetUpdateResult(
      outcome: CoreDatasetUpdateOutcome.updated,
      installedBefore: installedBefore,
      latest: check.latest,
      installedAfter: installedAfter,
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

bool _isTrustedHttpsUri(Uri uri) =>
    uri.scheme == 'https' && uri.host.isNotEmpty && uri.userInfo.isEmpty;

bool _sameOrigin(Uri first, Uri second) =>
    first.scheme == second.scheme &&
    first.host.toLowerCase() == second.host.toLowerCase() &&
    _effectivePort(first) == _effectivePort(second);

int _effectivePort(Uri uri) {
  if (uri.hasPort) return uri.port;
  return uri.scheme == 'https' ? 443 : 80;
}
