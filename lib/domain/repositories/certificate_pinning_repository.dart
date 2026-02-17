import '../../core/result/security_result.dart';

/// Contract for certificate pinning validation.
abstract class CertificatePinningRepository {
  /// Validates that the TLS certificate for [host] matches one of
  /// the provided SHA-256 [pins].
  Future<SecurityResult<bool>> validateCertificate({
    required String host,
    required List<String> pins,
  });
}
