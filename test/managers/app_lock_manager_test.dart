import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/entities/biometric_availability.dart';
import 'package:flutter_security_suite/domain/repositories/biometric_repository.dart';
import 'package:flutter_security_suite/managers/app_lock_manager.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeBiometrics implements BiometricRepository {
  final List<({String reason, bool allowDeviceCredential})> calls = [];
  Future<SecurityResult<bool>> Function() onAuthenticate =
      () async => const Success(true);

  @override
  Future<SecurityResult<BiometricAvailability>> checkAvailability() async =>
      const Success(BiometricAvailability.unavailable);

  @override
  Future<SecurityResult<bool>> authenticate({
    required String reason,
    bool allowDeviceCredential = true,
    String? cancelLabel,
  }) {
    calls.add((reason: reason, allowDeviceCredential: allowDeviceCredential));
    return onAuthenticate();
  }
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final start = DateTime.utc(2026, 1, 1, 12);
  late DateTime clock;
  late FakeBiometrics biometrics;

  setUp(() {
    clock = start;
    biometrics = FakeBiometrics();
  });

  AppLockManager build({
    Duration gracePeriod = Duration.zero,
    bool lockOnStart = false,
    bool allowDeviceCredential = true,
    String reason = 'Unlock to continue',
  }) {
    final manager = AppLockManager(
      biometrics: biometrics,
      gracePeriod: gracePeriod,
      lockOnStart: lockOnStart,
      allowDeviceCredential: allowDeviceCredential,
      reason: reason,
      now: () => clock,
    );
    addTearDown(manager.dispose);
    return manager;
  }

  void background(AppLockManager sut, Duration awayFor) {
    sut.handleLifecycleChange(AppLifecycleState.inactive);
    sut.handleLifecycleChange(AppLifecycleState.hidden);
    sut.handleLifecycleChange(AppLifecycleState.paused);
    clock = clock.add(awayFor);
    sut.handleLifecycleChange(AppLifecycleState.hidden);
    sut.handleLifecycleChange(AppLifecycleState.inactive);
    sut.handleLifecycleChange(AppLifecycleState.resumed);
  }

  group('construction', () {
    test('rejects a negative grace period', () {
      expect(
        () => AppLockManager(
          biometrics: biometrics,
          gracePeriod: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
    });

    test('rejects a blank reason', () {
      expect(
        () => AppLockManager(biometrics: biometrics, reason: '   '),
        throwsArgumentError,
      );
      expect(
        () => AppLockManager(biometrics: biometrics, reason: ''),
        throwsArgumentError,
      );
    });

    test('is unlocked by default', () {
      final sut = build();
      expect(sut.isLocked, isFalse);
      expect(sut.isUnlocking, isFalse);
    });

    test('can start locked', () {
      expect(build(lockOnStart: true).isLocked, isTrue);
    });
  });

  group('lock / forceUnlock', () {
    test('emit only on an actual change', () async {
      final sut = build();
      final changes = <bool>[];
      sut.lockStateChanges.listen(changes.add);
      sut.lock();
      sut.lock();
      sut.forceUnlock();
      sut.forceUnlock();
      await pumpEventQueue();
      expect(changes, [true, false]);
      expect(biometrics.calls, isEmpty);
    });

    test('forceUnlock forgets a pending background timestamp', () {
      final sut = build(gracePeriod: const Duration(seconds: 30));
      sut.handleLifecycleChange(AppLifecycleState.paused);
      sut.forceUnlock();
      clock = clock.add(const Duration(hours: 1));
      sut.handleLifecycleChange(AppLifecycleState.resumed);
      expect(sut.isLocked, isFalse);
    });
  });

  group('unlock', () {
    test('succeeds without a prompt when not locked', () async {
      final sut = build();
      expect((await sut.unlock()).dataOrNull, isTrue);
      expect(biometrics.calls, isEmpty);
    });

    test('unlocks on successful authentication', () async {
      final sut = build(lockOnStart: true);
      final changes = <bool>[];
      sut.lockStateChanges.listen(changes.add);
      expect((await sut.unlock()).dataOrNull, isTrue);
      await pumpEventQueue();
      expect(sut.isLocked, isFalse);
      expect(changes, [false]);
      expect(biometrics.calls.single.reason, 'Unlock to continue');
      expect(biometrics.calls.single.allowDeviceCredential, isTrue);
    });

    test('passes the configured options to the prompt', () async {
      final sut = build(
        lockOnStart: true,
        allowDeviceCredential: false,
        reason: 'Confirm it is you',
      );
      await sut.unlock();
      expect(biometrics.calls.single.reason, 'Confirm it is you');
      expect(biometrics.calls.single.allowDeviceCredential, isFalse);
    });

    test('a per-call reason overrides the default', () async {
      final sut = build(lockOnStart: true);
      await sut.unlock(reason: 'Open vault');
      expect(biometrics.calls.single.reason, 'Open vault');
    });

    test('a blank per-call reason falls back to the default', () async {
      final sut = build(lockOnStart: true);
      biometrics.onAuthenticate = () async => const Success(false);
      await sut.unlock(reason: '  ');
      await sut.unlock(reason: '');
      expect(
        biometrics.calls.map((c) => c.reason),
        everyElement('Unlock to continue'),
      );
    });

    test('stays locked when the user cancels', () async {
      final sut = build(lockOnStart: true);
      biometrics.onAuthenticate = () async => const Success(false);
      final result = await sut.unlock();
      expect(result.dataOrNull, isFalse);
      expect(sut.isLocked, isTrue);
      expect(sut.isUnlocking, isFalse);
    });

    test('stays locked and returns the failure on a biometric error', () async {
      final sut = build(lockOnStart: true);
      biometrics.onAuthenticate = () async => const Failure(
        BiometricException(
          message: 'Too many attempts',
          code: BiometricException.lockedOut,
        ),
      );
      final result = await sut.unlock();
      expect(result.isFailure, isTrue);
      expect(
        ((result as Failure).error).code,
        BiometricException.lockedOut,
      );
      expect(sut.isLocked, isTrue);
    });

    test('wraps a throwing repository', () async {
      final sut = build(lockOnStart: true);
      biometrics.onAuthenticate = () => Future.error(StateError('boom'));
      final result = await sut.unlock();
      expect(result.isFailure, isTrue);
      final error = (result as Failure).error;
      expect(error, isA<BiometricException>());
      expect(error.originalError, isA<StateError>());
      expect(sut.isLocked, isTrue);
      expect(sut.isUnlocking, isFalse);
    });

    test('can retry after a failed attempt', () async {
      final sut = build(lockOnStart: true);
      biometrics.onAuthenticate = () async => const Success(false);
      await sut.unlock();
      biometrics.onAuthenticate = () async => const Success(true);
      expect((await sut.unlock()).dataOrNull, isTrue);
      expect(sut.isLocked, isFalse);
      expect(biometrics.calls, hasLength(2));
    });

    test('concurrent calls share one prompt', () async {
      final sut = build(lockOnStart: true);
      final gate = Completer<SecurityResult<bool>>();
      biometrics.onAuthenticate = () => gate.future;
      final first = sut.unlock();
      final second = sut.unlock();
      expect(identical(first, second), isTrue);
      expect(sut.isUnlocking, isTrue);
      gate.complete(const Success(true));
      final results = await Future.wait([first, second]);
      expect(results.map((r) => r.dataOrNull), everyElement(isTrue));
      expect(biometrics.calls, hasLength(1));
      expect(sut.isUnlocking, isFalse);
    });

    test('manual lock during a prompt is overridden by a successful unlock',
        () async {
      final sut = build(lockOnStart: true);
      final gate = Completer<SecurityResult<bool>>();
      biometrics.onAuthenticate = () => gate.future;
      final pending = sut.unlock();
      sut.lock();
      gate.complete(const Success(true));
      await pending;
      expect(sut.isLocked, isFalse);
    });
  });

  group('lifecycle', () {
    test('locks immediately on background with no grace period', () {
      final sut = build();
      sut.handleLifecycleChange(AppLifecycleState.inactive);
      expect(sut.isLocked, isFalse);
      sut.handleLifecycleChange(AppLifecycleState.hidden);
      expect(sut.isLocked, isTrue);
    });

    test('locks on paused as well', () {
      final sut = build();
      sut.handleLifecycleChange(AppLifecycleState.paused);
      expect(sut.isLocked, isTrue);
    });

    test('inactive alone never locks (e.g. control centre)', () {
      final sut = build();
      sut.handleLifecycleChange(AppLifecycleState.inactive);
      clock = clock.add(const Duration(hours: 1));
      sut.handleLifecycleChange(AppLifecycleState.resumed);
      expect(sut.isLocked, isFalse);
    });

    test('detached is ignored', () {
      final sut = build();
      sut.handleLifecycleChange(AppLifecycleState.detached);
      expect(sut.isLocked, isFalse);
    });

    test('stays unlocked when returning inside the grace period', () {
      final sut = build(gracePeriod: const Duration(seconds: 30));
      background(sut, const Duration(seconds: 29));
      expect(sut.isLocked, isFalse);
    });

    test('does not lock while backgrounded with a grace period', () {
      final sut = build(gracePeriod: const Duration(seconds: 30));
      sut.handleLifecycleChange(AppLifecycleState.paused);
      expect(sut.isLocked, isFalse);
    });

    test('locks when returning exactly at the grace period', () {
      final sut = build(gracePeriod: const Duration(seconds: 30));
      background(sut, const Duration(seconds: 30));
      expect(sut.isLocked, isTrue);
    });

    test('locks when returning after the grace period', () {
      final sut = build(gracePeriod: const Duration(seconds: 30));
      background(sut, const Duration(minutes: 10));
      expect(sut.isLocked, isTrue);
    });

    test('measures from the first background event', () {
      final sut = build(gracePeriod: const Duration(seconds: 30));
      sut.handleLifecycleChange(AppLifecycleState.hidden);
      clock = clock.add(const Duration(seconds: 20));
      sut.handleLifecycleChange(AppLifecycleState.paused);
      clock = clock.add(const Duration(seconds: 20));
      sut.handleLifecycleChange(AppLifecycleState.resumed);
      expect(sut.isLocked, isTrue);
    });

    test('each background trip is measured separately', () {
      final sut = build(gracePeriod: const Duration(seconds: 30));
      background(sut, const Duration(seconds: 20));
      background(sut, const Duration(seconds: 20));
      expect(sut.isLocked, isFalse);
    });

    test('locks when the clock moved backwards while away', () {
      final sut = build(gracePeriod: const Duration(seconds: 30));
      background(sut, const Duration(hours: -2));
      expect(sut.isLocked, isTrue);
    });

    test('resumed without a prior background does nothing', () {
      final sut = build(gracePeriod: const Duration(seconds: 30));
      sut.handleLifecycleChange(AppLifecycleState.resumed);
      expect(sut.isLocked, isFalse);
    });

    test('lifecycle noise from the system prompt does not re-lock', () async {
      final sut = build(lockOnStart: true);
      final gate = Completer<SecurityResult<bool>>();
      biometrics.onAuthenticate = () => gate.future;
      final pending = sut.unlock();
      // The OS prompt takes the app through these states.
      sut.handleLifecycleChange(AppLifecycleState.inactive);
      sut.handleLifecycleChange(AppLifecycleState.paused);
      clock = clock.add(const Duration(minutes: 1));
      sut.handleLifecycleChange(AppLifecycleState.resumed);
      gate.complete(const Success(true));
      await pending;
      expect(sut.isLocked, isFalse);
      // A trailing `resumed` after the prompt closed must not lock either.
      sut.handleLifecycleChange(AppLifecycleState.resumed);
      expect(sut.isLocked, isFalse);
    });

    test('a successful unlock clears an earlier background timestamp',
        () async {
      final sut = build(gracePeriod: const Duration(seconds: 30));
      sut.handleLifecycleChange(AppLifecycleState.paused);
      sut.lock();
      await sut.unlock();
      clock = clock.add(const Duration(hours: 1));
      sut.handleLifecycleChange(AppLifecycleState.resumed);
      expect(sut.isLocked, isFalse);
    });

    test('locks again on the next background after unlocking', () async {
      final sut = build();
      background(sut, const Duration(seconds: 1));
      await sut.unlock();
      expect(sut.isLocked, isFalse);
      background(sut, const Duration(seconds: 1));
      expect(sut.isLocked, isTrue);
    });
  });

  group('start / dispose', () {
    test('observes the real app lifecycle after start', () {
      final sut = build()..start();
      sut.start(); // idempotent
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(sut.isLocked, isTrue);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    test('does not observe before start', () {
      final sut = build();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(sut.isLocked, isFalse);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    test('stops observing and closes the stream on dispose', () async {
      final sut = build()..start();
      var done = false;
      sut.lockStateChanges.listen((_) {}, onDone: () => done = true);
      await sut.dispose();
      await sut.dispose(); // idempotent
      expect(done, isTrue);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(sut.isLocked, isFalse);
      sut.handleLifecycleChange(AppLifecycleState.paused);
      expect(sut.isLocked, isFalse);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });

    test('start throws after dispose', () async {
      final sut = build();
      await sut.dispose();
      expect(sut.start, throwsStateError);
    });

    test('lock and unlock after dispose do not throw', () async {
      final sut = build();
      await sut.dispose();
      sut.lock();
      expect(sut.isLocked, isTrue);
      expect((await sut.unlock()).dataOrNull, isTrue);
      expect(sut.isLocked, isFalse);
    });
  });
}
