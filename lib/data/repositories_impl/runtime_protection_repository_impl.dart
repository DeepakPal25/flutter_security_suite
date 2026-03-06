import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/runtime_protection_repository.dart';
import '../datasources/runtime_protection_datasource.dart';

class RuntimeProtectionRepositoryImpl implements RuntimeProtectionRepository {
  final RuntimeProtectionDatasource _datasource;

  const RuntimeProtectionRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<bool>> isRuntimeHooked() async {
    try {
      SecurityLogger.info('Checking runtime hooking/instrumentation status');
      final result = await _datasource.isRuntimeHooked();
      return Success(result);
    } catch (e, st) {
      SecurityLogger.error(
        'Runtime protection check failed',
        error: e,
        stackTrace: st,
      );
      return Failure(
        PlatformSecurityException(
          platform: 'native',
          message: 'Runtime protection check failed: $e',
          originalError: e,
        ),
      );
    }
  }
}
