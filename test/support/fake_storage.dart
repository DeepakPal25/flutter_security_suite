import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/repositories/secure_storage_repository.dart';

/// In-memory [SecureStorageRepository] with switches to simulate failures.
class FakeStorage implements SecureStorageRepository {
  final Map<String, String> data = {};

  /// Keys whose write / read / delete returns a `Failure`.
  final Set<String> failWrites = {};
  final Set<String> failReads = {};
  final Set<String> failDeletes = {};

  /// Keys whose read throws instead of returning.
  final Set<String> throwReads = {};
  final Set<String> throwWrites = {};
  final Set<String> throwDeletes = {};

  final List<String> log = [];

  static const failure = Failure<Never>(
    SecureStorageException(message: 'keystore unavailable'),
  );

  @override
  Future<SecurityResult<void>> write({
    required String key,
    required String value,
  }) async {
    log.add('write:$key');
    if (throwWrites.contains(key)) throw StateError('write blew up');
    if (failWrites.contains(key)) return failure;
    data[key] = value;
    return const Success(null);
  }

  @override
  Future<SecurityResult<String?>> read({required String key}) async {
    log.add('read:$key');
    if (throwReads.contains(key)) throw StateError('read blew up');
    if (failReads.contains(key)) return failure;
    return Success(data[key]);
  }

  @override
  Future<SecurityResult<void>> delete({required String key}) async {
    log.add('delete:$key');
    if (throwDeletes.contains(key)) throw StateError('delete blew up');
    if (failDeletes.contains(key)) return failure;
    data.remove(key);
    return const Success(null);
  }

  @override
  Future<SecurityResult<void>> deleteAll() async {
    log.add('deleteAll');
    data.clear();
    return const Success(null);
  }
}
