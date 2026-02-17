import '../../core/result/security_result.dart';

/// Contract for root / jailbreak detection.
abstract class RootDetectionRepository {
  /// Returns `true` if the device is rooted or jailbroken.
  Future<SecurityResult<bool>> isDeviceRooted();
}
