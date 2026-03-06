import '../../core/result/security_result.dart';
import '../repositories/screen_recording_repository.dart';

/// Checks whether the screen is currently being recorded or mirrored.
class CheckScreenRecordingUseCase {
  final ScreenRecordingRepository _repository;

  const CheckScreenRecordingUseCase(this._repository);

  Future<SecurityResult<bool>> call() => _repository.isScreenBeingRecorded();
}
