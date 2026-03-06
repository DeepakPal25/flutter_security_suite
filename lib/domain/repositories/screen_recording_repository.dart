import '../../core/result/security_result.dart';

/// Contract for screen recording / mirroring detection.
abstract class ScreenRecordingRepository {
  /// Returns `true` if the screen is currently being recorded or mirrored.
  Future<SecurityResult<bool>> isScreenBeingRecorded();
}
