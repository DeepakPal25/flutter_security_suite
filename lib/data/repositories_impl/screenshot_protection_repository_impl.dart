import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/screenshot_protection_repository.dart';
import '../datasources/screenshot_protection_datasource.dart';

class ScreenshotProtectionRepositoryImpl
    implements ScreenshotProtectionRepository {
  final ScreenshotProtectionDatasource _datasource;

  const ScreenshotProtectionRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<void>> enableProtection() async {
    try {
      SecurityLogger.info('Enabling screenshot protection');
      await _datasource.enable();
      return const Success(null);
    } catch (e, st) {
      SecurityLogger.error(
        'Failed to enable screenshot protection',
        error: e,
        stackTrace: st,
      );
      return Failure(PlatformSecurityException(
        platform: 'native',
        message: 'Screenshot protection enable failed: $e',
        originalError: e,
      ));
    }
  }

  @override
  Future<SecurityResult<void>> disableProtection() async {
    try {
      SecurityLogger.info('Disabling screenshot protection');
      await _datasource.disable();
      return const Success(null);
    } catch (e, st) {
      SecurityLogger.error(
        'Failed to disable screenshot protection',
        error: e,
        stackTrace: st,
      );
      return Failure(PlatformSecurityException(
        platform: 'native',
        message: 'Screenshot protection disable failed: $e',
        originalError: e,
      ));
    }
  }
}
