import '../../core/result/security_result.dart';

/// Contract for application tamper detection.
abstract class TamperDetectionRepository {
  /// Returns `true` when tampering indicators are found in the app bundle
  /// or APK signing certificate.
  Future<SecurityResult<bool>> isTampered();

  /// Returns the SHA-256 hex fingerprint of the app's signing certificate,
  /// or `null` if it cannot be retrieved. Useful for comparing against a
  /// known-good value during setup.
  Future<SecurityResult<String?>> getSignatureHash();
}
