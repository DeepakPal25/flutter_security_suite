import '../../core/result/security_result.dart';
import '../entities/biometric_availability.dart';

/// Contract for biometric / device-credential authentication.
abstract class BiometricRepository {
  Future<SecurityResult<BiometricAvailability>> checkAvailability();

  /// Shows the system authentication prompt.
  ///
  /// * `Success(true)`  – the user authenticated.
  /// * `Success(false)` – the user cancelled / dismissed the prompt.
  /// * `Failure(BiometricException)` – authentication could not be performed
  ///   (not available, not enrolled, locked out, …).
  Future<SecurityResult<bool>> authenticate({
    required String reason,
    bool allowDeviceCredential = true,
    String? cancelLabel,
  });
}
