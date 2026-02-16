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
  String toString() =>
      'PlatformSecurityException($platform): $message';
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
