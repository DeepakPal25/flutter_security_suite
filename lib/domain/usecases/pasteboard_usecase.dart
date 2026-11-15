import '../../core/result/security_result.dart';
import '../repositories/pasteboard_repository.dart';

/// Copies sensitive values to a local-only, auto-expiring clipboard.
class PasteboardUseCase {
  /// Expiry applied when the caller does not pass one.
  static const Duration defaultExpiry = Duration(seconds: 60);

  final PasteboardRepository _repository;

  const PasteboardUseCase(this._repository);

  Future<SecurityResult<void>> copy({
    required String value,
    Duration expiresAfter = defaultExpiry,
  }) => _repository.copy(value: value, expiresAfter: expiresAfter);

  Future<SecurityResult<bool>> clear({bool onlyIfOwned = false}) =>
      _repository.clear(onlyIfOwned: onlyIfOwned);
}
