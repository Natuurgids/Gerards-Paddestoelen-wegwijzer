import 'dart:io';
import 'dart:typed_data';

import 'core_dataset_transport.dart';
import 'learning_purchase_verifier_http.dart';

const _learningPackageRequestTimeout = Duration(seconds: 15);

abstract interface class LearningPackageHttpTransport {
  Future<Uint8List> get(
    Uri uri, {
    required int maxBytes,
    Map<String, String> headers = const <String, String>{},
  });
}

class DartIoLearningPackageHttpTransport implements LearningPackageHttpTransport {
  const DartIoLearningPackageHttpTransport({
    this.connectionTimeout = _learningPackageRequestTimeout,
  });

  final Duration connectionTimeout;

  @override
  Future<Uint8List> get(
    Uri uri, {
    required int maxBytes,
    Map<String, String> headers = const <String, String>{},
  }) async {
    if (!_isTrustedHttpsUri(uri)) {
      throw const FormatException(
        'Learning package transport requires HTTPS without user info',
      );
    }
    if (maxBytes <= 0) {
      throw ArgumentError.value(maxBytes, 'maxBytes', 'must be positive');
    }

    final client = HttpClient()..connectionTimeout = connectionTimeout;
    try {
      final request = await client.getUrl(uri).timeout(connectionTimeout);
      request.followRedirects = false;
      for (final entry in headers.entries) {
        _validateHeader(entry.key, entry.value);
        request.headers.set(entry.key, entry.value);
      }
      final response = await request.close().timeout(connectionTimeout);
      if (response.isRedirect) {
        throw StateError('Learning package redirects are not allowed');
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Learning package request failed with HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      if (response.contentLength > maxBytes) {
        throw FormatException(
          'Learning package response exceeds the allowed size of $maxBytes bytes',
        );
      }

      final builder = BytesBuilder(copy: false);
      var received = 0;
      await for (final chunk in response.timeout(connectionTimeout)) {
        received += chunk.length;
        if (received > maxBytes) {
          throw FormatException(
            'Learning package response exceeds the allowed size of $maxBytes bytes',
          );
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    } finally {
      client.close(force: true);
    }
  }

  static void _validateHeader(String name, String value) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'host' ||
        normalized == 'content-length' ||
        name.contains('\n') ||
        name.contains('\r') ||
        value.contains('\n') ||
        value.contains('\r')) {
      throw const FormatException('Learning package request header is invalid');
    }
  }
}

/// Binds authenticated paid-learning delivery to one trusted HTTPS origin.
///
/// Runtime session headers are obtained for each request so short-lived tokens
/// can rotate. Redirects are refused by the production transport and this byte
/// source refuses any request outside the configured catalogue origin, preventing
/// authentication headers from being forwarded to another host.
class AuthenticatedLearningPackageByteSource implements CoreDatasetByteSource {
  AuthenticatedLearningPackageByteSource({
    required Uri trustedOrigin,
    required LearningVerifierHeadersProvider headersProvider,
    LearningPackageHttpTransport? transport,
  })  : _trustedOrigin = _validatedOrigin(trustedOrigin),
        _headersProvider = headersProvider,
        _transport = transport ?? const DartIoLearningPackageHttpTransport();

  final Uri _trustedOrigin;
  final LearningVerifierHeadersProvider _headersProvider;
  final LearningPackageHttpTransport _transport;

  @override
  Future<Uint8List> fetch(Uri uri, {required int maxBytes}) async {
    if (!_isTrustedHttpsUri(uri) || !_sameOrigin(_trustedOrigin, uri)) {
      throw const FormatException(
        'Learning package request must use the trusted catalogue origin',
      );
    }
    final headers = await _headersProvider();
    return _transport.get(
      uri,
      maxBytes: maxBytes,
      headers: Map.unmodifiable(headers),
    );
  }

  static Uri _validatedOrigin(Uri uri) {
    if (!_isTrustedHttpsUri(uri) || uri.fragment.isNotEmpty) {
      throw const FormatException(
        'Learning package trusted origin must be HTTPS without user info/fragment',
      );
    }
    return uri;
  }
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
