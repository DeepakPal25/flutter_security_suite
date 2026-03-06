import '../../core/result/security_result.dart';
import '../repositories/runtime_protection_repository.dart';

/// Checks whether a hooking/instrumentation framework is active at runtime.
class CheckRuntimeProtectionUseCase {
  final RuntimeProtectionRepository _repository;

  const CheckRuntimeProtectionUseCase(this._repository);

  Future<SecurityResult<bool>> call() => _repository.isRuntimeHooked();
}
