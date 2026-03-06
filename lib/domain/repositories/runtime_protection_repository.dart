import '../../core/result/security_result.dart';

/// Contract for runtime instrumentation / hooking detection.
abstract class RuntimeProtectionRepository {
  /// Returns `true` when a hooking framework (Frida, Xposed, etc.) or an
  /// attached debugger is detected at runtime.
  Future<SecurityResult<bool>> isRuntimeHooked();
}
