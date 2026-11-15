import 'dart:async';

import '../core/result/security_result.dart';
import '../core/utils/logger.dart';
import 'secure_token_storage.dart';
import 'token_expiry_manager.dart';

/// Ends a user session after a period of inactivity.
///
/// ```dart
/// final session = kit.createSessionManager(
///   timeout: const Duration(minutes: 5),
/// );
/// session.onSessionExpired.listen((_) => goToLogin());
/// session.startSession();
/// // on every user interaction:
/// session.recordActivity();
/// ```
///
/// Expiry is decided from the wall clock, not only from the timer, so a
/// session that timed out while the app was suspended expires as soon as the
/// app runs again (on the next timer tick or [recordActivity] call).
class SessionManager {
  /// Inactivity period after which the session expires.
  final Duration timeout;

  /// Whether stored tokens are removed when the session times out.
  final bool clearTokensOnExpiry;

  final SecureTokenStorage? _tokens;
  final TokenExpiryManager? _expiry;
  final DateTime Function() _now;

  final StreamController<void> _expired = StreamController<void>.broadcast();
  Timer? _timer;
  DateTime? _lastActivity;
  bool _active = false;
  bool _disposed = false;

  /// Throws [ArgumentError] when [timeout] is zero or negative.
  SessionManager({
    required this.timeout,
    SecureTokenStorage? tokenStorage,
    TokenExpiryManager? tokenExpiry,
    DateTime Function()? now,
    this.clearTokensOnExpiry = true,
  }) : _tokens = tokenStorage,
       _expiry = tokenExpiry,
       _now = now ?? DateTime.now {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, 'timeout', 'Must be positive');
    }
  }

  /// Fires once each time the session ends because of inactivity (after the
  /// tokens were cleared). Not fired by [endSession].
  Stream<void> get onSessionExpired => _expired.stream;

  /// Whether a session is running and has not timed out.
  bool get isActive {
    if (!_active) return false;
    return _elapsed() < timeout;
  }

  /// Time left until the session expires; zero when there is no session.
  Duration get remainingTime {
    if (!_active) return Duration.zero;
    final left = timeout - _elapsed();
    return left.isNegative ? Duration.zero : left;
  }

  /// Starts (or restarts) the session and its inactivity countdown.
  ///
  /// Throws [StateError] after [dispose].
  void startSession() {
    if (_disposed) throw StateError('SessionManager has been disposed');
    _active = true;
    _lastActivity = _now();
    _schedule(timeout);
    SecurityLogger.info('Session started');
  }

  /// Call on user interaction to push the expiry back.
  ///
  /// Returns `false` (and does nothing) when no session is running. If the
  /// timeout has already passed, the session expires instead of being
  /// extended and `false` is returned.
  bool recordActivity() {
    if (!_active || _disposed) return false;
    if (_elapsed() >= timeout) {
      _expire();
      return false;
    }
    _lastActivity = _now();
    return true;
  }

  /// Ends the session explicitly (logout). Does not emit
  /// [onSessionExpired]. With [clearTokens] the stored tokens and expiry are
  /// removed; the first failure of that cleanup is returned.
  Future<SecurityResult<void>> endSession({bool clearTokens = true}) async {
    final wasActive = _active;
    _stop();
    if (wasActive) SecurityLogger.info('Session ended');
    if (!clearTokens) return const Success(null);
    return _clearTokens();
  }

  /// Stops the timer and closes [onSessionExpired]. Tokens are kept.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _stop();
    await _expired.close();
  }

  /// Time since the last activity. A clock that jumped backwards restarts
  /// the countdown instead of extending the session indefinitely.
  Duration _elapsed() {
    final last = _lastActivity;
    if (last == null) return timeout;
    final now = _now();
    if (now.isBefore(last)) {
      _lastActivity = now;
      return Duration.zero;
    }
    return now.difference(last);
  }

  void _schedule(Duration delay) {
    _timer?.cancel();
    _timer = Timer(delay, _onTimer);
  }

  void _onTimer() {
    if (!_active) return;
    final left = timeout - _elapsed();
    if (left <= Duration.zero) {
      _expire();
    } else {
      _schedule(left); // activity was recorded since the timer was armed
    }
  }

  void _stop() {
    _active = false;
    _lastActivity = null;
    _timer?.cancel();
    _timer = null;
  }

  void _expire() {
    _stop();
    SecurityLogger.info('Session expired after inactivity');
    unawaited(_finishExpiry());
  }

  Future<void> _finishExpiry() async {
    if (clearTokensOnExpiry) {
      final result = await _clearTokens();
      if (result.isFailure) {
        SecurityLogger.warning('Clearing tokens on session expiry failed');
      }
    }
    if (!_expired.isClosed) _expired.add(null);
  }

  Future<SecurityResult<void>> _clearTokens() async {
    SecurityResult<void> outcome = const Success(null);
    try {
      final tokens = _tokens;
      if (tokens != null) {
        final r = await tokens.clearTokens();
        if (r.isFailure) outcome = r;
      }
      final expiry = _expiry;
      if (expiry != null) {
        final r = await expiry.clearExpiry();
        if (r.isFailure && outcome.isSuccess) outcome = r;
      }
    } catch (e, st) {
      SecurityLogger.error('Clearing tokens failed', error: e, stackTrace: st);
    }
    return outcome;
  }
}
