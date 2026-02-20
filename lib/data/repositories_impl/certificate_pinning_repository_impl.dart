import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/certificate_pinning_repository.dart';
import '../datasources/certificate_pinning_datasource.dart';

class CertificatePinningRepositoryImpl
    implements CertificatePinningRepository {
  final CertificatePinningDatasource _datasource;

  const CertificatePinningRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<bool>> validateCertificate({
    required String host,
    required List<String> pins,
  }) async {
    try {
      SecurityLogger.info('Validating certificate for $host');
      final isValid = await _datasource.validateCertificate(
        host: host,
        pins: pins,
      );
      return Success(isValid);
    } catch (e, st) {
      SecurityLogger.error(
        'Certificate pinning failed for $host',
        error: e,
        stackTrace: st,
      );
      return Failure(CertificatePinningException(
        host: host,
        message: e.toString(),
        originalError: e,
      ));
    }
  }
}
