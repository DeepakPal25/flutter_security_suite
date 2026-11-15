import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/exceptions/security_exception.dart';
import '../core/result/security_result.dart';
import '../core/utils/logger.dart';
import '../domain/repositories/biometric_repository.dart';

/// Locks the app when it has been in the background for longer than a grace
/// period and unlocks it again with biometrics / device credentials.
///
/// ```dart
/// final appLock = kit.createAppLockManager(
///   gracePeriod: const Duration(seconds: 30),
/// )..start();
/// appLock.lockStateChanges.listen((locked) { /* show / hide lock screen */ });
/// // from the lock screen:
/// await appLock.unlock();
/// ```
class AppLockManager with WidgetsBindingObserver {
  final BiometricRepository _biometrics;
  final DateTime Function() _now;

  /// How long the app may stay in the background without locking.
  final Duration gracePeriod;

  /// Default prompt text for [unlock].
  final String reason;

  /// Whether PIN / pattern / passcode is accepted as a fallback.
  final bool allowDeviceCredential;

  final StreamController<bool> _changes = StreamController<bool>.broadcast();
  bool _locked;
  bool _started = false;
  bool _disposed = false;
  DateTime? _backgroundedAt;
  Future<SecurityResult<bool>>? _unlocking;

  /// Throws [ArgumentError] when [gracePeriod] is negative or [reason] is
  /// blank.
  AppLockManager({
    required BiometricRepository biometrics,
    this.gracePeriod = Duration.zero,
    bool lockOnStart = false,
    this.reason = 'Unlock to continue',
    this.allowDeviceCredential = true,
    DateTime Function()? now,
  }) : _biometrics = biometrics,
       _now = now ?? DateTime.now,
       _locked = lockOnStart {
    if (gracePeriod.isNegative) {
      throw ArgumentError.value(gracePeriod, 'gracePeriod', 'Must be >= 0');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError.value(reason, 'reason', 'Must not be blank');
    }
  }

  /// Whether the app is currently locked.
  bool get isLocked => _locked;

  /// Whether an unlock prompt is currently showing.
  bool get isUnlocking => _unlocking != null;

  /// Emits the new lock state whenever it changes.
  Stream<bool> get lockStateChanges => _changes.stream;

  /// Starts observing the app lifecycle. Safe to call more than once.
  ///
  /// Throws [StateError] after [dispose].
  void start() {
    if (_disposed) throw StateError('AppLockManager has been disposed');
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stops observing and closes [lockStateChanges].
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
      _started = false;
    }
    await _changes.close();
  }

  /// Locks immediately.
  void lock() => _setLocked(true);

  /// Unlocks without a prompt, for apps that verified the user through
  /// their own fallback (e.g. an app PIN).
  void forceUnlock() {
    _backgroundedAt = null;
    _setLocked(false);
  }

  /// Shows the biometric prompt and unlocks on success.
  ///
  /// * `Success(true)`  – unlocked (also when it was not locked at all).
  /// * `Success(false)` – the user cancelled; still locked.
  /// * `Failure`        – biometrics unavailable / locked out / error; still
  ///   locked. Use [forceUnlock] after your own fallback authentication.
  ///
  /// Concurrent calls share one prompt.
  Future<SecurityResult<bool>> unlock({String? reason}) {
    if (!_locked) return Future.value(const Success(true));
    final running = _unlocking;
    if (running != null) return running;

    final future = _authenticate(reason);
    _unlocking = future;
    future.whenComplete(() {
      if (identical(_unlocking, future)) _unlocking = null;
    });
    return future;
  }

  Future<SecurityResult<bool>> _authenticate(String? reason) async {
    final text = reason == null || reason.trim().isEmpty ? this.reason : reason;
    try {
      final result = await _biometrics.authenticate(
        reason: text,
        allowDeviceCredential: allowDeviceCredential,
      );
      if (result.dataOrNull == true) {
        // The prompt itself sends the app through inactive/paused; do not
        // let that count as time spent in the background.
        _backgroundedAt = null;
        _setLocked(false);
      }
      return result;
    } catch (e, st) {
      SecurityLogger.error('App unlock failed', error: e, stackTrace: st);
      return Failure(
        BiometricException(
          message: 'Authentication failed: $e',
          originalError: e,
        ),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) =>
      handleLifecycleChange(state);

  /// Feeds a lifecycle change into the lock logic. Called automatically
  /// after [start]; public for apps that track the lifecycle themselves.
  void handleLifecycleChange(AppLifecycleState state) {
    if (_disposed) return;
    // Lifecycle noise caused by the system authentication prompt.
    if (_unlocking != null) return;

    // `hidden` only exists on Flutter 3.13+, so compare by name.
    final backgrounded =
        state == AppLifecycleState.paused || state.name == 'hidden';

    if (backgrounded) {
      _backgroundedAt ??= _now();
      // Lock right away so the content is already covered in the app
      // switcher snapshot and on return.
      if (gracePeriod == Duration.zero) _setLocked(true);
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since == null) return;
      final away = _now().difference(since);
      // A negative duration means the clock was moved back: lock.
      if (away.isNegative || away >= gracePeriod) _setLocked(true);
    }
  }

  void _setLocked(bool locked) {
    if (_locked == locked) return;
    _locked = locked;
    SecurityLogger.info(locked ? 'App locked' : 'App unlocked');
    if (!_changes.isClosed) _changes.add(locked);
  }
}
