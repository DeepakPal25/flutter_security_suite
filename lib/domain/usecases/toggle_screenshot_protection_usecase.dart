import '../../core/result/security_result.dart';
import '../repositories/screenshot_protection_repository.dart';

/// Enables or disables screenshot protection.
class ToggleScreenshotProtectionUseCase {
  final ScreenshotProtectionRepository _repository;

  const ToggleScreenshotProtectionUseCase(this._repository);

  Future<SecurityResult<void>> call({required bool enable}) {
    return enable
        ? _repository.enableProtection()
        : _repository.disableProtection();
  }
}
