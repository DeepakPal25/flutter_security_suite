import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/tamper_detection_repository.dart';
import '../datasources/tamper_detection_datasource.dart';

class TamperDetectionRepositoryImpl implements TamperDetectionRepository {
  final TamperDetectionDatasource _datasource;

  const TamperDetectionRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<bool>> isTampered() async {
    try {
      SecurityLogger.info('Checking app tamper status');
      final result = await _datasource.isTampered();
      return Success(result);
    } catch (e, st) {
      SecurityLogger.error('Tamper detection failed', error: e, stackTrace: st);
      return Failure(
        PlatformSecurityException(
          platform: 'native',
          message: 'Tamper detection failed: $e',
          originalError: e,
        ),
      );
    }
  }

  @override
  Future<SecurityResult<String?>> getSignatureHash() async {
    try {
      SecurityLogger.info('Retrieving signing certificate hash');
      final hash = await _datasource.getSignatureHash();
      return Success(hash);
    } catch (e, st) {
      SecurityLogger.error(
        'Signature hash retrieval failed',
        error: e,
        stackTrace: st,
      );
      return Failure(
        PlatformSecurityException(
          platform: 'native',
          message: 'Signature hash retrieval failed: $e',
          originalError: e,
        ),
      );
    }
  }
}
