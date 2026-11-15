import '../../core/result/security_result.dart';

/// Contract for the protected (local-only, auto-expiring) clipboard.
abstract class PasteboardRepository {
  /// Copies [value] to the clipboard, marked sensitive / local-only, and
  /// removes it again after [expiresAfter].
  Future<SecurityResult<void>> copy({
    required String value,
    required Duration expiresAfter,
  });

  /// Clears the clipboard. With [onlyIfOwned] the clipboard is only cleared
  /// when it still holds the value written by [copy]. Returns `true` when
  /// the clipboard was cleared.
  Future<SecurityResult<bool>> clear({bool onlyIfOwned = false});
}
