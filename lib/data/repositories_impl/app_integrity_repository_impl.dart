import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/app_integrity_repository.dart';
import '../datasources/app_integrity_datasource.dart';

class AppIntegrityRepositoryImpl implements AppIntegrityRepository {
  final AppIntegrityDatasource _datasource;

  const AppIntegrityRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<bool>> isAppIntegrityValid() async {
    try {
      SecurityLogger.info('Checking app integrity');
      final isValid = await _datasource.isAppIntegrityValid();
      return Success(isValid);
    } catch (e, st) {
      SecurityLogger.error(
        'App integrity check failed',
        error: e,
        stackTrace: st,
      );
      return Failure(
        PlatformSecurityException(
          platform: 'native',
          message: 'App integrity check failed: $e',
          originalError: e,
        ),
      );
    }
  }
}
