import '../../core/result/security_result.dart';
import '../entities/screen_capture_event.dart';
import '../repositories/screen_capture_repository.dart';

/// Observes screen recording / mirroring changes and screenshots.
class MonitorScreenCaptureUseCase {
  final ScreenCaptureRepository _repository;

  const MonitorScreenCaptureUseCase(this._repository);

  Stream<ScreenCaptureEvent> call() => _repository.events;

  Future<SecurityResult<bool>> isCaptured() => _repository.isCaptured();
}
