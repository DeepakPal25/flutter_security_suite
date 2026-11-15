import '../../core/result/security_result.dart';
import '../entities/biometric_availability.dart';
import '../repositories/biometric_repository.dart';

/// Biometric / device-credential authentication.
class BiometricAuthUseCase {
  final BiometricRepository _repository;

  const BiometricAuthUseCase(this._repository);

  Future<SecurityResult<BiometricAvailability>> checkAvailability() =>
      _repository.checkAvailability();

  Future<SecurityResult<bool>> authenticate({
    required String reason,
    bool allowDeviceCredential = true,
    String? cancelLabel,
  }) => _repository.authenticate(
    reason: reason,
    allowDeviceCredential: allowDeviceCredential,
    cancelLabel: cancelLabel,
  );
}
