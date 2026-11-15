import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/pasteboard_repository.dart';
import '../datasources/pasteboard_datasource.dart';

class PasteboardRepositoryImpl implements PasteboardRepository {
  /// Longest supported expiry. Anything longer defeats the purpose of an
  /// auto-expiring clipboard.
  static const Duration maxExpiry = Duration(hours: 1);

  final PasteboardDatasource _datasource;

  const PasteboardRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<void>> copy({
    required String value,
    required Duration expiresAfter,
  }) async {
    if (value.isEmpty) {
      return const Failure(
        InvalidArgumentSecurityException(
          message: 'Cannot copy an empty value to the pasteboard',
        ),
      );
    }
    if (expiresAfter <= Duration.zero) {
      return const Failure(
        InvalidArgumentSecurityException(
          message: 'Pasteboard expiry must be greater than zero',
        ),
      );
    }
    if (expiresAfter > maxExpiry) {
      return const Failure(
        InvalidArgumentSecurityException(
          message: 'Pasteboard expiry must not exceed one hour',
        ),
      );
    }
    try {
      // Never log the value itself.
      SecurityLogger.info(
        'Copying protected value to pasteboard '
        '(expires in ${expiresAfter.inMilliseconds} ms)',
      );
      await _datasource.copy(
        value: value,
        // Sub-millisecond durations still expire after at least 1 ms.
        expiresAfterMs: expiresAfter.inMilliseconds < 1
            ? 1
            : expiresAfter.inMilliseconds,
      );
      return const Success(null);
    } catch (e, st) {
      SecurityLogger.error('Pasteboard copy failed', error: e, stackTrace: st);
      return Failure(
        PlatformSecurityException(
          platform: 'native',
          message: 'Pasteboard copy failed: $e',
          originalError: e,
        ),
      );
    }
  }

  @override
  Future<SecurityResult<bool>> clear({bool onlyIfOwned = false}) async {
    try {
      SecurityLogger.info('Clearing pasteboard (onlyIfOwned: $onlyIfOwned)');
      return Success(await _datasource.clear(onlyIfOwned: onlyIfOwned));
    } catch (e, st) {
      SecurityLogger.error('Pasteboard clear failed', error: e, stackTrace: st);
      return Failure(
        PlatformSecurityException(
          platform: 'native',
          message: 'Pasteboard clear failed: $e',
          originalError: e,
        ),
      );
    }
  }
}
