import '../../core/result/security_result.dart';
import '../repositories/tamper_detection_repository.dart';

/// Checks whether the app bundle / APK has been tampered with.
class CheckTamperUseCase {
  final TamperDetectionRepository _repository;

  const CheckTamperUseCase(this._repository);

  Future<SecurityResult<bool>> call() => _repository.isTampered();

  /// Returns the SHA-256 hex fingerprint of the app's signing certificate.
  /// Useful for one-time setup to discover and pin the expected hash.
  Future<SecurityResult<String?>> getSignatureHash() =>
      _repository.getSignatureHash();
}
