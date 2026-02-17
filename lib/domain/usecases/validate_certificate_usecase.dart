import '../../core/result/security_result.dart';
import '../repositories/certificate_pinning_repository.dart';

/// Validates the TLS certificate against pinned hashes.
class ValidateCertificateUseCase {
  final CertificatePinningRepository _repository;

  const ValidateCertificateUseCase(this._repository);

  Future<SecurityResult<bool>> call({
    required String host,
    required List<String> pins,
  }) {
    return _repository.validateCertificate(host: host, pins: pins);
  }
}
