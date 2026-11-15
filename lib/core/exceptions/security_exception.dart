/// Base exception for all SecureBankKit security errors.
class SecurityException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;

  const SecurityException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'SecurityException($code): $message';
}

/// Thrown when certificate pinning validation fails.
class CertificatePinningException extends SecurityException {
  final String host;

  const CertificatePinningException({
    required this.host,
    required super.message,
    super.code = 'CERTIFICATE_PINNING_FAILURE',
    super.originalError,
  });

  @override
  String toString() => 'CertificatePinningException($host): $message';
}

/// Thrown when a platform-specific operation fails.
class PlatformSecurityException extends SecurityException {
  final String platform;

  const PlatformSecurityException({
    required this.platform,
    required super.message,
    super.code = 'PLATFORM_ERROR',
    super.originalError,
  });

  @override
  String toString() => 'PlatformSecurityException($platform): $message';
}

/// Thrown when secure storage operations fail.
class SecureStorageException extends SecurityException {
  final String? key;

  const SecureStorageException({
    this.key,
    required super.message,
    super.code = 'SECURE_STORAGE_ERROR',
    super.originalError,
  });

  @override
  String toString() => 'SecureStorageException(key=$key): $message';
}

/// Thrown when biometric authentication cannot be performed or fails.
///
/// [code] is one of the `BiometricException.*` constants.
class BiometricException extends SecurityException {
  static const String notAvailable = 'BIOMETRIC_NOT_AVAILABLE';
  static const String notEnrolled = 'BIOMETRIC_NOT_ENROLLED';
  static const String lockedOut = 'BIOMETRIC_LOCKED_OUT';
  static const String passcodeNotSet = 'BIOMETRIC_PASSCODE_NOT_SET';
  static const String noActivity = 'BIOMETRIC_NO_ACTIVITY';
  static const String inProgress = 'BIOMETRIC_IN_PROGRESS';
  static const String invalidArguments = 'BIOMETRIC_INVALID_ARGS';
  static const String failed = 'BIOMETRIC_ERROR';

  const BiometricException({
    required super.message,
    super.code = failed,
    super.originalError,
  });

  @override
  String toString() => 'BiometricException($code): $message';
}

/// Thrown when token storage / refresh operations fail.
class TokenException extends SecurityException {
  static const String invalidToken = 'TOKEN_INVALID';
  static const String refreshFailed = 'TOKEN_REFRESH_FAILED';
  static const String noRefreshToken = 'TOKEN_NO_REFRESH_TOKEN';

  const TokenException({
    required super.message,
    super.code = 'TOKEN_ERROR',
    super.originalError,
  });

  @override
  String toString() => 'TokenException($code): $message';
}

/// Thrown when an argument supplied to a security API is invalid.
class InvalidArgumentSecurityException extends SecurityException {
  const InvalidArgumentSecurityException({
    required super.message,
    super.code = 'INVALID_ARGUMENT',
    super.originalError,
  });

  @override
  String toString() => 'InvalidArgumentSecurityException: $message';
}
