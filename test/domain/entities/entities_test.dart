import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_security_suite/domain/entities/anti_tamper_status.dart';
import 'package:flutter_security_suite/domain/entities/biometric_availability.dart';
import 'package:flutter_security_suite/domain/entities/screen_capture_event.dart';

void main() {
  group('AntiTamperStatus', () {
    test('is not compromised when both checks are clean', () {
      const status = AntiTamperStatus(
        isDebuggerAttached: false,
        hasInjectedLibraries: false,
      );
      expect(status.isCompromised, isFalse);
    });

    test('is compromised when either check trips', () {
      expect(
        const AntiTamperStatus(
          isDebuggerAttached: true,
          hasInjectedLibraries: false,
        ).isCompromised,
        isTrue,
      );
      expect(
        const AntiTamperStatus(
          isDebuggerAttached: false,
          hasInjectedLibraries: true,
        ).isCompromised,
        isTrue,
      );
    });

    test('supports value equality and a readable toString', () {
      const a = AntiTamperStatus(
        isDebuggerAttached: true,
        hasInjectedLibraries: false,
      );
      const b = AntiTamperStatus(
        isDebuggerAttached: true,
        hasInjectedLibraries: false,
      );
      const c = AntiTamperStatus(
        isDebuggerAttached: true,
        hasInjectedLibraries: true,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(
        a.toString(),
        'AntiTamperStatus(isDebuggerAttached: true, '
        'hasInjectedLibraries: false)',
      );
    });
  });

  group('BiometricAvailability.fromMap', () {
    test('parses an available sensor', () {
      final result = BiometricAvailability.fromMap(const {
        'available': true,
        'type': 'face',
      });
      expect(result.isAvailable, isTrue);
      expect(result.type, BiometricType.face);
      expect(result.reason, isNull);
    });

    test('parses every known sensor type', () {
      for (final type in BiometricType.values) {
        final result = BiometricAvailability.fromMap({
          'available': false,
          'type': type.name,
        });
        expect(result.type, type);
      }
    });

    test('falls back to generic when available without a known type', () {
      for (final raw in <Object?>[null, 'retina', 42, 'none']) {
        final result = BiometricAvailability.fromMap({
          'available': true,
          'type': raw,
        });
        expect(result.type, BiometricType.generic, reason: 'type: $raw');
      }
    });

    test('keeps the reason when unavailable', () {
      final result = BiometricAvailability.fromMap(const {
        'available': false,
        'type': 'none',
        'reason': 'BIOMETRIC_NOT_ENROLLED',
      });
      expect(result.isAvailable, isFalse);
      expect(result.type, BiometricType.none);
      expect(result.reason, 'BIOMETRIC_NOT_ENROLLED');
    });

    test('drops the reason when available', () {
      final result = BiometricAvailability.fromMap(const {
        'available': true,
        'type': 'fingerprint',
        'reason': 'stale',
      });
      expect(result.reason, isNull);
    });

    test('ignores a non-string reason', () {
      final result = BiometricAvailability.fromMap(const {
        'available': false,
        'reason': 7,
      });
      expect(result.reason, isNull);
    });

    test('treats an empty map as unavailable', () {
      expect(
        BiometricAvailability.fromMap(const {}),
        BiometricAvailability.unavailable,
      );
    });

    test('treats a non-bool "available" as unavailable', () {
      for (final raw in <Object?>['true', 1, null, 'yes']) {
        final result = BiometricAvailability.fromMap({'available': raw});
        expect(result.isAvailable, isFalse, reason: 'available: $raw');
      }
    });

    test('supports value equality and toString', () {
      const a = BiometricAvailability(
        isAvailable: false,
        reason: 'BIOMETRIC_LOCKED_OUT',
      );
      const b = BiometricAvailability(
        isAvailable: false,
        reason: 'BIOMETRIC_LOCKED_OUT',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(BiometricAvailability.unavailable));
      expect(
        a.toString(),
        'BiometricAvailability(isAvailable: false, type: none, '
        'reason: BIOMETRIC_LOCKED_OUT)',
      );
    });
  });

  group('ScreenCaptureEvent.tryParse', () {
    test('parses a screenshot event', () {
      final event = ScreenCaptureEvent.tryParse(const {'type': 'screenshot'});
      expect(event, const ScreenCaptureEvent.screenshot());
      expect(event!.isCaptured, isNull);
    });

    test('parses capture start and stop', () {
      expect(
        ScreenCaptureEvent.tryParse(const {
          'type': 'captureChanged',
          'isCaptured': true,
        }),
        const ScreenCaptureEvent.captureChanged(isCaptured: true),
      );
      expect(
        ScreenCaptureEvent.tryParse(const {
          'type': 'captureChanged',
          'isCaptured': false,
        }),
        const ScreenCaptureEvent.captureChanged(isCaptured: false),
      );
    });

    test('accepts loosely typed platform maps', () {
      final Map<Object?, Object?> raw = {
        'type': 'captureChanged',
        'isCaptured': true,
        'extra': 1,
      };
      expect(
        ScreenCaptureEvent.tryParse(raw),
        const ScreenCaptureEvent.captureChanged(isCaptured: true),
      );
    });

    test('returns null for malformed payloads', () {
      final malformed = <Object?>[
        null,
        'screenshot',
        42,
        const <Object?>[],
        const <String, Object?>{},
        const {'type': 'unknown'},
        const {'type': 'captureChanged'},
        const {'type': 'captureChanged', 'isCaptured': 'true'},
        const {'type': 'captureChanged', 'isCaptured': 1},
        const {'type': 7},
      ];
      for (final raw in malformed) {
        expect(ScreenCaptureEvent.tryParse(raw), isNull, reason: '$raw');
      }
    });

    test('supports value equality and toString', () {
      const started = ScreenCaptureEvent.captureChanged(isCaptured: true);
      const stopped = ScreenCaptureEvent.captureChanged(isCaptured: false);
      expect(started, const ScreenCaptureEvent.captureChanged(isCaptured: true));
      expect(started.hashCode,
          const ScreenCaptureEvent.captureChanged(isCaptured: true).hashCode);
      expect(started, isNot(stopped));
      expect(started, isNot(const ScreenCaptureEvent.screenshot()));
      expect(started.toString(),
          'ScreenCaptureEvent.captureChanged(isCaptured: true)');
      expect(const ScreenCaptureEvent.screenshot().toString(),
          'ScreenCaptureEvent.screenshot()');
    });
  });
}
