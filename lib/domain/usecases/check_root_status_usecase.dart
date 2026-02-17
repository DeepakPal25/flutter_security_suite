import '../../core/result/security_result.dart';
import '../repositories/root_detection_repository.dart';

/// Checks whether the device is rooted / jailbroken.
class CheckRootStatusUseCase {
  final RootDetectionRepository _repository;

  const CheckRootStatusUseCase(this._repository);

  Future<SecurityResult<bool>> call() {
    return _repository.isDeviceRooted();
  }
}
