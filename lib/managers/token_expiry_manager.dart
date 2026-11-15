import '../core/exceptions/security_exception.dart';
import '../core/result/security_result.dart';
import '../core/utils/logger.dart';
import '../domain/repositories/secure_storage_repository.dart';
import 'secure_token_storage.dart';

/// What a [TokenRefresher] returns after talking to the auth server.
class RefreshedTokens {
  final String accessToken;

  /// New refresh token. `null` keeps the stored one (no rotation).
  final String? refreshToken;

  /// Absolute expiry of [accessToken].
  final DateTime expiresAt;

  const RefreshedTokens({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
  });
}

/// Exchanges the stored refresh token for new tokens.
typedef TokenRefresher = Future<RefreshedTokens> Function(String? refreshToken);

/// Tracks the access-token expiry and refreshes the token when needed,
/// making sure only one refresh runs at a time.
///
/// A missing, unreadable or corrupt expiry is always treated as *expired*.
class TokenExpiryManager {
  final SecureStorageRepository _storage;
  final SecureTokenStorage _tokens;
  final DateTime Function() _now;

  /// How long before the expiry a token already counts as "should refresh".
  final Duration defaultRefreshBuffer;

  Future<SecurityResult<String>>? _inFlight;

  /// Throws [ArgumentError] when [defaultRefreshBuffer] is negative.
  TokenExpiryManager({
    required SecureStorageRepository storage,
    required SecureTokenStorage tokenStorage,
    DateTime Function()? now,
    this.defaultRefreshBuffer = const Duration(seconds: 60),
  }) : _storage = storage,
       _tokens = tokenStorage,
       _now = now ?? DateTime.now {
    if (defaultRefreshBuffer.isNegative) {
      throw ArgumentError.value(
        defaultRefreshBuffer,
        'defaultRefreshBuffer',
        'Must not be negative',
      );
    }
  }

  /// Storage key of the expiry timestamp.
  String get expiryKey => '${_tokens.namespace}.token_expiry';

  /// Whether a refresh is running right now.
  bool get isRefreshing => _inFlight != null;

  /// Persists the absolute expiry of the access token.
  Future<SecurityResult<void>> setExpiry(DateTime expiresAt) async {
    try {
      return await _storage.write(
        key: expiryKey,
        value: expiresAt.toUtc().millisecondsSinceEpoch.toString(),
      );
    } catch (e, st) {
      SecurityLogger.error('Saving expiry failed', error: e, stackTrace: st);
      return Failure(
        TokenException(message: 'Saving the expiry failed', originalError: e),
      );
    }
  }

  /// Persists an expiry relative to now (e.g. an OAuth `expires_in`).
  ///
  /// A zero or negative lifetime is stored as "already expired".
  Future<SecurityResult<void>> setExpiresIn(Duration lifetime) =>
      setExpiry(_now().add(lifetime));

  /// The stored expiry (UTC), or `null` when missing or corrupt.
  Future<SecurityResult<DateTime?>> getExpiry() async {
    try {
      final result = await _storage.read(key: expiryKey);
      return result.fold(
        onSuccess: (raw) {
          final millis = raw == null ? null : int.tryParse(raw.trim());
          if (millis == null) return const Success(null);
          try {
            return Success(
              DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true),
            );
          } catch (_) {
            return const Success(null); // out of DateTime range
          }
        },
        onFailure: (error) => Failure(error),
      );
    } catch (e, st) {
      SecurityLogger.error('Reading expiry failed', error: e, stackTrace: st);
      return Failure(
        TokenException(message: 'Reading the expiry failed', originalError: e),
      );
    }
  }

  Future<SecurityResult<void>> clearExpiry() async {
    try {
      return await _storage.delete(key: expiryKey);
    } catch (e, st) {
      SecurityLogger.error('Clearing expiry failed', error: e, stackTrace: st);
      return Failure(
        TokenException(message: 'Clearing the expiry failed', originalError: e),
      );
    }
  }

  /// `true` when the token has expired **or** no valid expiry is known.
  Future<bool> isTokenExpired() => _isPast(Duration.zero);

  /// `true` when the token expires within [buffer] (default
  /// [defaultRefreshBuffer]), has expired, or no valid expiry is known.
  Future<bool> shouldRefreshToken({Duration? buffer}) =>
      _isPast(_clamp(buffer ?? defaultRefreshBuffer));

  static Duration _clamp(Duration d) => d.isNegative ? Duration.zero : d;

  Future<bool> _isPast(Duration buffer) async {
    final expiry = (await getExpiry()).dataOrNull;
    if (expiry == null) return true;
    return !_now().toUtc().add(buffer).isBefore(expiry);
  }

  /// Returns a usable access token, refreshing it first when necessary.
  ///
  /// * Concurrent calls share a single refresh: [refresher] runs once and
  ///   every caller gets the same result.
  /// * A throwing [refresher] yields `Failure(TokenException)` with code
  ///   [TokenException.refreshFailed]; the stored tokens are left untouched
  ///   and a later call may try again.
  /// * With [requireRefreshToken] (default) a missing refresh token fails
  ///   with [TokenException.noRefreshToken] without calling [refresher].
  /// * [force] refreshes even when the current token is still valid.
  Future<SecurityResult<String>> refreshIfNeeded(
    TokenRefresher refresher, {
    Duration? buffer,
    bool force = false,
    bool requireRefreshToken = true,
  }) {
    final running = _inFlight;
    if (running != null) return running;

    final future = _refresh(
      refresher,
      buffer: buffer,
      force: force,
      requireRefreshToken: requireRefreshToken,
    );
    _inFlight = future;
    future.whenComplete(() {
      if (identical(_inFlight, future)) _inFlight = null;
    });
    return future;
  }

  Future<SecurityResult<String>> _refresh(
    TokenRefresher refresher, {
    required Duration? buffer,
    required bool force,
    required bool requireRefreshToken,
  }) async {
    try {
      if (!force && !await shouldRefreshToken(buffer: buffer)) {
        final current = (await _tokens.getAccessToken()).dataOrNull;
        if (current != null) return Success(current);
        // Expiry says "valid" but the token is gone: refresh.
      }

      final stored = await _tokens.getRefreshToken();
      if (stored is Failure<String?>) return Failure(stored.error);
      final refreshToken = stored.dataOrNull;
      if (refreshToken == null && requireRefreshToken) {
        return const Failure(
          TokenException(
            message: 'No refresh token stored',
            code: TokenException.noRefreshToken,
          ),
        );
      }

      final RefreshedTokens fresh;
      try {
        fresh = await refresher(refreshToken);
      } catch (e, st) {
        SecurityLogger.error('Token refresh failed', error: e, stackTrace: st);
        return Failure(
          TokenException(
            message: 'Token refresh failed',
            code: TokenException.refreshFailed,
            originalError: e,
          ),
        );
      }

      if (fresh.accessToken.trim().isEmpty) {
        return const Failure(
          TokenException(
            message: 'Refresh returned an empty access token',
            code: TokenException.refreshFailed,
          ),
        );
      }
      final rotated = fresh.refreshToken;
      final saved = await _tokens.saveTokens(
        accessToken: fresh.accessToken,
        refreshToken: rotated == null || rotated.trim().isEmpty
            ? null
            : rotated,
      );
      if (saved is Failure<void>) return Failure(saved.error);

      final expiry = await setExpiry(fresh.expiresAt);
      if (expiry is Failure<void>) return Failure(expiry.error);

      SecurityLogger.info('Access token refreshed');
      return Success(fresh.accessToken);
    } catch (e, st) {
      SecurityLogger.error('Token refresh failed', error: e, stackTrace: st);
      return Failure(
        TokenException(
          message: 'Token refresh failed',
          code: TokenException.refreshFailed,
          originalError: e,
        ),
      );
    }
  }
}
