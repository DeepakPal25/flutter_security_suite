import '../../core/result/security_result.dart';
import '../entities/anti_tamper_status.dart';
import '../repositories/anti_tamper_repository.dart';

/// Detects attached debuggers and injected dynamic libraries.
class CheckAntiTamperUseCase {
  final AntiTamperRepository _repository;

  const CheckAntiTamperUseCase(this._repository);

  Future<SecurityResult<AntiTamperStatus>> call() => _repository.check();

  Future<SecurityResult<bool>> isDebuggerAttached() =>
      _repository.isDebuggerAttached();

  Future<SecurityResult<bool>> hasInjectedLibraries() =>
      _repository.hasInjectedLibraries();

  Future<SecurityResult<bool>> denyDebuggerAttachment() =>
      _repository.denyDebuggerAttachment();
}
