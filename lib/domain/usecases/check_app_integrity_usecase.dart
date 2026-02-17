import '../../core/result/security_result.dart';
import '../repositories/app_integrity_repository.dart';

/// Verifies that the application has not been tampered with.
class CheckAppIntegrityUseCase {
  final AppIntegrityRepository _repository;

  const CheckAppIntegrityUseCase(this._repository);

  Future<SecurityResult<bool>> call() {
    return _repository.isAppIntegrityValid();
  }
}
