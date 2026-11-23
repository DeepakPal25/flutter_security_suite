import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_security_suite/flutter_security_suite.dart';

void main() {
  group('StringObfuscator', () {
    test('round-trips a value', () {
      final o = StringObfuscator('seed');
      const plain = 'https://api.bank.com/v1';
      expect(o.reveal(o.obfuscate(plain)), plain);
    });

    test('round-trips unicode and empty strings', () {
      final o = StringObfuscator('seed');
      for (final plain in ['', 'a', '🔐 key: café', 'x' * 500]) {
        expect(o.reveal(o.obfuscate(plain)), plain);
      }
    });

    test('obfuscated output never contains the plaintext', () {
      final o = StringObfuscator('seed');
      final token = o.obfuscate('SUPER_SECRET_KEY');
      expect(token.contains('SUPER_SECRET_KEY'), isFalse);
    });

    test('uses a random salt so the same input differs each time', () {
      final o = StringObfuscator('seed');
      expect(o.obfuscate('same'), isNot(o.obfuscate('same')));
    });

    test('is deterministic given a fixed random source (salt)', () {
      final a = StringObfuscator('seed', random: Random(1));
      final b = StringObfuscator('seed', random: Random(1));
      expect(a.obfuscate('value'), b.obfuscate('value'));
    });

    test('a different secret cannot reveal the value as the original', () {
      final token = StringObfuscator('right').obfuscate('hello world');
      // Wrong secret either throws (invalid UTF-8) or yields other bytes,
      // but never the original string.
      String? revealed;
      try {
        revealed = StringObfuscator('wrong').reveal(token);
      } on InvalidArgumentSecurityException {
        revealed = null;
      }
      expect(revealed, isNot('hello world'));
    });

    test('rejects an empty secret', () {
      expect(
        () => StringObfuscator(''),
        throwsA(isA<InvalidArgumentSecurityException>()),
      );
    });

    test('rejects malformed tokens', () {
      final o = StringObfuscator('seed');
      expect(
        () => o.reveal('not base64!!!'),
        throwsA(isA<InvalidArgumentSecurityException>()),
      );
      expect(
        () => o.reveal('AAAA'), // valid base64 but too short for the salt
        throwsA(isA<InvalidArgumentSecurityException>()),
      );
    });
  });

  group('BuildHardeningInspector', () {
    test('reports release + stripped as hardened', () {
      final status = const BuildHardeningInspector(
        debugIsRelease: true,
        debugIsDebug: false,
        debugIsProfile: false,
        debugSymbolsStripped: true,
      ).inspect();
      expect(status.isReleaseBuild, isTrue);
      expect(status.isHardened, isTrue);
    });

    test('a debug build is not hardened', () {
      final status = const BuildHardeningInspector(
        debugIsRelease: false,
        debugIsDebug: true,
        debugIsProfile: false,
        debugSymbolsStripped: false,
      ).inspect();
      expect(status.isHardened, isFalse);
    });

    test('release without stripped symbols is not hardened', () {
      final status = const BuildHardeningInspector(
        debugIsRelease: true,
        debugIsDebug: false,
        debugIsProfile: false,
        debugSymbolsStripped: false,
      ).inspect();
      expect(status.isHardened, isFalse);
    });
  });
}
