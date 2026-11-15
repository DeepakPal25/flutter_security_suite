import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_security_suite/platform/method_channel_security.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late MethodChannelSecurity sut;
  final List<MethodCall> log = [];
  Map<String, Object?> replies = {};

  setUp(() {
    sut = MethodChannelSecurity();
    log.clear();
    replies = {};
    messenger.setMockMethodCallHandler(MethodChannelSecurity.channel, (
      MethodCall call,
    ) async {
      log.add(call);
      final reply = replies[call.method];
      if (reply is PlatformException) throw reply;
      return reply;
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(MethodChannelSecurity.channel, null);
    messenger.setMockStreamHandler(
      MethodChannelSecurity.screenCaptureEventChannel,
      null,
    );
  });

  group('anti-tamper', () {
    test('isDebuggerAttached', () async {
      replies['antitamper#isDebuggerAttached'] = true;
      expect(await sut.isDebuggerAttached(), isTrue);
      expect(log.single.method, 'antitamper#isDebuggerAttached');
    });

    test('hasInjectedLibraries', () async {
      replies['antitamper#hasInjectedLibraries'] = true;
      expect(await sut.hasInjectedLibraries(), isTrue);
      expect(log.single.method, 'antitamper#hasInjectedLibraries');
    });

    test('denyDebuggerAttachment', () async {
      replies['antitamper#denyDebugger'] = true;
      expect(await sut.denyDebuggerAttachment(), isTrue);
      expect(log.single.method, 'antitamper#denyDebugger');
    });

    test('null replies fall back to false', () async {
      expect(await sut.isDebuggerAttached(), isFalse);
      expect(await sut.hasInjectedLibraries(), isFalse);
      expect(await sut.denyDebuggerAttachment(), isFalse);
    });

    test('platform errors surface to the caller', () async {
      replies['antitamper#isDebuggerAttached'] = PlatformException(code: 'E');
      expect(sut.isDebuggerAttached(), throwsA(isA<PlatformException>()));
    });

    test('a wrongly typed reply throws instead of being coerced', () async {
      replies['antitamper#isDebuggerAttached'] = 'yes';
      expect(sut.isDebuggerAttached(), throwsA(isA<TypeError>()));
    });
  });

  group('screen capture', () {
    test('isScreenCaptured', () async {
      replies['screencapture#isCaptured'] = true;
      expect(await sut.isScreenCaptured(), isTrue);
      expect(log.single.method, 'screencapture#isCaptured');
    });

    test('isScreenCaptured falls back to false on null', () async {
      expect(await sut.isScreenCaptured(), isFalse);
    });

    test('events are delivered from the event channel', () async {
      messenger.setMockStreamHandler(
        MethodChannelSecurity.screenCaptureEventChannel,
        MockStreamHandler.inline(
          onListen: (args, events) {
            events
              ..success({'type': 'captureChanged', 'isCaptured': true})
              ..success({'type': 'screenshot'});
          },
        ),
      );

      final received = await sut.screenCaptureEvents().take(2).toList();

      expect(received, [
        {'type': 'captureChanged', 'isCaptured': true},
        {'type': 'screenshot'},
      ]);
    });

    test('native stream errors are forwarded', () async {
      messenger.setMockStreamHandler(
        MethodChannelSecurity.screenCaptureEventChannel,
        MockStreamHandler.inline(
          onListen: (args, events) {
            events.error(code: 'CAPTURE_ERROR', message: 'nope');
          },
        ),
      );

      await expectLater(
        sut.screenCaptureEvents().first,
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'CAPTURE_ERROR',
          ),
        ),
      );
    });
  });

  group('pasteboard', () {
    test('copy sends value and expiry', () async {
      await sut.pasteboardCopy(value: 'otp-123', expiresAfterMs: 30000);
      expect(log.single.method, 'pasteboard#copy');
      expect(log.single.arguments, {
        'value': 'otp-123',
        'expiresAfterMs': 30000,
      });
    });

    test('clear defaults to onlyIfOwned: false', () async {
      replies['pasteboard#clear'] = true;
      expect(await sut.pasteboardClear(), isTrue);
      expect(log.single.arguments, {'onlyIfOwned': false});
    });

    test('clear forwards onlyIfOwned and falls back to false', () async {
      expect(await sut.pasteboardClear(onlyIfOwned: true), isFalse);
      expect(log.single.method, 'pasteboard#clear');
      expect(log.single.arguments, {'onlyIfOwned': true});
    });

    test('copy surfaces platform errors', () async {
      replies['pasteboard#copy'] = PlatformException(code: 'PASTEBOARD_ERROR');
      expect(
        sut.pasteboardCopy(value: 'x', expiresAfterMs: 1),
        throwsA(isA<PlatformException>()),
      );
    });
  });

  group('biometrics', () {
    test('availability returns the native map', () async {
      replies['biometric#availability'] = {'available': true, 'type': 'face'};
      expect(await sut.biometricAvailability(), {
        'available': true,
        'type': 'face',
      });
      expect(log.single.method, 'biometric#availability');
    });

    test('availability falls back to an empty map', () async {
      expect(await sut.biometricAvailability(), isEmpty);
    });

    test('authenticate omits cancelLabel when null', () async {
      replies['biometric#authenticate'] = true;
      final ok = await sut.biometricAuthenticate(
        reason: 'Unlock',
        allowDeviceCredential: true,
      );
      expect(ok, isTrue);
      expect(log.single.method, 'biometric#authenticate');
      expect(log.single.arguments, {
        'reason': 'Unlock',
        'allowDeviceCredential': true,
      });
    });

    test('authenticate includes cancelLabel when given', () async {
      replies['biometric#authenticate'] = false;
      final ok = await sut.biometricAuthenticate(
        reason: 'Pay',
        allowDeviceCredential: false,
        cancelLabel: 'Back',
      );
      expect(ok, isFalse);
      expect(log.single.arguments, {
        'reason': 'Pay',
        'allowDeviceCredential': false,
        'cancelLabel': 'Back',
      });
    });

    test('authenticate falls back to false on null', () async {
      expect(
        await sut.biometricAuthenticate(
          reason: 'Unlock',
          allowDeviceCredential: true,
        ),
        isFalse,
      );
    });

    test('authenticate surfaces the native error code', () async {
      replies['biometric#authenticate'] = PlatformException(
        code: 'BIOMETRIC_LOCKED_OUT',
      );
      expect(
        sut.biometricAuthenticate(reason: 'x', allowDeviceCredential: true),
        throwsA(
          isA<PlatformException>().having(
            (e) => e.code,
            'code',
            'BIOMETRIC_LOCKED_OUT',
          ),
        ),
      );
    });
  });

  test('throws MissingPluginException when no native side is registered',
      () async {
    messenger.setMockMethodCallHandler(MethodChannelSecurity.channel, null);
    expect(sut.isDebuggerAttached(), throwsA(isA<MissingPluginException>()));
  });
}
