/// Snapshot of the PIN attempt / lockout state.
///
/// Returned by [PinLockManager.lockoutState]. All fields survive an app
/// restart because they are persisted in secure storage.
class PinLockoutState {
  /// Whether verification is currently refused because of too many failures.
  final bool isLockedOut;

  /// How many more attempts remain before the next lockout.
  ///
  /// `0` while [isLockedOut] is `true`.
  final int remainingAttempts;

  /// When the current lockout ends, or `null` when not locked out.
  final DateTime? lockedUntil;

  const PinLockoutState({
    required this.isLockedOut,
    required this.remainingAttempts,
    this.lockedUntil,
  });

  /// Time left before another attempt is allowed.
  ///
  /// [Duration.zero] when not locked out or when the lockout has already
  /// elapsed. Pass [now] (e.g. an injected clock) to compute deterministically.
  Duration retryAfter([DateTime? now]) {
    final until = lockedUntil;
    if (!isLockedOut || until == null) return Duration.zero;
    final diff = until.difference(now ?? DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  String toString() =>
      'PinLockoutState(isLockedOut: $isLockedOut, '
      'remainingAttempts: $remainingAttempts, lockedUntil: $lockedUntil)';
}

/// Outcome of a single [PinLockManager.verifyPin] call.
class PinVerification {
  /// Whether the supplied PIN matched the stored one.
  final bool verified;

  /// Whether the account is now (or still) locked out.
  ///
  /// When `true`, [verified] is always `false` and the PIN may not even have
  /// been checked (the cooldown was still active).
  final bool isLockedOut;

  /// Attempts remaining before the next lockout. `0` while [isLockedOut].
  final int remainingAttempts;

  /// When an active lockout ends, or `null` when not locked out.
  final DateTime? lockedUntil;

  const PinVerification({
    required this.verified,
    required this.isLockedOut,
    required this.remainingAttempts,
    this.lockedUntil,
  });

  /// Time left before another attempt is allowed. See [PinLockoutState.retryAfter].
  Duration retryAfter([DateTime? now]) {
    final until = lockedUntil;
    if (!isLockedOut || until == null) return Duration.zero;
    final diff = until.difference(now ?? DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  @override
  String toString() =>
      'PinVerification(verified: $verified, isLockedOut: $isLockedOut, '
      'remainingAttempts: $remainingAttempts, lockedUntil: $lockedUntil)';
}
