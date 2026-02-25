import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/root_detection_repository.dart';
import '../datasources/root_detection_datasource.dart';

class RootDetectionRepositoryImpl implements RootDetectionRepository {
  final RootDetectionDatasource _datasource;

  const RootDetectionRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<bool>> isDeviceRooted() async {
    try {
      SecurityLogger.info('Checking root/jailbreak status');
      final isRooted = await _datasource.isDeviceRooted();
      return Success(isRooted);
    } catch (e, st) {
      SecurityLogger.error('Root detection failed', error: e, stackTrace: st);
      return Failure(
        PlatformSecurityException(
          platform: 'native',
          message: 'Root detection failed: $e',
          originalError: e,
        ),
      );
    }
  }
}
