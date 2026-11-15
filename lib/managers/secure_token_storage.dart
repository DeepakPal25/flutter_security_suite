import '../core/exceptions/security_exception.dart';
import '../core/result/security_result.dart';
import '../core/utils/logger.dart';
import '../domain/repositories/secure_storage_repository.dart';

/// Stores the access and refresh token in the platform secure storage
/// (Keychain / EncryptedSharedPreferences).
///
/// Token values are never logged.
class SecureTokenStorage {
  final SecureStorageRepository _storage;

  /// Prefix of the storage keys, so several token sets can coexist.
  final String namespace;

  /// Throws [ArgumentError] when [namespace] is blank.
  SecureTokenStorage(this._storage, {String namespace = 'sbk'})
    : namespace = _checkNamespace(namespace);

  static String _checkNamespace(String namespace) {
    final ns = namespace.trim();
    if (ns.isEmpty) {
      throw ArgumentError.value(namespace, 'namespace', 'Must not be blank');
    }
    return ns;
  }

  /// Storage key of the access token.
  String get accessTokenKey => '$namespace.access_token';

  /// Storage key of the refresh token.
  String get refreshTokenKey => '$namespace.refresh_token';

  Future<SecurityResult<void>> saveAccessToken(String token) =>
      _save(accessTokenKey, token, 'access token');

  Future<SecurityResult<void>> saveRefreshToken(String token) =>
      _save(refreshTokenKey, token, 'refresh token');

  /// The stored access token, or `null` when there is none.
  Future<SecurityResult<String?>> getAccessToken() => _read(accessTokenKey);

  /// The stored refresh token, or `null` when there is none.
  Future<SecurityResult<String?>> getRefreshToken() => _read(refreshTokenKey);

  /// Saves the access token and, when given, the refresh token.
  ///
  /// Both tokens are validated before anything is written. The two writes
  /// are not atomic: if the second one fails the access token stays saved
  /// and the failure is returned.
  Future<SecurityResult<void>> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    if (_isBlank(accessToken)) return _invalid('access token');
    if (refreshToken != null && _isBlank(refreshToken)) {
      return _invalid('refresh token');
    }
    final access = await saveAccessToken(accessToken);
    if (access.isFailure || refreshToken == null) return access;
    return saveRefreshToken(refreshToken);
  }

  Future<SecurityResult<void>> clearAccessToken() => _delete(accessTokenKey);

  Future<SecurityResult<void>> clearRefreshToken() => _delete(refreshTokenKey);

  /// Removes both tokens. Both deletes are always attempted; the first
  /// failure (if any) is returned.
  Future<SecurityResult<void>> clearTokens() async {
    final access = await clearAccessToken();
    final refresh = await clearRefreshToken();
    return access.isFailure ? access : refresh;
  }

  /// Whether an access token is stored. Read failures are returned as such.
  Future<SecurityResult<bool>> hasAccessToken() async {
    final result = await getAccessToken();
    return result.fold(
      onSuccess: (token) => Success(token != null),
      onFailure: (error) => Failure(error),
    );
  }

  static bool _isBlank(String value) => value.trim().isEmpty;

  SecurityResult<void> _invalid(String what) => Failure(
    TokenException(
      message: 'The $what must not be empty',
      code: TokenException.invalidToken,
    ),
  );

  Future<SecurityResult<void>> _save(
    String key,
    String token,
    String what,
  ) async {
    if (_isBlank(token)) return _invalid(what);
    try {
      return await _storage.write(key: key, value: token);
    } catch (e, st) {
      SecurityLogger.error('Saving $what failed', error: e, stackTrace: st);
      return Failure(
        TokenException(message: 'Saving the $what failed', originalError: e),
      );
    }
  }

  Future<SecurityResult<String?>> _read(String key) async {
    try {
      final result = await _storage.read(key: key);
      return result.fold(
        onSuccess: (value) =>
            Success(value == null || value.isEmpty ? null : value),
        onFailure: (error) => Failure(error),
      );
    } catch (e, st) {
      SecurityLogger.error('Reading token failed', error: e, stackTrace: st);
      return Failure(
        TokenException(message: 'Reading the token failed', originalError: e),
      );
    }
  }

  Future<SecurityResult<void>> _delete(String key) async {
    try {
      return await _storage.delete(key: key);
    } catch (e, st) {
      SecurityLogger.error('Clearing token failed', error: e, stackTrace: st);
      return Failure(
        TokenException(message: 'Clearing the token failed', originalError: e),
      );
    }
  }
}
