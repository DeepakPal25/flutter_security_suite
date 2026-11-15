import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/entities/anti_tamper_status.dart';
import 'package:flutter_security_suite/domain/entities/biometric_availability.dart';
import 'package:flutter_security_suite/domain/entities/screen_capture_event.dart';
import 'package:flutter_security_suite/domain/repositories/anti_tamper_repository.dart';
import 'package:flutter_security_suite/domain/repositories/biometric_repository.dart';
import 'package:flutter_security_suite/domain/repositories/pasteboard_repository.dart';
import 'package:flutter_security_suite/domain/repositories/screen_capture_repository.dart';
import 'package:flutter_security_suite/domain/usecases/biometric_auth_usecase.dart';
import 'package:flutter_security_suite/domain/usecases/check_anti_tamper_usecase.dart';
import 'package:flutter_security_suite/domain/usecases/monitor_screen_capture_usecase.dart';
import 'package:flutter_security_suite/domain/usecases/pasteboard_usecase.dart';

class MockAntiTamperRepository extends Mock implements AntiTamperRepository {}

class MockBiometricRepository extends Mock implements BiometricRepository {}

class MockPasteboardRepository extends Mock implements PasteboardRepository {}

class MockScreenCaptureRepository extends Mock
    implements ScreenCaptureRepository {}

const _failure = Failure<Never>(SecurityException(message: 'boom'));

void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));

  group('CheckAntiTamperUseCase', () {
    late MockAntiTamperRepository repo;
    late CheckAntiTamperUseCase sut;

    setUp(() {
      repo = MockAntiTamperRepository();
      sut = CheckAntiTamperUseCase(repo);
    });

    test('call() returns the combined status', () async {
      const status = AntiTamperStatus(
        isDebuggerAttached: true,
        hasInjectedLibraries: false,
      );
      when(() => repo.check()).thenAnswer((_) async => const Success(status));
      expect((await sut()).dataOrNull, status);
      verify(() => repo.check()).called(1);
    });

    test('delegates the individual checks', () async {
      when(() => repo.isDebuggerAttached())
          .thenAnswer((_) async => const Success(true));
      when(() => repo.hasInjectedLibraries())
          .thenAnswer((_) async => const Success(false));
      when(() => repo.denyDebuggerAttachment())
          .thenAnswer((_) async => const Success(true));

      expect((await sut.isDebuggerAttached()).dataOrNull, isTrue);
      expect((await sut.hasInjectedLibraries()).dataOrNull, isFalse);
      expect((await sut.denyDebuggerAttachment()).dataOrNull, isTrue);
      verifyNever(() => repo.check());
    });

    test('propagates failures unchanged', () async {
      when(() => repo.check()).thenAnswer((_) async => _failure);
      final result = await sut();
      expect(result.isFailure, isTrue);
      expect((result as Failure).error.message, 'boom');
    });
  });

  group('BiometricAuthUseCase', () {
    late MockBiometricRepository repo;
    late BiometricAuthUseCase sut;

    setUp(() {
      repo = MockBiometricRepository();
      sut = BiometricAuthUseCase(repo);
    });

    test('checkAvailability delegates', () async {
      const availability = BiometricAvailability(
        isAvailable: true,
        type: BiometricType.face,
      );
      when(() => repo.checkAvailability())
          .thenAnswer((_) async => const Success(availability));
      expect((await sut.checkAvailability()).dataOrNull, availability);
    });

    test('authenticate defaults to allowing the device credential', () async {
      when(
        () => repo.authenticate(
          reason: 'Unlock',
          allowDeviceCredential: true,
          cancelLabel: null,
        ),
      ).thenAnswer((_) async => const Success(true));

      expect((await sut.authenticate(reason: 'Unlock')).dataOrNull, isTrue);
    });

    test('authenticate forwards every option', () async {
      when(
        () => repo.authenticate(
          reason: 'Pay',
          allowDeviceCredential: false,
          cancelLabel: 'Back',
        ),
      ).thenAnswer((_) async => const Success(false));

      final result = await sut.authenticate(
        reason: 'Pay',
        allowDeviceCredential: false,
        cancelLabel: 'Back',
      );
      expect(result.dataOrNull, isFalse);
    });

    test('propagates failures unchanged', () async {
      when(
        () => repo.authenticate(
          reason: any(named: 'reason'),
          allowDeviceCredential: any(named: 'allowDeviceCredential'),
          cancelLabel: any(named: 'cancelLabel'),
        ),
      ).thenAnswer(
        (_) async => const Failure(
          BiometricException(
            message: 'locked',
            code: BiometricException.lockedOut,
          ),
        ),
      );
      final result = await sut.authenticate(reason: 'Unlock');
      expect((result as Failure).error.code, BiometricException.lockedOut);
    });
  });

  group('PasteboardUseCase', () {
    late MockPasteboardRepository repo;
    late PasteboardUseCase sut;

    setUp(() {
      repo = MockPasteboardRepository();
      sut = PasteboardUseCase(repo);
    });

    test('copy defaults to a 60 second expiry', () async {
      when(
        () => repo.copy(
          value: 'otp',
          expiresAfter: const Duration(seconds: 60),
        ),
      ).thenAnswer((_) async => const Success(null));

      expect((await sut.copy(value: 'otp')).isSuccess, isTrue);
      expect(PasteboardUseCase.defaultExpiry, const Duration(seconds: 60));
    });

    test('copy forwards a custom expiry', () async {
      when(
        () => repo.copy(
          value: 'otp',
          expiresAfter: const Duration(seconds: 5),
        ),
      ).thenAnswer((_) async => const Success(null));

      await sut.copy(value: 'otp', expiresAfter: const Duration(seconds: 5));
      verify(
        () => repo.copy(
          value: 'otp',
          expiresAfter: const Duration(seconds: 5),
        ),
      ).called(1);
    });

    test('clear forwards onlyIfOwned', () async {
      when(() => repo.clear(onlyIfOwned: false))
          .thenAnswer((_) async => const Success(true));
      when(() => repo.clear(onlyIfOwned: true))
          .thenAnswer((_) async => const Success(false));

      expect((await sut.clear()).dataOrNull, isTrue);
      expect((await sut.clear(onlyIfOwned: true)).dataOrNull, isFalse);
    });

    test('propagates failures unchanged', () async {
      when(
        () => repo.copy(
          value: any(named: 'value'),
          expiresAfter: any(named: 'expiresAfter'),
        ),
      ).thenAnswer((_) async => _failure);
      expect((await sut.copy(value: 'x')).isFailure, isTrue);
    });
  });

  group('MonitorScreenCaptureUseCase', () {
    late MockScreenCaptureRepository repo;
    late MonitorScreenCaptureUseCase sut;

    setUp(() {
      repo = MockScreenCaptureRepository();
      sut = MonitorScreenCaptureUseCase(repo);
    });

    test('call() exposes the repository stream', () async {
      final controller = StreamController<ScreenCaptureEvent>.broadcast();
      when(() => repo.events).thenAnswer((_) => controller.stream);

      final received = <ScreenCaptureEvent>[];
      final sub = sut().listen(received.add);
      controller.add(const ScreenCaptureEvent.screenshot());
      await pumpEventQueue();

      expect(received, const [ScreenCaptureEvent.screenshot()]);
      await sub.cancel();
      await controller.close();
    });

    test('isCaptured delegates and propagates failures', () async {
      when(() => repo.isCaptured())
          .thenAnswer((_) async => const Success(true));
      expect((await sut.isCaptured()).dataOrNull, isTrue);

      when(() => repo.isCaptured()).thenAnswer((_) async => _failure);
      expect((await sut.isCaptured()).isFailure, isTrue);
    });
  });
}
