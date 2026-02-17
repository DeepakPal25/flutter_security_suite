import '../../core/result/security_result.dart';

/// Contract for screenshot / screen-capture protection.
abstract class ScreenshotProtectionRepository {
  /// Enable screenshot protection on the current activity/window.
  Future<SecurityResult<void>> enableProtection();

  /// Disable screenshot protection on the current activity/window.
  Future<SecurityResult<void>> disableProtection();
}
