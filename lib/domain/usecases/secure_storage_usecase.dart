import '../../core/result/security_result.dart';
import '../repositories/secure_storage_repository.dart';

/// Provides encrypted key-value storage operations.
class SecureStorageUseCase {
  final SecureStorageRepository _repository;

  const SecureStorageUseCase(this._repository);

  Future<SecurityResult<void>> write({
    required String key,
    required String value,
  }) {
    return _repository.write(key: key, value: value);
  }

  Future<SecurityResult<String?>> read({required String key}) {
    return _repository.read(key: key);
  }

  Future<SecurityResult<void>> delete({required String key}) {
    return _repository.delete(key: key);
  }

  Future<SecurityResult<void>> deleteAll() {
    return _repository.deleteAll();
  }
}
