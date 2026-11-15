import '../../core/result/security_result.dart';
import '../entities/screen_capture_event.dart';

/// Contract for live screen-capture monitoring.
abstract class ScreenCaptureRepository {
  /// Broadcast stream of capture-state changes and screenshot events.
  Stream<ScreenCaptureEvent> get events;

  /// Returns `true` if the screen is being recorded or mirrored right now.
  Future<SecurityResult<bool>> isCaptured();
}
