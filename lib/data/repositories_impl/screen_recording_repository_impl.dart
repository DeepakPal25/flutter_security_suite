import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/screen_recording_repository.dart';
import '../datasources/screen_recording_datasource.dart';

class ScreenRecordingRepositoryImpl implements ScreenRecordingRepository {
  final ScreenRecordingDatasource _datasource;

  const ScreenRecordingRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<bool>> isScreenBeingRecorded() async {
    try {
      SecurityLogger.info('Checking screen recording status');
      final result = await _datasource.isScreenBeingRecorded();
      return Success(result);
    } catch (e, st) {
      SecurityLogger.error(
        'Screen recording detection failed',
        error: e,
        stackTrace: st,
      );
      return Failure(
        PlatformSecurityException(
          platform: 'native',
          message: 'Screen recording detection failed: $e',
          originalError: e,
        ),
      );
    }
  }
}
