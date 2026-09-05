import 'dart:convert';
import 'dart:io';

import 'learning_access.dart';
import 'learning_commerce.dart';

const learningPurchaseVerifyUrl = String.fromEnvironment(
  'LEARNING_PURCHASE_VERIFY_URL',
);
const learningEntitlementsUrl = String.fromEnvironment(
  'LEARNING_ENTITLEMENTS_URL',
);

const _maxVerifierResponseBytes = 64 * 1024;
const _verifierTimeout = Duration(seconds: 15);

typedef LearningVerifierHeadersProvider =
    Future<Map<String, String>> Function();

class LearningVerifierHttpResponse {
  const LearningVerifierHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final List<int> body;
}

abstract interface class LearningVerifierTransport {
  Future<LearningVerifierHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String> headers = const <String, String>{},
  });
}

class DartIoLearningVerifierTransport implements LearningVerifierTransport {
  DartIoLearningVerifierTransport({HttpClient? client})
      : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<LearningVerifierHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    final request = await _client.postUrl(uri).timeout(_verifierTimeout);
    request.followRedirects = false;
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    for (final entry in headers.entries) {
      _validateHeader(entry.key, entry.value);
      request.headers.set(entry.key, entry.value);
    }
    request.add(utf8.encode(jsonEncode(body)));

    final response = await request.close().timeout(_verifierTimeout);
    if (response.isRedirect) {
      throw StateError('Learning verifier redirects are not allowed');
    }

    final bytes = <int>[];
    await for (final chunk in response.timeout(_verifierTimeout)) {
      if (bytes.length + chunk.length > _maxVerifierResponseBytes) {
        throw StateError('Learning verifier response exceeds size limit');
      }
      bytes.addAll(chunk);
    }
    return LearningVerifierHttpResponse(
      statusCode: response.statusCode,
      body: List<int>.unmodifiable(bytes),
    );
  }

  static void _validateHeader(String name, String value) {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty ||
        normalized == 'host' ||
        normalized == 'content-length' ||
        normalized == 'content-type' ||
        name.contains('\n') ||
        name.contains('\r') ||
        value.contains('\n') ||
        value.contains('\r')) {
      throw const FormatException('Learning verifier request header is invalid');
    }
  }
}

/// Trusted server verifier for permanent learning-product entitlements.
///
/// This client transports store verification evidence to a separately managed
/// HTTPS service. It never validates Google Play/App Store receipts locally.
/// Authentication/session headers, when required, are supplied at runtime by
/// [headersProvider]; reusable server credentials must not be embedded in the
/// app bundle or compile-time defines.
class HttpLearningPurchaseVerifier implements LearningPurchaseVerifier {
  HttpLearningPurchaseVerifier({
    required String verifyUrl,
    required String entitlementsUrl,
    LearningVerifierTransport? transport,
    LearningVerifierHeadersProvider? headersProvider,
  })  : _verifyUri = _validatedUri(verifyUrl, field: 'verifyUrl'),
        _entitlementsUri = _validatedUri(
          entitlementsUrl,
          field: 'entitlementsUrl',
        ),
        _transport = transport ?? DartIoLearningVerifierTransport(),
        _headersProvider = headersProvider {
    if (!_sameOrigin(_verifyUri, _entitlementsUri)) {
      throw const FormatException(
        'Learning verifier endpoints must share one HTTPS origin',
      );
    }
  }

  factory HttpLearningPurchaseVerifier.fromEnvironment({
    LearningVerifierTransport? transport,
    LearningVerifierHeadersProvider? headersProvider,
  }) =>
      HttpLearningPurchaseVerifier(
        verifyUrl: learningPurchaseVerifyUrl,
        entitlementsUrl: learningEntitlementsUrl,
        transport: transport,
        headersProvider: headersProvider,
      );

  final Uri _verifyUri;
  final Uri _entitlementsUri;
  final LearningVerifierTransport _transport;
  final LearningVerifierHeadersProvider? _headersProvider;

  @override
  Future<VerifiedLearningPurchase> verify(
    LearningPurchaseEvidence evidence,
  ) async {
    if (evidence.state != LearningPurchaseState.purchased &&
        evidence.state != LearningPurchaseState.restored) {
      throw StateError('Only completed purchase evidence can be verified');
    }
    if (evidence.productKey.trim().isEmpty ||
        evidence.verificationPayload.trim().isEmpty) {
      throw StateError('Learning purchase evidence is incomplete');
    }

    final response = await _post(
      _verifyUri,
      <String, Object?>{
        'contract_version': 1,
        'provider': _providerWireName(evidence.provider),
        'product_key': evidence.productKey,
        'transaction_id': evidence.transactionId.trim().isEmpty
            ? null
            : evidence.transactionId,
        'verification_payload': evidence.verificationPayload,
      },
    );
    final decoded = _decodeSuccessObject(response, operation: 'verify');
    final productKey = decoded['product_key'];
    final entitlementKey = decoded['entitlement_key'];
    final active = decoded['active'];
    if (productKey is! String ||
        productKey.trim().isEmpty ||
        entitlementKey is! String ||
        entitlementKey.trim().isEmpty ||
        active is! bool) {
      throw const FormatException(
        'Learning verifier returned invalid purchase verification data',
      );
    }
    return VerifiedLearningPurchase(
      productKey: productKey,
      entitlementKey: entitlementKey,
      active: active,
    );
  }

  @override
  Future<EntitlementSnapshot> restoreVerifiedEntitlements() async {
    final response = await _post(
      _entitlementsUri,
      const <String, Object?>{'contract_version': 1},
    );
    final decoded = _decodeSuccessObject(response, operation: 'entitlements');
    final values = decoded['active_entitlements'];
    if (values is! List) {
      throw const FormatException(
        'Learning verifier returned invalid entitlement snapshot',
      );
    }
    final keys = <String>{};
    for (final value in values) {
      if (value is! String || value.trim().isEmpty) {
        throw const FormatException(
          'Learning verifier returned invalid entitlement key',
        );
      }
      keys.add(value);
    }
    return EntitlementSnapshot(keys);
  }

  Future<LearningVerifierHttpResponse> _post(
    Uri uri,
    Map<String, Object?> body,
  ) async {
    final headers = await (_headersProvider?.call() ??
        Future<Map<String, String>>.value(const <String, String>{}));
    return _transport.postJson(uri, body, headers: Map.unmodifiable(headers));
  }

  static Map<String, dynamic> _decodeSuccessObject(
    LearningVerifierHttpResponse response, {
    required String operation,
  }) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Learning verifier $operation failed with HTTP ${response.statusCode}',
      );
    }
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.body));
    } on FormatException {
      throw const FormatException('Learning verifier returned invalid JSON');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Learning verifier response must be an object');
    }
    return decoded;
  }

  static Uri _validatedUri(String raw, {required String field}) {
    if (raw.trim().isEmpty) {
      throw FormatException('$field is not configured');
    }
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.fragment.isNotEmpty) {
      throw FormatException('$field must be an HTTPS URL without userinfo/fragment');
    }
    return uri;
  }

  static bool _sameOrigin(Uri a, Uri b) =>
      a.scheme == b.scheme && a.host == b.host && a.port == b.port;

  static String _providerWireName(LearningCommerceProvider provider) =>
      switch (provider) {
        LearningCommerceProvider.googlePlay => 'google_play',
        LearningCommerceProvider.appStore => 'app_store',
      };
}
