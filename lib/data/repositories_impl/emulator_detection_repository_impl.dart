import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/emulator_detection_repository.dart';
import '../datasources/emulator_detection_datasource.dart';

class EmulatorDetectionRepositoryImpl implements EmulatorDetectionRepository {
  final EmulatorDetectionDatasource _datasource;

  const EmulatorDetectionRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<bool>> isEmulator() async {
    try {
      SecurityLogger.info('Checking emulator/simulator status');
      final result = await _datasource.isEmulator();
      return Success(result);
    } catch (e, st) {
      SecurityLogger.error('Emulator detection failed', error: e, stackTrace: st);
      return Failure(
        PlatformSecurityException(
          platform: 'native',
          message: 'Emulator detection failed: $e',
          originalError: e,
        ),
      );
    }
  }
}
