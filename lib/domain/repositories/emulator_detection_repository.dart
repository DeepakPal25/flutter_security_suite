import '../../core/result/security_result.dart';

/// Contract for emulator / simulator detection.
abstract class EmulatorDetectionRepository {
  /// Returns `true` if the app is running on an emulator or simulator.
  Future<SecurityResult<bool>> isEmulator();
}
