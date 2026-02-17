import '../../core/result/security_result.dart';

/// Contract for platform-encrypted key-value storage.
abstract class SecureStorageRepository {
  /// Write [value] for the given [key].
  Future<SecurityResult<void>> write({
    required String key,
    required String value,
  });

  /// Read the value stored under [key], or `null` if absent.
  Future<SecurityResult<String?>> read({required String key});

  /// Delete the entry stored under [key].
  Future<SecurityResult<void>> delete({required String key});

  /// Delete all entries.
  Future<SecurityResult<void>> deleteAll();
}
