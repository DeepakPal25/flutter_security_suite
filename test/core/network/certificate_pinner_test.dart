import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/network/certificate_pinner.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

// NOTE: no TestWidgetsFlutterBinding here – it installs HttpOverrides that
// would block the real localhost TLS connections used below.
void main() {
  final rsaDer = Fixtures.der(Fixtures.rsaCert);
  final ecDer = Fixtures.der(Fixtures.ecCert);

  group('normalizeHost', () {
    test('trims, lower-cases and strips trailing dots', () {
      expect(CertificatePinner.normalizeHost('  API.Example.COM.. '),
          'api.example.com');
      expect(CertificatePinner.normalizeHost('example.com'), 'example.com');
      expect(CertificatePinner.normalizeHost('   '), '');
    });
  });

  group('normalizePin', () {
    test('accepts plain base64', () {
      expect(CertificatePinner.normalizePin(Fixtures.rsaSpkiPin),
          Fixtures.rsaSpkiPin);
    });

    test('accepts sha256/ prefix in any case and surrounding whitespace', () {
      expect(CertificatePinner.normalizePin(' sha256/${Fixtures.rsaSpkiPin} '),
          Fixtures.rsaSpkiPin);
      expect(CertificatePinner.normalizePin('SHA256/${Fixtures.rsaSpkiPin}'),
          Fixtures.rsaSpkiPin);
    });

    test('accepts base64url and unpadded base64', () {
      final url = Fixtures.rsaCertPin.replaceAll('+', '-').replaceAll('/', '_');
      expect(CertificatePinner.normalizePin(url), Fixtures.rsaCertPin);
      final unpadded = Fixtures.rsaSpkiPin.replaceAll('=', '');
      expect(CertificatePinner.normalizePin(unpadded), Fixtures.rsaSpkiPin);
    });

    test('accepts hex in either case, with or without colons', () {
      expect(CertificatePinner.normalizePin(Fixtures.rsaCertHex),
          Fixtures.rsaCertPin);
      expect(CertificatePinner.normalizePin(Fixtures.rsaCertHex.toUpperCase()),
          Fixtures.rsaCertPin);
      final colons = RegExp('..')
          .allMatches(Fixtures.rsaCertHex)
          .map((m) => m.group(0))
          .join(':');
      expect(CertificatePinner.normalizePin(colons), Fixtures.rsaCertPin);
    });

    test('rejects empty, wrong-length and garbage pins', () {
      for (final bad in [
        '',
        '   ',
        'sha256/',
        'not a pin!',
        base64.encode(List.filled(31, 1)),
        base64.encode(List.filled(33, 1)),
        base64.encode(List.filled(20, 1)), // SHA-1 sized
        'abcd',
        '${Fixtures.rsaCertHex}00',
      ]) {
        expect(() => CertificatePinner.normalizePin(bad), throwsArgumentError,
            reason: 'pin "$bad"');
      }
    });
  });

  group('constructor validation', () {
    test('rejects blank hosts', () {
      expect(
        () => CertificatePinner(pins: {'  ': [Fixtures.rsaSpkiPin]}),
        throwsArgumentError,
      );
    });

    test('rejects bare and misplaced wildcards', () {
      for (final host in ['*', '*.', 'api.*.example.com', 'a*.example.com']) {
        expect(
          () => CertificatePinner(pins: {host: [Fixtures.rsaSpkiPin]}),
          throwsArgumentError,
          reason: host,
        );
      }
    });

    test('rejects an empty pin list', () {
      expect(
        () => CertificatePinner(pins: {'example.com': <String>[]}),
        throwsArgumentError,
      );
    });

    test('rejects a malformed pin', () {
      expect(
        () => CertificatePinner(pins: {'example.com': ['nope']}),
        throwsArgumentError,
      );
    });

    test('accepts an empty map (nothing pinned)', () {
      final pinner = CertificatePinner(pins: const {});
      expect(pinner.pinnedHosts, isEmpty);
      expect(pinner.isPinned('example.com'), isFalse);
    });

    test('normalizes hosts and de-duplicates equivalent pins', () {
      final pinner = CertificatePinner(pins: {
        ' Example.COM. ': [
          Fixtures.rsaCertPin,
          'sha256/${Fixtures.rsaCertPin}',
          Fixtures.rsaCertHex,
        ],
      });
      expect(pinner.pinnedHosts, ['example.com']);
      expect(pinner.pinsForHost('EXAMPLE.com'), {Fixtures.rsaCertPin});
    });

    test('does not alias the caller\'s map', () {
      final source = {
        'example.com': [Fixtures.rsaSpkiPin],
      };
      final pinner = CertificatePinner(pins: source);
      source['evil.com'] = [Fixtures.otherPin];
      source['example.com']!.add(Fixtures.otherPin);
      expect(pinner.isPinned('evil.com'), isFalse);
      expect(pinner.pinsForHost('example.com'), {Fixtures.rsaSpkiPin});
    });
  });

  group('host matching', () {
    final pinner = CertificatePinner(pins: {
      'api.example.com': [Fixtures.rsaSpkiPin],
      '*.example.com': [Fixtures.ecSpkiPin],
    });

    test('exact entry wins over wildcard', () {
      expect(pinner.pinsForHost('api.example.com'), {Fixtures.rsaSpkiPin});
    });

    test('wildcard matches exactly one extra label', () {
      expect(pinner.pinsForHost('www.example.com'), {Fixtures.ecSpkiPin});
      expect(pinner.pinsForHost('WWW.Example.Com.'), {Fixtures.ecSpkiPin});
      expect(pinner.isPinned('a.b.example.com'), isFalse);
      expect(pinner.isPinned('example.com'), isFalse);
    });

    test('unrelated, lookalike and empty hosts are unpinned', () {
      expect(pinner.isPinned('example.org'), isFalse);
      expect(pinner.isPinned('badexample.com'), isFalse);
      expect(pinner.isPinned('api.example.com.evil.net'), isFalse);
      expect(pinner.isPinned(''), isFalse);
      expect(pinner.isPinned('.'), isFalse);
      expect(pinner.isPinned('localhost'), isFalse);
    });
  });

  group('fingerprints', () {
    test('SPKI fingerprint matches OpenSSL for an RSA certificate', () {
      expect(CertificatePinner.spkiFingerprint(rsaDer), Fixtures.rsaSpkiPin);
    });

    test('SPKI fingerprint matches OpenSSL for an EC certificate', () {
      expect(CertificatePinner.spkiFingerprint(ecDer), Fixtures.ecSpkiPin);
    });

    test('certificate fingerprint matches OpenSSL', () {
      expect(
          CertificatePinner.certificateFingerprint(rsaDer), Fixtures.rsaCertPin);
      expect(
          CertificatePinner.certificateFingerprint(ecDer), Fixtures.ecCertPin);
    });

    test('accepts a plain List<int> as well as Uint8List', () {
      expect(CertificatePinner.spkiFingerprint(rsaDer.toList()),
          Fixtures.rsaSpkiPin);
    });

    test('extractSpki returns a well-formed SubjectPublicKeyInfo', () {
      final spki = CertificatePinner.extractSpki(rsaDer)!;
      expect(spki.first, 0x30);
      expect(spki.length, lessThan(rsaDer.length));
    });

    test('returns null instead of throwing for malformed input', () {
      final inputs = <List<int>>[
        const [],
        const [0x30],
        const [0x30, 0x82],
        const [0x30, 0x03, 0x02, 0x01, 0x01],
        const [0x04, 0x02, 0x00, 0x00],
        List.filled(64, 0xFF),
        rsaDer.sublist(0, 40),
        rsaDer.sublist(0, rsaDer.length ~/ 3),
        utf8.encode('-----BEGIN CERTIFICATE-----'),
      ];
      for (final input in inputs) {
        expect(CertificatePinner.spkiFingerprint(input), isNull,
            reason: 'length ${input.length}');
      }
    });

    test('never throws on any truncation or single-byte corruption', () {
      for (var i = 0; i < rsaDer.length; i++) {
        CertificatePinner.extractSpki(rsaDer.sublist(0, i));
      }
      for (var i = 0; i < 80; i++) {
        final copy = Uint8List.fromList(rsaDer);
        copy[i] = 0xFF;
        CertificatePinner.extractSpki(copy);
        copy[i] = 0x00;
        CertificatePinner.extractSpki(copy);
      }
    });

    test('rejects lengths that point past the end of the buffer', () {
      final copy = Uint8List.fromList(rsaDer);
      // Outer SEQUENCE uses a 2-byte long-form length; inflate it.
      expect(copy[1], 0x82);
      copy[2] = 0xFF;
      copy[3] = 0xFF;
      expect(CertificatePinner.extractSpki(copy), isNull);
    });

    test('fingerprint() follows the pinner mode', () {
      final spki = CertificatePinner(pins: const {});
      final cert =
          CertificatePinner(pins: const {}, mode: PinningMode.certificate);
      expect(spki.fingerprint(rsaDer), Fixtures.rsaSpkiPin);
      expect(cert.fingerprint(rsaDer), Fixtures.rsaCertPin);
      expect(spki.fingerprint(const []), isNull);
      expect(cert.fingerprint(const []), isNull);
    });
  });

  group('matches', () {
    test('public-key mode', () {
      final pinner = CertificatePinner(pins: {
        'localhost': [Fixtures.otherPin, Fixtures.rsaSpkiPin],
      });
      expect(pinner.matches('localhost', rsaDer), isTrue);
      expect(pinner.matches('LOCALHOST.', rsaDer), isTrue);
      expect(pinner.matches('localhost', ecDer), isFalse);
      expect(pinner.matches('localhost', const [1, 2, 3]), isFalse);
      expect(pinner.matches('localhost', const []), isFalse);
    });

    test('a certificate hash does not satisfy public-key mode (and back)', () {
      final spkiMode = CertificatePinner(pins: {
        'localhost': [Fixtures.rsaCertPin],
      });
      final certMode = CertificatePinner(
        pins: {
          'localhost': [Fixtures.rsaSpkiPin],
        },
        mode: PinningMode.certificate,
      );
      expect(spkiMode.matches('localhost', rsaDer), isFalse);
      expect(certMode.matches('localhost', rsaDer), isFalse);
    });

    test('certificate mode', () {
      final pinner = CertificatePinner(
        pins: {
          'localhost': [Fixtures.rsaCertHex],
        },
        mode: PinningMode.certificate,
      );
      expect(pinner.matches('localhost', rsaDer), isTrue);
      expect(pinner.matches('localhost', ecDer), isFalse);
    });

    test('unpinned hosts follow rejectUnpinnedHosts', () {
      final lenient = CertificatePinner(pins: {
        'localhost': [Fixtures.rsaSpkiPin],
      });
      final strict = CertificatePinner(
        pins: {
          'localhost': [Fixtures.rsaSpkiPin],
        },
        rejectUnpinnedHosts: true,
      );
      expect(lenient.matches('other.test', ecDer), isTrue);
      expect(strict.matches('other.test', ecDer), isFalse);
      expect(strict.matches('localhost', rsaDer), isTrue);
    });
  });

  group('check', () {
    test('passes for unpinned hosts unless strict, even without a cert', () {
      final lenient = CertificatePinner(pins: const {});
      expect(() => lenient.check('example.com', null), returnsNormally);

      final strict =
          CertificatePinner(pins: const {}, rejectUnpinnedHosts: true);
      expect(
        () => strict.check('example.com', null),
        throwsA(isA<CertificatePinningException>()
            .having((e) => e.host, 'host', 'example.com')),
      );
    });

    test('throws when a pinned host presents no certificate', () {
      final pinner = CertificatePinner(pins: {
        'localhost': [Fixtures.rsaSpkiPin],
      });
      expect(
        () => pinner.check('localhost', null),
        throwsA(isA<CertificatePinningException>().having(
            (e) => e.message, 'message', contains('no certificate'))),
      );
    });
  });

  group('against a real TLS server', () {
    late HttpServer server;
    late int port;
    final clientContext = Fixtures.clientContext();

    setUp(() async {
      server = await HttpServer.bindSecure(
        'localhost',
        0,
        Fixtures.serverContext(),
      );
      port = server.port;
      server.listen((request) {
        request.response
          ..write('secret-payload')
          ..close();
      });
    });

    tearDown(() => server.close(force: true));

    Future<String> fetch(HttpClient client, String url) async {
      try {
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        return await utf8.decodeStream(response);
      } finally {
        client.close(force: true);
      }
    }

    test('correct public-key pin: request succeeds', () async {
      final pinner = CertificatePinner(pins: {
        'localhost': [Fixtures.rsaSpkiPin],
      });
      final body = await fetch(
        pinner.createHttpClient(context: clientContext),
        'https://localhost:$port/',
      );
      expect(body, 'secret-payload');
    });

    test('correct certificate pin: request succeeds', () async {
      final pinner = CertificatePinner(
        pins: {
          'localhost': [Fixtures.rsaCertPin],
        },
        mode: PinningMode.certificate,
      );
      final body = await fetch(
        pinner.createHttpClient(context: clientContext),
        'https://localhost:$port/',
      );
      expect(body, 'secret-payload');
    });

    test('backup pin listed next to a stale pin still succeeds', () async {
      final pinner = CertificatePinner(pins: {
        'localhost': [Fixtures.otherPin, Fixtures.rsaSpkiPin],
      });
      final body = await fetch(
        pinner.createHttpClient(context: clientContext),
        'https://localhost:$port/',
      );
      expect(body, 'secret-payload');
    });

    test('wrong pin: connection is refused before any request is served',
        () async {
      var served = 0;
      await server.close(force: true);
      server = await HttpServer.bindSecure(
        'localhost',
        port,
        Fixtures.serverContext(),
      );
      server.listen((request) {
        served++;
        request.response.close();
      });

      // The certificate is trusted by the client context (a "valid" MITM
      // certificate), but its key is not the pinned one.
      final pinner = CertificatePinner(pins: {
        'localhost': [Fixtures.ecSpkiPin],
      });
      await expectLater(
        fetch(
          pinner.createHttpClient(context: clientContext),
          'https://localhost:$port/',
        ),
        throwsA(isA<CertificatePinningException>()
            .having((e) => e.host, 'host', 'localhost')
            .having((e) => e.message, 'message', contains('mismatch'))),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(served, 0);
    });

    test('server key rotated to an unpinned key is rejected', () async {
      await server.close(force: true);
      server = await HttpServer.bindSecure(
        'localhost',
        port,
        Fixtures.serverContext(ec: true),
      );
      server.listen((request) => request.response.close());

      final pinner = CertificatePinner(pins: {
        'localhost': [Fixtures.rsaSpkiPin],
      });
      await expectLater(
        fetch(
          pinner.createHttpClient(context: clientContext),
          'https://localhost:$port/',
        ),
        throwsA(isA<CertificatePinningException>()),
      );
    });

    test('EC certificate with matching pin succeeds', () async {
      await server.close(force: true);
      server = await HttpServer.bindSecure(
        'localhost',
        port,
        Fixtures.serverContext(ec: true),
      );
      server.listen((request) {
        request.response
          ..write('ec')
          ..close();
      });
      final pinner = CertificatePinner(pins: {
        'localhost': [Fixtures.ecSpkiPin],
      });
      final body = await fetch(
        pinner.createHttpClient(context: clientContext),
        'https://localhost:$port/',
      );
      expect(body, 'ec');
    });

    test('pinning never bypasses normal trust validation', () async {
      // Correct pin, but the client does not trust the self-signed cert.
      final pinner = CertificatePinner(pins: {
        'localhost': [Fixtures.rsaSpkiPin],
      });
      await expectLater(
        fetch(
          pinner.createHttpClient(
            context: SecurityContext(withTrustedRoots: false),
          ),
          'https://localhost:$port/',
        ),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('unpinned host is allowed by default', () async {
      final pinner = CertificatePinner(pins: {
        'api.example.com': [Fixtures.otherPin],
      });
      final body = await fetch(
        pinner.createHttpClient(context: clientContext),
        'https://localhost:$port/',
      );
      expect(body, 'secret-payload');
    });

    test('unpinned host is refused with rejectUnpinnedHosts', () async {
      final pinner = CertificatePinner(
        pins: {
          'api.example.com': [Fixtures.otherPin],
        },
        rejectUnpinnedHosts: true,
      );
      await expectLater(
        fetch(
          pinner.createHttpClient(context: clientContext),
          'https://localhost:$port/',
        ),
        throwsA(isA<CertificatePinningException>()
            .having((e) => e.message, 'message', contains('No pins'))),
      );
    });

    test('cleartext http to a pinned host is refused', () async {
      final plain = await HttpServer.bind('localhost', 0);
      var served = 0;
      plain.listen((request) {
        served++;
        request.response.close();
      });
      addTearDown(() => plain.close(force: true));

      final pinner = CertificatePinner(pins: {
        'localhost': [Fixtures.rsaSpkiPin],
      });
      await expectLater(
        fetch(pinner.createHttpClient(), 'http://localhost:${plain.port}/'),
        throwsA(isA<CertificatePinningException>()
            .having((e) => e.message, 'message', contains('cleartext'))),
      );
      expect(served, 0);
    });

    test('cleartext http to an unpinned host works unless strict', () async {
      final plain = await HttpServer.bind('localhost', 0);
      plain.listen((request) {
        request.response
          ..write('plain')
          ..close();
      });
      addTearDown(() => plain.close(force: true));

      final lenient = CertificatePinner(pins: {
        'api.example.com': [Fixtures.otherPin],
      });
      expect(
        await fetch(
            lenient.createHttpClient(), 'http://localhost:${plain.port}/'),
        'plain',
      );

      final strict = CertificatePinner(
        pins: {
          'api.example.com': [Fixtures.otherPin],
        },
        rejectUnpinnedHosts: true,
      );
      await expectLater(
        fetch(strict.createHttpClient(), 'http://localhost:${plain.port}/'),
        throwsA(isA<CertificatePinningException>()),
      );
    });

    test('a redirect from a pinned host to cleartext is refused', () async {
      await server.close(force: true);
      server = await HttpServer.bindSecure(
        'localhost',
        port,
        Fixtures.serverContext(),
      );
      server.listen((request) {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, 'http://localhost:1/x')
          ..close();
      });
      final pinner = CertificatePinner(pins: {
        'localhost': [Fixtures.rsaSpkiPin],
      });
      await expectLater(
        fetch(
          pinner.createHttpClient(context: clientContext),
          'https://localhost:$port/',
        ),
        throwsA(isA<CertificatePinningException>()),
      );
    });

    test('several requests on one client all succeed', () async {
      final pinner = CertificatePinner(pins: {
        'localhost': [Fixtures.rsaSpkiPin],
      });
      final client = pinner.createHttpClient(context: clientContext);
      addTearDown(() => client.close(force: true));
      for (var i = 0; i < 3; i++) {
        final request =
            await client.getUrl(Uri.parse('https://localhost:$port/$i'));
        final response = await request.close();
        expect(await utf8.decodeStream(response), 'secret-payload');
      }
    });

    group('validateHost', () {
      test('true for a matching pin', () async {
        final pinner = CertificatePinner(pins: {
          'localhost': [Fixtures.rsaSpkiPin],
        });
        expect(
          await pinner.validateHost('localhost',
              port: port, context: clientContext),
          isTrue,
        );
      });

      test('false for a mismatching pin', () async {
        final pinner = CertificatePinner(pins: {
          'localhost': [Fixtures.ecSpkiPin],
        });
        expect(
          await pinner.validateHost('localhost',
              port: port, context: clientContext),
          isFalse,
        );
      });

      test('false without connecting when the host is unpinned', () async {
        final pinner = CertificatePinner(pins: {
          'api.example.com': [Fixtures.rsaSpkiPin],
        });
        // Port 1 would fail to connect – proves no connection is attempted.
        expect(await pinner.validateHost('localhost', port: 1), isFalse);
      });

      test('throws when the certificate is untrusted', () async {
        final pinner = CertificatePinner(pins: {
          'localhost': [Fixtures.rsaSpkiPin],
        });
        await expectLater(
          pinner.validateHost(
            'localhost',
            port: port,
            context: SecurityContext(withTrustedRoots: false),
          ),
          throwsA(isA<HandshakeException>()),
        );
      });

      test('throws when nothing is listening', () async {
        final closed = await ServerSocket.bind('localhost', 0);
        final deadPort = closed.port;
        await closed.close();
        final pinner = CertificatePinner(pins: {
          'localhost': [Fixtures.rsaSpkiPin],
        });
        await expectLater(
          pinner.validateHost('localhost',
              port: deadPort, context: clientContext),
          throwsA(isA<SocketException>()),
        );
      });

      test('times out against a server that never completes the handshake',
          () async {
        final silent = await ServerSocket.bind('localhost', 0);
        final sockets = <Socket>[];
        silent.listen(sockets.add);
        addTearDown(() async {
          for (final s in sockets) {
            s.destroy();
          }
          await silent.close();
        });
        final pinner = CertificatePinner(pins: {
          'localhost': [Fixtures.rsaSpkiPin],
        });
        await expectLater(
          pinner.validateHost(
            'localhost',
            port: silent.port,
            context: clientContext,
            timeout: const Duration(milliseconds: 300),
          ),
          throwsA(isA<TimeoutException>()),
        );
      });
    });
  });
}
