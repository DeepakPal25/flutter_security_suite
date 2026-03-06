import '../../core/result/security_result.dart';
import '../repositories/emulator_detection_repository.dart';

/// Checks whether the app is running on an emulator or simulator.
class CheckEmulatorUseCase {
  final EmulatorDetectionRepository _repository;

  const CheckEmulatorUseCase(this._repository);

  Future<SecurityResult<bool>> call() => _repository.isEmulator();
}
