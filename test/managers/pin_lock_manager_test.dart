import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/entities/pin_lockout_state.dart';
import 'package:flutter_security_suite/domain/repositories/secure_storage_repository.dart';
import 'package:flutter_security_suite/managers/pin_lock_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [SecureStorageRepository] that survives being handed to a new
/// [PinLockManager], so we can simulate an app restart by reusing the same
/// backing map.
class InMemoryStorage implements SecureStorageRepository {
  final Map<String, String> store;
  bool failWrites = false;

  InMemoryStorage([Map<String, String>? store]) : store = store ?? {};

  @override
  Future<SecurityResult<void>> write({
    required String key,
    required String value,
  }) async {
    if (failWrites) {
      return const Failure(SecureStorageException(message: 'write failed'));
    }
    store[key] = value;
    return const Success(null);
  }

  @override
  Future<SecurityResult<String?>> read({required String key}) async {
    return Success(store[key]);
  }

  @override
  Future<SecurityResult<void>> delete({required String key}) async {
    store.remove(key);
    return const Success(null);
  }

  @override
  Future<SecurityResult<void>> deleteAll() async {
    store.clear();
    return const Success(null);
  }
}

T unwrap<T>(SecurityResult<T> result) => result.fold(
      onSuccess: (data) => data,
      onFailure: (e) => throw StateError('Expected Success but got $e'),
    );

SecurityException expectFailure<T>(SecurityResult<T> result) => result.fold(
      onSuccess: (data) => throw StateError('Expected Failure but got $data'),
      onFailure: (e) => e,
    );

void main() {
  group('PinLockManager', () {
    late InMemoryStorage storage;

    setUp(() => storage = InMemoryStorage());

    test('isPinSet is false before a PIN is set, true afterwards', () async {
      final pin = PinLockManager(storage);
      expect(unwrap(await pin.isPinSet()), isFalse);

      await pin.setPin('1357');
      expect(unwrap(await pin.isPinSet()), isTrue);
    });

    test('setPin rejects a PIN shorter than minPinLength', () async {
      final pin = PinLockManager(storage, minPinLength: 4);
      final error = expectFailure(await pin.setPin('12'));
      expect(error, isA<AppLockException>());
      expect((error as AppLockException).code, AppLockException.weakPin);
      expect(unwrap(await pin.isPinSet()), isFalse);
    });

    test('verifyPin returns notConfigured when no PIN is set', () async {
      final pin = PinLockManager(storage);
      final error = expectFailure(await pin.verifyPin('1357'));
      expect((error as AppLockException).code, AppLockException.notConfigured);
    });

    test('correct PIN verifies and resets the attempt counter', () async {
      final pin = PinLockManager(storage, maxAttempts: 5);
      await pin.setPin('1357');

      // Burn two attempts.
      await pin.verifyPin('0000');
      final afterWrong = unwrap(await pin.verifyPin('9999'));
      expect(afterWrong.verified, isFalse);
      expect(afterWrong.remainingAttempts, 3);

      final ok = unwrap(await pin.verifyPin('1357'));
      expect(ok.verified, isTrue);
      expect(ok.remainingAttempts, 5);

      // Counter cleared.
      final state = unwrap(await pin.lockoutState());
      expect(state.remainingAttempts, 5);
      expect(state.isLockedOut, isFalse);
    });

    test('plaintext PIN is never persisted', () async {
      final pin = PinLockManager(storage);
      await pin.setPin('1357');
      expect(storage.store.values, isNot(contains('1357')));
      // A salt and a hash are stored, but not the PIN itself.
      expect(storage.store.keys, contains('sbk.pin.hash'));
      expect(storage.store.keys, contains('sbk.pin.salt'));
    });

    test('locks out after maxAttempts and refuses even the correct PIN',
        () async {
      var clock = DateTime(2026, 1, 1, 12, 0, 0);
      final pin = PinLockManager(
        storage,
        maxAttempts: 5,
        lockoutDuration: const Duration(minutes: 1),
        now: () => clock,
      );
      await pin.setPin('1357');

      PinVerification? last;
      for (var i = 0; i < 5; i++) {
        last = unwrap(await pin.verifyPin('0000'));
      }
      expect(last!.isLockedOut, isTrue);
      expect(last.remainingAttempts, 0);
      expect(last.retryAfter(clock), const Duration(minutes: 1));

      // Even the correct PIN is refused while locked out.
      final duringLockout = unwrap(await pin.verifyPin('1357'));
      expect(duringLockout.verified, isFalse);
      expect(duringLockout.isLockedOut, isTrue);
    });

    test('cooldown elapses and a fresh set of attempts is granted', () async {
      var clock = DateTime(2026, 1, 1, 12, 0, 0);
      final pin = PinLockManager(
        storage,
        maxAttempts: 5,
        lockoutDuration: const Duration(minutes: 1),
        now: () => clock,
      );
      await pin.setPin('1357');

      for (var i = 0; i < 5; i++) {
        await pin.verifyPin('0000');
      }

      // Advance past the cooldown.
      clock = clock.add(const Duration(minutes: 1, seconds: 1));

      final ok = unwrap(await pin.verifyPin('1357'));
      expect(ok.verified, isTrue);
      expect(ok.isLockedOut, isFalse);
    });

    test('lockout survives an app restart (new manager, same storage)',
        () async {
      var clock = DateTime(2026, 1, 1, 12, 0, 0);
      final pin = PinLockManager(
        storage,
        maxAttempts: 5,
        lockoutDuration: const Duration(minutes: 1),
        now: () => clock,
      );
      await pin.setPin('1357');
      for (var i = 0; i < 5; i++) {
        await pin.verifyPin('0000');
      }

      // Simulate a force-quit + relaunch: brand-new manager over the SAME
      // backing storage, clock barely advanced.
      clock = clock.add(const Duration(seconds: 5));
      final restarted = PinLockManager(
        storage,
        maxAttempts: 5,
        lockoutDuration: const Duration(minutes: 1),
        now: () => clock,
      );

      final state = unwrap(await restarted.lockoutState());
      expect(state.isLockedOut, isTrue, reason: 'restart must not reset lockout');

      final attempt = unwrap(await restarted.verifyPin('1357'));
      expect(attempt.verified, isFalse);
      expect(attempt.isLockedOut, isTrue);
    });

    test('failed-attempt count persists across a restart', () async {
      final pin = PinLockManager(storage, maxAttempts: 5);
      await pin.setPin('1357');
      await pin.verifyPin('0000');
      await pin.verifyPin('0000');

      final restarted = PinLockManager(storage, maxAttempts: 5);
      final state = unwrap(await restarted.lockoutState());
      expect(state.remainingAttempts, 3,
          reason: 'two prior failures must carry over');
    });

    test('clearPin removes the PIN and all attempt state', () async {
      final pin = PinLockManager(storage);
      await pin.setPin('1357');
      await pin.verifyPin('0000');

      await pin.clearPin();
      expect(unwrap(await pin.isPinSet()), isFalse);
      expect(storage.store, isEmpty);

      final error = expectFailure(await pin.verifyPin('1357'));
      expect((error as AppLockException).code, AppLockException.notConfigured);
    });

    test('setPin surfaces a storage write failure as a Failure', () async {
      final pin = PinLockManager(storage);
      storage.failWrites = true;
      final result = await pin.setPin('1357');
      expect(result.isFailure, isTrue);
    });

    group('constructor validation', () {
      test('rejects maxAttempts < 1', () {
        expect(() => PinLockManager(storage, maxAttempts: 0),
            throwsArgumentError);
      });
      test('rejects a negative lockoutDuration', () {
        expect(
            () => PinLockManager(storage,
                lockoutDuration: const Duration(seconds: -1)),
            throwsArgumentError);
      });
      test('rejects a blank namespace', () {
        expect(() => PinLockManager(storage, namespace: '  '),
            throwsArgumentError);
      });
    });
  });
}
