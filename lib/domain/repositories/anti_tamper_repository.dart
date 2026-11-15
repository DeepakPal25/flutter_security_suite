import '../../core/result/security_result.dart';
import '../entities/anti_tamper_status.dart';

/// Contract for debugger and dynamic-library injection detection.
abstract class AntiTamperRepository {
  /// Returns `true` if a debugger / tracer is attached to the process.
  Future<SecurityResult<bool>> isDebuggerAttached();

  /// Returns `true` if injected dynamic libraries are detected.
  Future<SecurityResult<bool>> hasInjectedLibraries();

  /// Runs both checks.
  Future<SecurityResult<AntiTamperStatus>> check();

  /// Asks the OS to refuse future debugger attachment. Returns `true` when
  /// attachment is denied for this process.
  Future<SecurityResult<bool>> denyDebuggerAttachment();
}
