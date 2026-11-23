import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/exceptions/security_exception.dart';
import '../core/result/security_result.dart';
import '../core/utils/logger.dart';
import '../domain/entities/pin_lockout_state.dart';
import '../domain/repositories/secure_storage_repository.dart';

/// Manages an app PIN with a persistent brute-force lockout.
///
/// The PIN is never stored in plain text: a fresh random salt is generated per
/// PIN and only the salted SHA-256 hash is written to secure storage. After
/// [maxAttempts] consecutive wrong attempts, verification is refused for
/// [lockoutDuration]. The failed-attempt counter and the lockout deadline are
/// both persisted, so **force-quitting and relaunching the app does not reset
/// them** — a restart cannot be used to bypass the cooldown.
///
/// This is a pure-Dart manager; it does no platform I/O of its own beyond the
/// injected [SecureStorageRepository]. Construct one with
/// `SecureBankKit.createPinLockManager(...)`.
///
/// ```dart
/// final pin = kit.createPinLockManager();
/// await pin.setPin('1357');
///
/// final result = await pin.verifyPin(entered);
/// result.fold(
///   onSuccess: (v) {
///     if (v.verified) {
///       // unlocked — e.g. appLock.forceUnlock()
///     } else if (v.isLockedOut) {
///       // show "try again in ${v.retryAfter().inSeconds}s"
///     } else {
///       // show "${v.remainingAttempts} attempts left"
///     }
///   },
///   onFailure: (e) => showError(e),
/// );
/// ```
class PinLockManager {
  final SecureStorageRepository _storage;
  final Random _random;
  final DateTime Function() _now;

  /// Namespace prefixed to every storage key, so several PINs (e.g. app lock
  /// vs. a transaction PIN) can coexist without colliding.
  final String namespace;

  /// Consecutive wrong attempts allowed before a lockout begins.
  final int maxAttempts;

  /// How long verification stays locked once [maxAttempts] is reached.
  final Duration lockoutDuration;

  /// Minimum number of characters a PIN must have.
  final int minPinLength;

  PinLockManager(
    this._storage, {
    String namespace = 'sbk',
    this.maxAttempts = 5,
    this.lockoutDuration = const Duration(minutes: 1),
    this.minPinLength = 4,
    Random? random,
    DateTime Function()? now,
  })  : namespace = _checkNamespace(namespace),
        _random = random ?? Random.secure(),
        _now = now ?? DateTime.now {
    if (maxAttempts < 1) {
      throw ArgumentError.value(
          maxAttempts, 'maxAttempts', 'Must be at least 1');
    }
    if (lockoutDuration.isNegative) {
      throw ArgumentError.value(
          lockoutDuration, 'lockoutDuration', 'Must not be negative');
    }
    if (minPinLength < 1) {
      throw ArgumentError.value(
          minPinLength, 'minPinLength', 'Must be at least 1');
    }
  }

  static String _checkNamespace(String namespace) {
    if (namespace.trim().isEmpty) {
      throw ArgumentError.value(namespace, 'namespace', 'Must not be blank');
    }
    return namespace;
  }

  String get _hashKey => '$namespace.pin.hash';
  String get _saltKey => '$namespace.pin.salt';
  String get _failedKey => '$namespace.pin.failed';
  String get _lockedUntilKey => '$namespace.pin.locked_until';

  /// Whether a PIN has been set.
  Future<SecurityResult<bool>> isPinSet() async {
    try {
      final hash = await _readRaw(_hashKey);
      return Success(hash != null && hash.isNotEmpty);
    } catch (e, st) {
      return _fail('Could not read PIN state', e, st);
    }
  }

  /// Set or replace the PIN.
  ///
  /// Generates a new salt, stores the salted hash, and clears any existing
  /// failed-attempt count and lockout. Fails with [AppLockException.weakPin]
  /// when [pin] is shorter than [minPinLength].
  Future<SecurityResult<void>> setPin(String pin) async {
    final normalized = pin.trim();
    if (normalized.length < minPinLength) {
      return Failure(AppLockException(
        message: 'The PIN must be at least $minPinLength characters long',
        code: AppLockException.weakPin,
      ));
    }
    try {
      final salt = _newSalt();
      final hash = _hash(normalized, salt);

      final w1 = await _storage.write(key: _saltKey, value: base64.encode(salt));
      if (w1 is Failure<void>) return w1;
      final w2 = await _storage.write(key: _hashKey, value: hash);
      if (w2 is Failure<void>) return w2;

      await _storage.delete(key: _failedKey);
      await _storage.delete(key: _lockedUntilKey);
      return const Success(null);
    } catch (e, st) {
      return _fail('Saving the PIN failed', e, st);
    }
  }

  /// Verify [pin] against the stored one, applying the lockout policy.
  ///
  /// - If a lockout is active, the PIN is **not** checked and the result has
  ///   `isLockedOut == true` with `verified == false`.
  /// - On a correct PIN, the failed counter and any lockout are cleared.
  /// - On a wrong PIN, the failed counter increments; reaching [maxAttempts]
  ///   starts a [lockoutDuration] cooldown and resets the counter.
  ///
  /// Fails with [AppLockException.notConfigured] when no PIN has been set.
  Future<SecurityResult<PinVerification>> verifyPin(String pin) async {
    try {
      final storedHash = await _readRaw(_hashKey);
      final storedSalt = await _readRaw(_saltKey);
      if (storedHash == null ||
          storedSalt == null ||
          storedHash.isEmpty ||
          storedSalt.isEmpty) {
        return const Failure(AppLockException(
          message: 'No PIN has been set',
          code: AppLockException.notConfigured,
        ));
      }

      final now = _now();
      final lockedUntil = await _readLockedUntil();
      if (lockedUntil != null && now.isBefore(lockedUntil)) {
        // Still cooling down — refuse without checking the PIN.
        return Success(PinVerification(
          verified: false,
          isLockedOut: true,
          remainingAttempts: 0,
          lockedUntil: lockedUntil,
        ));
      }
      // Cooldown has elapsed; clear the stale deadline.
      if (lockedUntil != null) {
        await _storage.delete(key: _lockedUntilKey);
      }

      final salt = base64.decode(storedSalt);
      final candidate = _hash(pin.trim(), salt);
      if (_constantTimeEquals(candidate, storedHash)) {
        await _storage.delete(key: _failedKey);
        await _storage.delete(key: _lockedUntilKey);
        return Success(PinVerification(
          verified: true,
          isLockedOut: false,
          remainingAttempts: maxAttempts,
        ));
      }

      // Wrong PIN — record the failure.
      final failed = (await _readInt(_failedKey) ?? 0) + 1;
      if (failed >= maxAttempts) {
        final until = now.add(lockoutDuration);
        await _storage.write(
            key: _lockedUntilKey,
            value: until.millisecondsSinceEpoch.toString());
        // Reset the counter so a fresh set of attempts is available after the
        // cooldown rather than an immediate re-lock on the next wrong try.
        await _storage.write(key: _failedKey, value: '0');
        return Success(PinVerification(
          verified: false,
          isLockedOut: true,
          remainingAttempts: 0,
          lockedUntil: until,
        ));
      }

      await _storage.write(key: _failedKey, value: failed.toString());
      return Success(PinVerification(
        verified: false,
        isLockedOut: false,
        remainingAttempts: maxAttempts - failed,
      ));
    } catch (e, st) {
      return _fail('PIN verification failed', e, st);
    }
  }

  /// Read the current attempt / lockout state without consuming an attempt.
  Future<SecurityResult<PinLockoutState>> lockoutState() async {
    try {
      final now = _now();
      final lockedUntil = await _readLockedUntil();
      if (lockedUntil != null && now.isBefore(lockedUntil)) {
        return Success(PinLockoutState(
          isLockedOut: true,
          remainingAttempts: 0,
          lockedUntil: lockedUntil,
        ));
      }
      final failed = await _readInt(_failedKey) ?? 0;
      final remaining = (maxAttempts - failed).clamp(0, maxAttempts);
      return Success(PinLockoutState(
        isLockedOut: false,
        remainingAttempts: remaining,
      ));
    } catch (e, st) {
      return _fail('Could not read lockout state', e, st);
    }
  }

  /// Remove the PIN and clear all attempt / lockout state.
  Future<SecurityResult<void>> clearPin() async {
    try {
      await _storage.delete(key: _hashKey);
      await _storage.delete(key: _saltKey);
      await _storage.delete(key: _failedKey);
      await _storage.delete(key: _lockedUntilKey);
      return const Success(null);
    } catch (e, st) {
      return _fail('Clearing the PIN failed', e, st);
    }
  }

  Uint8List _newSalt() {
    final salt = Uint8List(16);
    for (var i = 0; i < salt.length; i++) {
      salt[i] = _random.nextInt(256);
    }
    return salt;
  }

  String _hash(String pin, List<int> salt) {
    final pinBytes = utf8.encode(pin);
    final input = Uint8List(salt.length + pinBytes.length)
      ..setRange(0, salt.length, salt)
      ..setRange(salt.length, salt.length + pinBytes.length, pinBytes);
    return sha256.convert(input).toString();
  }

  /// Length-constant comparison to avoid leaking match progress via timing.
  bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }

  Future<String?> _readRaw(String key) async {
    final r = await _storage.read(key: key);
    return r.fold(
      onSuccess: (v) => v,
      onFailure: (e) => throw e,
    );
  }

  Future<int?> _readInt(String key) async {
    final v = await _readRaw(key);
    if (v == null || v.isEmpty) return null;
    return int.tryParse(v);
  }

  Future<DateTime?> _readLockedUntil() async {
    final millis = await _readInt(_lockedUntilKey);
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Failure<T> _fail<T>(String message, Object e, StackTrace st) {
    SecurityLogger.error(message, error: e, stackTrace: st);
    return Failure<T>(AppLockException(message: message, originalError: e));
  }
}
