import '../../core/result/security_result.dart';

/// Contract for application integrity verification.
abstract class AppIntegrityRepository {
  /// Returns `true` if the app has not been tampered with.
  ///
  /// Checks may include debugger detection, installer verification,
  /// and signature validation.
  Future<SecurityResult<bool>> isAppIntegrityValid();
}
