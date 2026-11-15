import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/anti_tamper_status.dart';
import '../../domain/repositories/anti_tamper_repository.dart';
import '../datasources/anti_tamper_datasource.dart';

class AntiTamperRepositoryImpl implements AntiTamperRepository {
  final AntiTamperDatasource _datasource;

  const AntiTamperRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<bool>> isDebuggerAttached() => _guard(
    'Debugger detection',
    _datasource.isDebuggerAttached,
  );

  @override
  Future<SecurityResult<bool>> hasInjectedLibraries() => _guard(
    'Injected library detection',
    _datasource.hasInjectedLibraries,
  );

  @override
  Future<SecurityResult<bool>> denyDebuggerAttachment() => _guard(
    'Deny debugger attachment',
    _datasource.denyDebuggerAttachment,
  );

  @override
  Future<SecurityResult<AntiTamperStatus>> check() => _guard(
    'Anti-tamper check',
    () async {
      final debugger = await _datasource.isDebuggerAttached();
      final injected = await _datasource.hasInjectedLibraries();
      return AntiTamperStatus(
        isDebuggerAttached: debugger,
        hasInjectedLibraries: injected,
      );
    },
  );

  Future<SecurityResult<T>> _guard<T>(
    String label,
    Future<T> Function() body,
  ) async {
    try {
      SecurityLogger.info('$label started');
      return Success(await body());
    } catch (e, st) {
      SecurityLogger.error('$label failed', error: e, stackTrace: st);
      return Failure(
        PlatformSecurityException(
          platform: 'native',
          message: '$label failed: $e',
          originalError: e,
        ),
      );
    }
  }
}
