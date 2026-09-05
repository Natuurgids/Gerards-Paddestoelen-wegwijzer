import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:gerards_paddestoelen_wegwijzer/src/data/learning_package_transport.dart';

void main() {
  test('authenticated source attaches runtime headers to trusted origin', () async {
    final transport = _Transport();
    var token = 'first';
    final source = AuthenticatedLearningPackageByteSource(
      trustedOrigin: Uri.parse('https://learning.example.test/catalog.json'),
      headersProvider: () async => {'Authorization': 'Bearer $token'},
      transport: transport,
    );

    final first = await source.fetch(
      Uri.parse('https://learning.example.test/catalog.json'),
      maxBytes: 32,
    );
    token = 'second';
    final second = await source.fetch(
      Uri.parse('https://learning.example.test/packages/boletes.json'),
      maxBytes: 32,
    );

    expect(first, Uint8List.fromList([1, 2, 3]));
    expect(second, Uint8List.fromList([1, 2, 3]));
    expect(transport.requests, hasLength(2));
    expect(transport.requests[0].headers['Authorization'], 'Bearer first');
    expect(transport.requests[1].headers['Authorization'], 'Bearer second');
  });

  test('cross-origin request is rejected before session headers are requested', () async {
    final transport = _Transport();
    var headerCalls = 0;
    final source = AuthenticatedLearningPackageByteSource(
      trustedOrigin: Uri.parse('https://learning.example.test/catalog.json'),
      headersProvider: () async {
        headerCalls++;
        return const {'Authorization': 'Bearer secret'};
      },
      transport: transport,
    );

    expect(
      () => source.fetch(
        Uri.parse('https://other.example.test/package.json'),
        maxBytes: 32,
      ),
      throwsA(isA<FormatException>()),
    );
    expect(headerCalls, 0);
    expect(transport.requests, isEmpty);
  });

  test('different HTTPS port is a different protected origin', () async {
    final source = AuthenticatedLearningPackageByteSource(
      trustedOrigin: Uri.parse('https://learning.example.test/catalog.json'),
      headersProvider: () async => const {'Authorization': 'Bearer secret'},
      transport: _Transport(),
    );

    expect(
      () => source.fetch(
        Uri.parse('https://learning.example.test:444/package.json'),
        maxBytes: 32,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('trusted origin must be HTTPS and contain no URL credentials', () {
    expect(
      () => AuthenticatedLearningPackageByteSource(
        trustedOrigin: Uri.parse('http://learning.example.test/catalog.json'),
        headersProvider: () async => const {},
        transport: _Transport(),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => AuthenticatedLearningPackageByteSource(
        trustedOrigin: Uri.parse(
          'https://user:pass@learning.example.test/catalog.json',
        ),
        headersProvider: () async => const {},
        transport: _Transport(),
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

class _Request {
  const _Request(this.uri, this.maxBytes, this.headers);

  final Uri uri;
  final int maxBytes;
  final Map<String, String> headers;
}

class _Transport implements LearningPackageHttpTransport {
  final List<_Request> requests = [];

  @override
  Future<Uint8List> get(
    Uri uri, {
    required int maxBytes,
    Map<String, String> headers = const <String, String>{},
  }) async {
    requests.add(_Request(uri, maxBytes, Map.of(headers)));
    return Uint8List.fromList([1, 2, 3]);
  }
}
