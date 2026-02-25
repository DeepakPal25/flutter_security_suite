import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/secure_storage_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/secure_storage_repository_impl.dart';

class MockSecureStorageDatasource extends Mock
    implements SecureStorageDatasource {}

void main() {
  late MockSecureStorageDatasource mockDs;
  late SecureStorageRepositoryImpl sut;

  setUp(() {
    mockDs = MockSecureStorageDatasource();
    sut = SecureStorageRepositoryImpl(mockDs);
  });

  group('write', () {
    test('returns Success when datasource succeeds', () async {
      when(() => mockDs.write(key: 'k', value: 'v'))
          .thenAnswer((_) async {});

      final result = await sut.write(key: 'k', value: 'v');

      expect(result, isA<Success<void>>());
    });

    test('returns Failure when datasource throws', () async {
      when(() => mockDs.write(key: 'k', value: 'v'))
          .thenThrow(Exception('write error'));

      final result = await sut.write(key: 'k', value: 'v');

      expect(result, isA<Failure<void>>());
    });
  });

  group('read', () {
    test('returns Success with value', () async {
      when(() => mockDs.read(key: 'k')).thenAnswer((_) async => 'secret');

      final result = await sut.read(key: 'k');

      expect(result.dataOrNull, 'secret');
    });

    test('returns Success(null) when key absent', () async {
      when(() => mockDs.read(key: 'missing')).thenAnswer((_) async => null);

      final result = await sut.read(key: 'missing');

      expect(result, isA<Success<String?>>());
      expect(result.dataOrNull, isNull);
    });

    test('returns Failure when datasource throws', () async {
      when(() => mockDs.read(key: 'k')).thenThrow(Exception('read error'));

      final result = await sut.read(key: 'k');

      expect(result, isA<Failure<String?>>());
    });
  });

  group('delete', () {
    test('returns Success when datasource succeeds', () async {
      when(() => mockDs.delete(key: 'k')).thenAnswer((_) async {});

      final result = await sut.delete(key: 'k');

      expect(result, isA<Success<void>>());
    });

    test('returns Failure when datasource throws', () async {
      when(() => mockDs.delete(key: 'k'))
          .thenThrow(Exception('delete error'));

      final result = await sut.delete(key: 'k');

      expect(result, isA<Failure<void>>());
    });
  });

  group('deleteAll', () {
    test('returns Success when datasource succeeds', () async {
      when(() => mockDs.deleteAll()).thenAnswer((_) async {});

      final result = await sut.deleteAll();

      expect(result, isA<Success<void>>());
    });

    test('returns Failure when datasource throws', () async {
      when(() => mockDs.deleteAll()).thenThrow(Exception('clear error'));

      final result = await sut.deleteAll();

      expect(result, isA<Failure<void>>());
    });
  });
}
