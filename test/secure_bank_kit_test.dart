import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_security_suite/flutter_security_suite.dart';
import 'package:flutter_security_suite/platform/method_channel_security.dart';

/// End-to-end tests of the public facade, with only the platform channel
/// replaced.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final List<MethodCall> log = [];
  final Map<String, String> store = {};
  Map<String, Object?> replies = {};
  bool failEverything = false;

  void installHandler() {
    messenger.setMockMethodCallHandler(MethodChannelSecurity.channel, (
      MethodCall call,
    ) async {
      log.add(call);
      if (failEverything) throw PlatformException(code: 'BOOM');
      final args = (call.arguments as Map?) ?? const {};
      switch (call.method) {
        case 'storage#write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'storage#read':
          return store[args['key']];
        case 'storage#delete':
          store.remove(args['key']);
          return null;
        case 'storage#deleteAll':
          store.clear();
          return null;
      }
      final reply = replies[call.method];
      if (reply is PlatformException) throw reply;
      return reply;
    });
  }

  setUp(() {
    log.clear();
    store.clear();
    replies = {};
    failEverything = false;
    installHandler();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(MethodChannelSecurity.channel, null);
    messenger.setMockStreamHandler(
      MethodChannelSecurity.screenCaptureEventChannel,
      null,
    );
  });

  group('runSecurityCheck', () {
    test('reports a clean device', () async {
      replies = {
        'root#isDeviceRooted': false,
        'integrity#isValid': true,
        'emulator#isEmulator': false,
        'tamper#isTampered': false,
        'runtime#isHooked': false,
      };
      final status = await SecureBankKit.initialize().runSecurityCheck();
      expect(status.isSecure, isTrue);
    });

    test('fails secure when every native check errors', () async {
      failEverything = true;
      final status = await SecureBankKit.initialize().runSecurityCheck();
      expect(status.isRooted, isTrue);
      expect(status.isAppIntegrityValid, isFalse);
      expect(status.isTampered, isTrue);
      expect(status.isSecure, isFalse);
    });

    test('fails secure when the plugin is not registered', () async {
      messenger.setMockMethodCallHandler(MethodChannelSecurity.channel, null);
      final status = await SecureBankKit.initialize().runSecurityCheck();
      expect(status.isRooted, isTrue);
      expect(status.isTampered, isTrue);
      expect(status.isSecure, isFalse);
    });

    test('skips disabled checks', () async {
      final kit = SecureBankKit.initialize(
        enableRootDetection: false,
        enableAppIntegrity: false,
        enableEmulatorDetection: false,
        enableTamperDetection: false,
        enableRuntimeProtection: false,
      );
      final status = await kit.runSecurityCheck();
      expect(log, isEmpty);
      expect(status.isSecure, isTrue);
    });
  });

  group('antiTamper', () {
    test('check combines both native probes', () async {
      replies = {
        'antitamper#isDebuggerAttached': false,
        'antitamper#hasInjectedLibraries': true,
      };
      final result = await SecureBankKit.initialize().antiTamper.check();
      expect(
        result.dataOrNull,
        const AntiTamperStatus(
          isDebuggerAttached: false,
          hasInjectedLibraries: true,
        ),
      );
    });

    test('returns a Failure rather than throwing', () async {
      failEverything = true;
      final kit = SecureBankKit.initialize();
      expect((await kit.antiTamper.check()).isFailure, isTrue);
      expect((await kit.antiTamper.isDebuggerAttached()).isFailure, isTrue);
      expect((await kit.antiTamper.hasInjectedLibraries()).isFailure, isTrue);
      expect(
        (await kit.antiTamper.denyDebuggerAttachment()).isFailure,
        isTrue,
      );
    });
  });

  group('screenCapture', () {
    void emit(List<Map<String, Object?>> payloads) {
      messenger.setMockStreamHandler(
        MethodChannelSecurity.screenCaptureEventChannel,
        MockStreamHandler.inline(
          onListen: (args, events) {
            for (final payload in payloads) {
              events.success(payload);
            }
          },
        ),
      );
    }

    test('events parses native payloads and drops malformed ones', () async {
      emit([
        {'type': 'captureChanged', 'isCaptured': true},
        {'type': 'garbage'},
        {'type': 'screenshot'},
      ]);
      final events =
          await SecureBankKit.initialize().screenCapture.events.take(2).toList();
      expect(events, const [
        ScreenCaptureEvent.captureChanged(isCaptured: true),
        ScreenCaptureEvent.screenshot(),
      ]);
    });

    test('onCaptureChanged only emits capture state', () async {
      emit([
        {'type': 'screenshot'},
        {'type': 'captureChanged', 'isCaptured': true},
        {'type': 'captureChanged', 'isCaptured': false},
      ]);
      final states = await SecureBankKit.initialize()
          .screenCapture
          .onCaptureChanged
          .take(2)
          .toList();
      expect(states, [true, false]);
    });

    test('onScreenshot only emits screenshots', () async {
      emit([
        {'type': 'captureChanged', 'isCaptured': true},
        {'type': 'screenshot'},
      ]);
      await expectLater(
        SecureBankKit.initialize().screenCapture.onScreenshot.first,
        completes,
      );
    });

    test('isCaptured returns the native value or a Failure', () async {
      replies['screencapture#isCaptured'] = true;
      final kit = SecureBankKit.initialize();
      expect((await kit.screenCapture.isCaptured()).dataOrNull, isTrue);
      failEverything = true;
      expect((await kit.screenCapture.isCaptured()).isFailure, isTrue);
    });
  });

  group('pasteboard', () {
    test('copy uses a 60 second default expiry', () async {
      final result = await SecureBankKit.initialize().pasteboard.copy('otp');
      expect(result.isSuccess, isTrue);
      expect(log.single.method, 'pasteboard#copy');
      expect(log.single.arguments, {'value': 'otp', 'expiresAfterMs': 60000});
    });

    test('invalid input never reaches the platform', () async {
      final kit = SecureBankKit.initialize();
      expect((await kit.pasteboard.copy('')).isFailure, isTrue);
      expect(
        (await kit.pasteboard.copy('x', expiresAfter: Duration.zero))
            .isFailure,
        isTrue,
      );
      expect(
        (await kit.pasteboard.copy('x', expiresAfter: const Duration(hours: 2)))
            .isFailure,
        isTrue,
      );
      expect(log, isEmpty);
    });

    test('clear forwards onlyIfOwned', () async {
      replies['pasteboard#clear'] = true;
      final result = await SecureBankKit.initialize().pasteboard.clear(
        onlyIfOwned: true,
      );
      expect(result.dataOrNull, isTrue);
      expect(log.single.arguments, {'onlyIfOwned': true});
    });
  });

  group('biometrics', () {
    test('checkAvailability parses the native reply', () async {
      replies['biometric#availability'] = {
        'available': true,
        'type': 'fingerprint',
      };
      final result =
          await SecureBankKit.initialize().biometrics.checkAvailability();
      expect(result.dataOrNull!.type, BiometricType.fingerprint);
    });

    test('authenticate maps native error codes', () async {
      replies['biometric#authenticate'] = PlatformException(
        code: BiometricException.notEnrolled,
        message: 'none enrolled',
      );
      final result = await SecureBankKit.initialize().biometrics.authenticate(
        reason: 'Unlock',
      );
      final error = (result as Failure).error;
      expect(error, isA<BiometricException>());
      expect(error.code, BiometricException.notEnrolled);
    });

    test('an unregistered plugin reports notAvailable', () async {
      messenger.setMockMethodCallHandler(MethodChannelSecurity.channel, null);
      final kit = SecureBankKit.initialize();
      expect(
        ((await kit.biometrics.checkAvailability()) as Failure).error.code,
        BiometricException.notAvailable,
      );
      expect(
        ((await kit.biometrics.authenticate(reason: 'Unlock')) as Failure)
            .error
            .code,
        BiometricException.notAvailable,
      );
    });

    test('a blank reason is rejected before prompting', () async {
      final result = await SecureBankKit.initialize().biometrics.authenticate(
        reason: '  ',
      );
      expect(
        (result as Failure).error.code,
        BiometricException.invalidArguments,
      );
      expect(log, isEmpty);
    });
  });

  group('tokens', () {
    test('token storage round-trips through secure storage', () async {
      final kit = SecureBankKit.initialize();
      await kit.tokenStorage.saveTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
      );
      expect(store['sbk.access_token'], 'access-1');
      expect(store['sbk.refresh_token'], 'refresh-1');
      expect((await kit.tokenStorage.getAccessToken()).dataOrNull, 'access-1');

      await kit.tokenStorage.clearTokens();
      expect(store, isEmpty);
    });

    test('tokenNamespace changes the storage keys', () async {
      final kit = SecureBankKit.initialize(tokenNamespace: 'bank');
      await kit.tokenStorage.saveAccessToken('a');
      expect(store.keys, ['bank.access_token']);
      expect(kit.tokenExpiry.expiryKey, 'bank.token_expiry');
    });

    test('a blank tokenNamespace is rejected', () {
      expect(
        () => SecureBankKit.initialize(tokenNamespace: ' '),
        throwsArgumentError,
      );
    });

    test('token expiry is persisted and evaluated', () async {
      final kit = SecureBankKit.initialize();
      expect(await kit.tokenExpiry.isTokenExpired(), isTrue);

      await kit.tokenExpiry.setExpiresIn(const Duration(hours: 1));
      expect(store.containsKey('sbk.token_expiry'), isTrue);
      expect(await kit.tokenExpiry.isTokenExpired(), isFalse);
      expect(
        await kit.tokenExpiry.shouldRefreshToken(
          buffer: const Duration(hours: 2),
        ),
        isTrue,
      );
    });

    test('storage errors come back as Failures', () async {
      failEverything = true;
      final kit = SecureBankKit.initialize();
      expect((await kit.tokenStorage.saveAccessToken('a')).isFailure, isTrue);
      expect((await kit.tokenStorage.getAccessToken()).isFailure, isTrue);
    });
  });

  group('managers', () {
    test('a session manager wipes tokens when the session ends', () async {
      final kit = SecureBankKit.initialize();
      await kit.tokenStorage.saveTokens(
        accessToken: 'a',
        refreshToken: 'r',
      );
      final session = kit.createSessionManager(
        timeout: const Duration(minutes: 5),
      );
      session.startSession();
      expect(session.isActive, isTrue);

      final result = await session.endSession();

      expect(result.isSuccess, isTrue);
      expect(session.isActive, isFalse);
      expect(store.containsKey('sbk.access_token'), isFalse);
      expect(store.containsKey('sbk.refresh_token'), isFalse);
      await session.dispose();
    });

    test('createSessionManager rejects a non-positive timeout', () {
      final kit = SecureBankKit.initialize();
      expect(
        () => kit.createSessionManager(timeout: Duration.zero),
        throwsArgumentError,
      );
    });

    test('an app lock manager unlocks through the biometric channel',
        () async {
      replies['biometric#authenticate'] = true;
      final lock = SecureBankKit.initialize().createAppLockManager(
        reason: 'Unlock the vault',
      );
      lock.lock();
      expect(lock.isLocked, isTrue);

      final result = await lock.unlock();

      expect(result.dataOrNull, isTrue);
      expect(lock.isLocked, isFalse);
      final call = log.singleWhere((c) => c.method == 'biometric#authenticate');
      expect((call.arguments as Map)['reason'], 'Unlock the vault');
      await lock.dispose();
    });

    test('the app stays locked when authentication fails', () async {
      replies['biometric#authenticate'] = PlatformException(
        code: BiometricException.lockedOut,
      );
      final lock = SecureBankKit.initialize().createAppLockManager();
      lock.lock();

      final result = await lock.unlock();

      expect(result.isFailure, isTrue);
      expect(lock.isLocked, isTrue);
      await lock.dispose();
    });

    test('createAppLockManager rejects invalid configuration', () {
      final kit = SecureBankKit.initialize();
      expect(
        () => kit.createAppLockManager(reason: ' '),
        throwsArgumentError,
      );
      expect(
        () => kit.createAppLockManager(
          gracePeriod: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
    });
  });

  group('certificatePinning', () {
    const validPin = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

    test('pinner() is built from the configured pins', () {
      final kit = SecureBankKit.initialize(
        certificatePins: const {
          'api.example.com': [validPin],
        },
      );
      expect(kit.certificatePinning.pinner(), isA<CertificatePinner>());
    });

    test('pinner() rejects a malformed pin', () {
      final kit = SecureBankKit.initialize(
        certificatePins: const {
          'api.example.com': ['not-a-sha256-pin'],
        },
      );
      expect(() => kit.certificatePinning.pinner(), throwsArgumentError);
      expect(
        () => kit.certificatePinning.createHttpClient(),
        throwsArgumentError,
      );
    });

    test('pinner() rejects a host with no pins', () {
      final kit = SecureBankKit.initialize(
        certificatePins: const {'api.example.com': <String>[]},
      );
      expect(() => kit.certificatePinning.pinner(), throwsArgumentError);
    });
  });
}
