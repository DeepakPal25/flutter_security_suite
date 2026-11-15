import 'dart:io';

import 'package:flutter_security_suite/core/network/certificate_pinner.dart';
import 'package:flutter_security_suite/data/datasources/certificate_pinning_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/certificate_pinning_repository_impl.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../fixtures/fixtures.dart';

void main() {
  group('parseHost', () {
    test('bare host defaults to port 443', () {
      final r = CertificatePinningDatasource.parseHost('api.example.com');
      expect(r.host, 'api.example.com');
      expect(r.port, 443);
    });

    test('host:port', () {
      final r = CertificatePinningDatasource.parseHost(' Example.com:8443 ');
      expect(r.host, 'example.com');
      expect(r.port, 8443);
    });

    test('IPv4 and bracketed IPv6', () {
      expect(CertificatePinningDatasource.parseHost('127.0.0.1:9000'),
          (host: '127.0.0.1', port: 9000));
      expect(CertificatePinningDatasource.parseHost('[::1]:9000'),
          (host: '::1', port: 9000));
      expect(CertificatePinningDatasource.parseHost('[::1]'),
          (host: '::1', port: 443));
    });

    test('rejects everything that is not a plain host', () {
      for (final bad in [
        '',
        '   ',
        'https://example.com',
        'example.com/path',
        'user@example.com',
        'user:pw@example.com',
        'example.com?x=1',
        'example.com#frag',
        'exa mple.com',
        r'example.com\evil',
        '*.example.com',
        'example.com:0',
        'example.com:70000',
        'example.com:abc',
        ':443',
      ]) {
        expect(() => CertificatePinningDatasource.parseHost(bad),
            throwsArgumentError,
            reason: '"$bad"');
      }
    });
  });

  group('validateCertificate', () {
    late HttpServer server;

    setUp(() async {
      server = await HttpServer.bindSecure(
          'localhost', 0, Fixtures.serverContext());
      server.listen((r) => r.response.close());
    });

    tearDown(() => server.close(force: true));

    test('true for a matching public-key pin', () async {
      final ds = CertificatePinningDatasource(
          securityContext: Fixtures.clientContext());
      expect(
        await ds.validateCertificate(
          host: 'localhost:${server.port}',
          pins: ['sha256/${Fixtures.rsaSpkiPin}'],
        ),
        isTrue,
      );
    });

    test('false for a mismatch', () async {
      final ds = CertificatePinningDatasource(
          securityContext: Fixtures.clientContext());
      expect(
        await ds.validateCertificate(
          host: 'localhost:${server.port}',
          pins: [Fixtures.otherPin],
        ),
        isFalse,
      );
    });

    test('certificate mode compares the whole certificate', () async {
      final ds = CertificatePinningDatasource(
        mode: PinningMode.certificate,
        securityContext: Fixtures.clientContext(),
      );
      expect(
        await ds.validateCertificate(
          host: 'localhost:${server.port}',
          pins: [Fixtures.rsaCertHex],
        ),
        isTrue,
      );
      expect(
        await ds.validateCertificate(
          host: 'localhost:${server.port}',
          pins: [Fixtures.rsaSpkiPin],
        ),
        isFalse,
      );
    });

    test('empty pin list is false without connecting', () async {
      final ds = CertificatePinningDatasource();
      expect(
        await ds.validateCertificate(host: 'localhost:1', pins: const []),
        isFalse,
      );
    });

    test('malformed host is rejected even with an empty pin list', () {
      final ds = CertificatePinningDatasource();
      expect(
        ds.validateCertificate(host: 'https://x.test', pins: const []),
        throwsArgumentError,
      );
    });

    test('malformed pin throws ArgumentError', () {
      final ds = CertificatePinningDatasource();
      expect(
        ds.validateCertificate(host: 'localhost:1', pins: const ['short']),
        throwsArgumentError,
      );
    });

    test('repository turns every failure into a Failure result', () async {
      final repo = CertificatePinningRepositoryImpl(
        CertificatePinningDatasource(securityContext: Fixtures.clientContext()),
      );

      final ok = await repo.validateCertificate(
        host: 'localhost:${server.port}',
        pins: [Fixtures.rsaSpkiPin],
      );
      expect(ok.dataOrNull, isTrue);

      final mismatch = await repo.validateCertificate(
        host: 'localhost:${server.port}',
        pins: [Fixtures.ecSpkiPin],
      );
      expect(mismatch.dataOrNull, isFalse);

      final badHost = await repo.validateCertificate(
        host: 'https://localhost',
        pins: [Fixtures.rsaSpkiPin],
      );
      expect(badHost.isFailure, isTrue);

      final badPin = await repo.validateCertificate(
        host: 'localhost:${server.port}',
        pins: const ['bogus'],
      );
      badPin.fold(
        onSuccess: (_) => fail('expected failure'),
        onFailure: (e) {
          expect(e, isA<CertificatePinningException>());
          expect(e.originalError, isA<ArgumentError>());
        },
      );

      // Trusted-roots-only client must not accept the self-signed server.
      final untrusted = await CertificatePinningRepositoryImpl(
        CertificatePinningDatasource(
          securityContext: SecurityContext(withTrustedRoots: false),
        ),
      ).validateCertificate(
        host: 'localhost:${server.port}',
        pins: [Fixtures.rsaSpkiPin],
      );
      expect(untrusted.isFailure, isTrue);
    });
  });
}
