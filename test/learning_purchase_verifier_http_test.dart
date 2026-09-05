import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_access.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_commerce.dart';
import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_purchase_verifier_http.dart';

void main() {
  test('verifier endpoints require one HTTPS origin', () {
    expect(
      () => HttpLearningPurchaseVerifier(
        verifyUrl: 'http://verify.example.test/verify',
        entitlementsUrl: 'http://verify.example.test/entitlements',
        transport: _Transport(),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => HttpLearningPurchaseVerifier(
        verifyUrl: 'https://verify.example.test/verify',
        entitlementsUrl: 'https://other.example.test/entitlements',
        transport: _Transport(),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => HttpLearningPurchaseVerifier(
        verifyUrl: 'https://user:secret@verify.example.test/verify',
        entitlementsUrl: 'https://verify.example.test/entitlements',
        transport: _Transport(),
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('purchase verification posts store evidence and returns trusted result', () async {
    final transport = _Transport(
      responses: [
        _jsonResponse({
          'product_key': 'learning_pack_boletes_pores',
          'entitlement_key': 'learning.specialist.boletes-pores',
          'active': true,
        }),
      ],
    );
    final verifier = _verifier(
      transport,
      headersProvider: () async => const {'Authorization': 'Bearer session-token'},
    );

    final result = await verifier.verify(
      const LearningPurchaseEvidence(
        provider: LearningCommerceProvider.googlePlay,
        productKey: 'learning_pack_boletes_pores',
        transactionId: 'order-123',
        verificationPayload: 'server-verification-token',
        state: LearningPurchaseState.purchased,
      ),
    );

    expect(result.productKey, 'learning_pack_boletes_pores');
    expect(result.entitlementKey, 'learning.specialist.boletes-pores');
    expect(result.active, isTrue);
    expect(transport.requests, hasLength(1));
    final request = transport.requests.single;
    expect(request.uri.path, '/verify');
    expect(request.headers['Authorization'], 'Bearer session-token');
    expect(request.body, {
      'contract_version': 1,
      'provider': 'google_play',
      'product_key': 'learning_pack_boletes_pores',
      'transaction_id': 'order-123',
      'verification_payload': 'server-verification-token',
    });
  });

  test('nullable SDK transaction ID is sent as null and never fabricated', () async {
    final transport = _Transport(
      responses: [
        _jsonResponse({
          'product_key': 'learning_pack_boletes_pores',
          'entitlement_key': 'learning.specialist.boletes-pores',
          'active': true,
        }),
      ],
    );

    await _verifier(transport).verify(
      const LearningPurchaseEvidence(
        provider: LearningCommerceProvider.appStore,
        productKey: 'learning_pack_boletes_pores',
        transactionId: '',
        verificationPayload: 'signed-transaction',
        state: LearningPurchaseState.restored,
      ),
    );

    expect(transport.requests.single.body['provider'], 'app_store');
    expect(transport.requests.single.body['transaction_id'], isNull);
  });

  test('pending evidence never reaches trusted verifier transport', () async {
    final transport = _Transport();

    await expectLater(
      _verifier(transport).verify(
        const LearningPurchaseEvidence(
          provider: LearningCommerceProvider.googlePlay,
          productKey: 'learning_pack_boletes_pores',
          transactionId: 'order-1',
          verificationPayload: 'server-token',
          state: LearningPurchaseState.pending,
        ),
      ),
      throwsA(isA<StateError>()),
    );
    expect(transport.requests, isEmpty);
  });

  test('authoritative entitlement snapshot is decoded from server', () async {
    final transport = _Transport(
      responses: [
        _jsonResponse({
          'active_entitlements': [
            'learning.specialist.boletes-pores',
            'learning.specialist.gilled-mushrooms',
            'learning.specialist.boletes-pores',
          ],
        }),
      ],
    );

    final EntitlementSnapshot snapshot =
        await _verifier(transport).restoreVerifiedEntitlements();

    expect(snapshot.keys, {
      'learning.specialist.boletes-pores',
      'learning.specialist.gilled-mushrooms',
    });
    expect(transport.requests.single.uri.path, '/entitlements');
    expect(transport.requests.single.body, {'contract_version': 1});
  });

  test('HTTP failure and invalid responses fail closed', () async {
    final httpFailure = _Transport(
      responses: [
        const LearningVerifierHttpResponse(statusCode: 503, body: <int>[]),
      ],
    );
    await expectLater(
      _verifier(httpFailure).restoreVerifiedEntitlements(),
      throwsA(isA<StateError>()),
    );

    final invalidJson = _Transport(
      responses: [
        LearningVerifierHttpResponse(
          statusCode: 200,
          body: utf8.encode('not-json'),
        ),
      ],
    );
    await expectLater(
      _verifier(invalidJson).restoreVerifiedEntitlements(),
      throwsA(isA<FormatException>()),
    );

    final invalidShape = _Transport(
      responses: [
        _jsonResponse({'active_entitlements': [12]}),
      ],
    );
    await expectLater(
      _verifier(invalidShape).restoreVerifiedEntitlements(),
      throwsA(isA<FormatException>()),
    );
  });

  test('verification response requires typed logical entitlement fields', () async {
    final transport = _Transport(
      responses: [
        _jsonResponse({
          'product_key': 'learning_pack_boletes_pores',
          'entitlement_key': '',
          'active': true,
        }),
      ],
    );

    await expectLater(
      _verifier(transport).verify(
        const LearningPurchaseEvidence(
          provider: LearningCommerceProvider.googlePlay,
          productKey: 'learning_pack_boletes_pores',
          transactionId: 'order-1',
          verificationPayload: 'server-token',
          state: LearningPurchaseState.purchased,
        ),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

HttpLearningPurchaseVerifier _verifier(
  LearningVerifierTransport transport, {
  LearningVerifierHeadersProvider? headersProvider,
}) =>
    HttpLearningPurchaseVerifier(
      verifyUrl: 'https://verify.example.test/verify',
      entitlementsUrl: 'https://verify.example.test/entitlements',
      transport: transport,
      headersProvider: headersProvider,
    );

LearningVerifierHttpResponse _jsonResponse(Map<String, Object?> value) =>
    LearningVerifierHttpResponse(
      statusCode: 200,
      body: utf8.encode(jsonEncode(value)),
    );

class _Request {
  const _Request({
    required this.uri,
    required this.body,
    required this.headers,
  });

  final Uri uri;
  final Map<String, Object?> body;
  final Map<String, String> headers;
}

class _Transport implements LearningVerifierTransport {
  _Transport({this.responses = const <LearningVerifierHttpResponse>[]});

  final List<LearningVerifierHttpResponse> responses;
  final List<_Request> requests = [];
  int _responseIndex = 0;

  @override
  Future<LearningVerifierHttpResponse> postJson(
    Uri uri,
    Map<String, Object?> body, {
    Map<String, String> headers = const <String, String>{},
  }) async {
    requests.add(
      _Request(
        uri: uri,
        body: Map<String, Object?>.from(body),
        headers: Map<String, String>.from(headers),
      ),
    );
    if (_responseIndex >= responses.length) {
      throw StateError('No fake verifier response configured');
    }
    return responses[_responseIndex++];
  }
}
