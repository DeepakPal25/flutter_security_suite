import 'package:flutter_security_suite/core/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lines = <String>[];

  setUp(() {
    lines.clear();
    SecurityLogger.debugSink = lines.add;
  });

  tearDown(() {
    SecurityLogger.disable();
    SecurityLogger.debugSink = null;
    SecurityLogger.debugReleaseModeOverride = null;
  });

  group('SecurityLogger.redact', () {
    test('fully redacts by default', () {
      expect(SecurityLogger.redact('super-secret-value'), '[REDACTED]');
    });

    test('returns "null" for null and empty for empty', () {
      expect(SecurityLogger.redact(null), 'null');
      expect(SecurityLogger.redact(''), '');
    });

    test('keeps the requested prefix and suffix', () {
      expect(
        SecurityLogger.redact('abcdefghijkl', visibleStart: 2, visibleEnd: 3),
        'ab****jkl',
      );
    });

    test('keeps only a suffix when asked', () {
      expect(
        SecurityLogger.redact('eyJhbGciOiJIUzI1NiJ9.payload.sig', visibleEnd: 4),
        '****.sig',
      );
    });

    test('keeps only a prefix when asked', () {
      expect(SecurityLogger.redact('4111111111111111', visibleStart: 4), '4111****');
    });

    test('fully redacts values too short to reveal part of', () {
      // 7 characters, 4 visible: more than half would leak.
      expect(
        SecurityLogger.redact('abcdefg', visibleStart: 2, visibleEnd: 2),
        '[REDACTED]',
      );
      expect(SecurityLogger.redact('a', visibleStart: 1), '[REDACTED]');
    });

    test('reveals at most half of the value at the boundary', () {
      expect(
        SecurityLogger.redact('abcdefgh', visibleStart: 2, visibleEnd: 2),
        'ab****gh',
      );
    });

    test('treats negative visible counts as zero', () {
      expect(
        SecurityLogger.redact('abcdefgh', visibleStart: -5, visibleEnd: -1),
        '[REDACTED]',
      );
      expect(
        SecurityLogger.redact('abcdefgh', visibleStart: -5, visibleEnd: 2),
        '****gh',
      );
    });

    test('supports a custom mask', () {
      expect(
        SecurityLogger.redact('abcdefgh', visibleEnd: 2, mask: '…'),
        '…gh',
      );
    });

    test('never returns the original value for huge visible counts', () {
      expect(
        SecurityLogger.redact('abcdefgh', visibleStart: 100, visibleEnd: 100),
        '[REDACTED]',
      );
    });
  });

  group('SecurityLogger.sanitize', () {
    test('leaves ordinary messages untouched', () {
      expect(
        SecurityLogger.sanitize('Root detection check started'),
        'Root detection check started',
      );
      expect(SecurityLogger.sanitize(''), '');
    });

    test('redacts JWTs', () {
      const jwt =
          'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N';
      final out = SecurityLogger.sanitize('got $jwt from server');
      expect(out, 'got [REDACTED] from server');
    });

    test('redacts Bearer and Basic credentials but keeps the scheme', () {
      expect(
        SecurityLogger.sanitize('Authorization: Bearer abcDEF123456789'),
        'Authorization: Bearer [REDACTED]',
      );
      expect(
        SecurityLogger.sanitize('Authorization: Basic dXNlcjpwYXNzd29yZA=='),
        'Authorization: Basic [REDACTED]',
      );
    });

    test('redacts key=value secrets case-insensitively', () {
      final out = SecurityLogger.sanitize(
        'login user=alice Password=hunter2 otp=123456&pin=4321',
      );
      expect(out, contains('user=alice'));
      expect(out, isNot(contains('hunter2')));
      expect(out, isNot(contains('123456')));
      expect(out, isNot(contains('4321')));
      expect(out, contains('Password=[REDACTED]'));
    });

    test('redacts JSON style secrets', () {
      final out = SecurityLogger.sanitize(
        '{"access_token": "abc.def", "refresh_token":"xyz123", "name": "bob"}',
      );
      expect(out, isNot(contains('abc.def')));
      expect(out, isNot(contains('xyz123')));
      expect(out, contains('"name": "bob"'));
    });

    test('redacts payment card numbers with and without separators', () {
      expect(
        SecurityLogger.sanitize('card 4111111111111111 declined'),
        'card [REDACTED] declined',
      );
      expect(
        SecurityLogger.sanitize('card 4111 1111 1111 1111 declined'),
        'card [REDACTED] declined',
      );
      expect(
        SecurityLogger.sanitize('card 4111-1111-1111-1111 declined'),
        'card [REDACTED] declined',
      );
    });

    test('does not redact short numbers', () {
      expect(
        SecurityLogger.sanitize('expires in 60000 ms, port 8443'),
        'expires in 60000 ms, port 8443',
      );
    });

    test('redacts several secrets in one message', () {
      final out = SecurityLogger.sanitize(
        'token=aaa111 secret: bbb222 api_key=ccc333',
      );
      expect(out, isNot(contains('aaa111')));
      expect(out, isNot(contains('bbb222')));
      expect(out, isNot(contains('ccc333')));
    });

    test('is idempotent', () {
      final once = SecurityLogger.sanitize('password=hunter2');
      expect(SecurityLogger.sanitize(once), once);
    });
  });

  group('SecurityLogger enable / disable', () {
    test('is disabled by default and emits nothing', () {
      expect(SecurityLogger.isEnabled, isFalse);
      SecurityLogger.info('hello');
      SecurityLogger.warning('hello');
      SecurityLogger.error('hello', error: StateError('x'));
      expect(lines, isEmpty);
    });

    test('emits once enabled in debug builds', () {
      SecurityLogger.debugReleaseModeOverride = false;
      SecurityLogger.enable();
      expect(SecurityLogger.isEnabled, isTrue);
      SecurityLogger.info('hello');
      expect(lines, ['hello']);
    });

    test('stays off in release builds', () {
      SecurityLogger.debugReleaseModeOverride = true;
      SecurityLogger.enable();
      expect(SecurityLogger.isEnabled, isFalse);
      SecurityLogger.info('hello');
      expect(lines, isEmpty);
    });

    test('enable() in release turns off logging that was on', () {
      SecurityLogger.debugReleaseModeOverride = false;
      SecurityLogger.enable();
      SecurityLogger.debugReleaseModeOverride = true;
      SecurityLogger.enable();
      expect(SecurityLogger.isEnabled, isFalse);
    });

    test('can be forced on in release with allowInRelease', () {
      SecurityLogger.debugReleaseModeOverride = true;
      SecurityLogger.enable(allowInRelease: true);
      expect(SecurityLogger.isEnabled, isTrue);
      SecurityLogger.info('hello');
      expect(lines, ['hello']);
    });

    test('disable() stops output', () {
      SecurityLogger.debugReleaseModeOverride = false;
      SecurityLogger.enable();
      SecurityLogger.disable();
      SecurityLogger.info('hello');
      expect(lines, isEmpty);
    });
  });

  group('SecurityLogger output', () {
    setUp(() {
      SecurityLogger.debugReleaseModeOverride = false;
      SecurityLogger.enable();
    });

    test('prefixes warnings and errors', () {
      SecurityLogger.warning('careful');
      SecurityLogger.error('broken', error: Exception('x'));
      expect(lines, ['⚠ careful', '✖ broken']);
    });

    test('sanitizes every level', () {
      SecurityLogger.info('token=abc12345');
      SecurityLogger.warning('password=hunter2');
      SecurityLogger.error('Bearer abcdefgh12345678');
      expect(lines.join('\n'), isNot(contains('abc12345')));
      expect(lines.join('\n'), isNot(contains('hunter2')));
      expect(lines.join('\n'), isNot(contains('abcdefgh12345678')));
      expect(lines, hasLength(3));
    });

    test('works without a sink', () {
      SecurityLogger.debugSink = null;
      expect(() => SecurityLogger.info('hello'), returnsNormally);
    });
  });
}
