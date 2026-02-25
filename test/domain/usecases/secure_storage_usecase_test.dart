import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/repositories/secure_storage_repository.dart';
import 'package:flutter_security_suite/domain/usecases/secure_storage_usecase.dart';

class MockSecureStorageRepository extends Mock
    implements SecureStorageRepository {}

void main() {
  late MockSecureStorageRepository mockRepo;
  late SecureStorageUseCase sut;

  setUp(() {
    mockRepo = MockSecureStorageRepository();
    sut = SecureStorageUseCase(mockRepo);
  });

  group('write', () {
    test('delegates to repository and returns Success', () async {
      when(
        () => mockRepo.write(key: 'k', value: 'v'),
      ).thenAnswer((_) async => const Success(null));

      final result = await sut.write(key: 'k', value: 'v');

      expect(result, isA<Success<void>>());
      verify(() => mockRepo.write(key: 'k', value: 'v')).called(1);
    });
  });

  group('read', () {
    test('returns stored value on success', () async {
      when(
        () => mockRepo.read(key: 'k'),
      ).thenAnswer((_) async => const Success('secret'));

      final result = await sut.read(key: 'k');

      expect(result.dataOrNull, 'secret');
    });

    test('returns null when key is absent', () async {
      when(
        () => mockRepo.read(key: 'missing'),
      ).thenAnswer((_) async => const Success(null));

      final result = await sut.read(key: 'missing');

      expect(result.dataOrNull, isNull);
      expect(result, isA<Success<String?>>());
    });
  });

  group('delete', () {
    test('delegates to repository', () async {
      when(
        () => mockRepo.delete(key: 'k'),
      ).thenAnswer((_) async => const Success(null));

      final result = await sut.delete(key: 'k');

      expect(result, isA<Success<void>>());
    });
  });

  group('deleteAll', () {
    test('delegates to repository', () async {
      when(
        () => mockRepo.deleteAll(),
      ).thenAnswer((_) async => const Success(null));

      final result = await sut.deleteAll();

      expect(result, isA<Success<void>>());
    });

    test('returns Failure on error', () async {
      when(() => mockRepo.deleteAll()).thenAnswer(
        (_) async => Failure(SecureStorageException(message: 'wipe failed')),
      );

      final result = await sut.deleteAll();

      expect(result, isA<Failure<void>>());
    });
  });
}
