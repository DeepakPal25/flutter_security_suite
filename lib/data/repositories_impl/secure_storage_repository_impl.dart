import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/secure_storage_repository.dart';
import '../datasources/secure_storage_datasource.dart';

class SecureStorageRepositoryImpl implements SecureStorageRepository {
  final SecureStorageDatasource _datasource;

  const SecureStorageRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<void>> write({
    required String key,
    required String value,
  }) async {
    try {
      SecurityLogger.info('Writing to secure storage: key=$key');
      await _datasource.write(key: key, value: value);
      return const Success(null);
    } catch (e, st) {
      SecurityLogger.error(
        'Secure storage write failed',
        error: e,
        stackTrace: st,
      );
      return Failure(SecureStorageException(
        key: key,
        message: 'Write failed: $e',
        originalError: e,
      ));
    }
  }

  @override
  Future<SecurityResult<String?>> read({required String key}) async {
    try {
      SecurityLogger.info('Reading from secure storage: key=$key');
      final value = await _datasource.read(key: key);
      return Success(value);
    } catch (e, st) {
      SecurityLogger.error(
        'Secure storage read failed',
        error: e,
        stackTrace: st,
      );
      return Failure(SecureStorageException(
        key: key,
        message: 'Read failed: $e',
        originalError: e,
      ));
    }
  }

  @override
  Future<SecurityResult<void>> delete({required String key}) async {
    try {
      SecurityLogger.info('Deleting from secure storage: key=$key');
      await _datasource.delete(key: key);
      return const Success(null);
    } catch (e, st) {
      SecurityLogger.error(
        'Secure storage delete failed',
        error: e,
        stackTrace: st,
      );
      return Failure(SecureStorageException(
        key: key,
        message: 'Delete failed: $e',
        originalError: e,
      ));
    }
  }

  @override
  Future<SecurityResult<void>> deleteAll() async {
    try {
      SecurityLogger.info('Deleting all secure storage entries');
      await _datasource.deleteAll();
      return const Success(null);
    } catch (e, st) {
      SecurityLogger.error(
        'Secure storage deleteAll failed',
        error: e,
        stackTrace: st,
      );
      return Failure(SecureStorageException(
        message: 'DeleteAll failed: $e',
        originalError: e,
      ));
    }
  }
}
