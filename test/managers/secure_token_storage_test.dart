import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/repositories/secure_storage_repository.dart';
import 'package:flutter_security_suite/managers/secure_token_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSecureStorageRepository extends Mock
    implements SecureStorageRepository {}

/// Simple in-memory repository used for round-trip tests.
class InMemoryStorage implements SecureStorageRepository {
  final Map<String, String> data = {};

  @override
  Future<SecurityResult<void>> write({
    required String key,
    required String value,
  }) async {
    data[key] = value;
    return const Success(null);
  }

  @override
  Future<SecurityResult<String?>> read({required String key}) async =>
      Success(data[key]);

  @override
  Future<SecurityResult<void>> delete({required String key}) async {
    data.remove(key);
    return const Success(null);
  }

  @override
  Future<SecurityResult<void>> deleteAll() async {
    data.clear();
    return const Success(null);
  }
}

const _storageFailure = Failure<Never>(
  SecureStorageException(message: 'keystore unavailable'),
);

void main() {
  late MockSecureStorageRepository repo;
  late SecureTokenStorage sut;

  setUp(() {
    repo = MockSecureStorageRepository();
    sut = SecureTokenStorage(repo);
  });

  group('construction', () {
    test('uses the default namespace', () {
      expect(sut.accessTokenKey, 'sbk.access_token');
      expect(sut.refreshTokenKey, 'sbk.refresh_token');
    });

    test('trims a custom namespace', () {
      final custom = SecureTokenStorage(repo, namespace: '  bank  ');
      expect(custom.accessTokenKey, 'bank.access_token');
      expect(custom.refreshTokenKey, 'bank.refresh_token');
    });

    test('rejects a blank namespace', () {
      expect(() => SecureTokenStorage(repo, namespace: ''), throwsArgumentError);
      expect(
        () => SecureTokenStorage(repo, namespace: '   '),
        throwsArgumentError,
      );
    });
  });

  group('round trip (in-memory)', () {
    late InMemoryStorage memory;

    setUp(() {
      memory = InMemoryStorage();
      sut = SecureTokenStorage(memory);
    });

    test('saves, reads and clears both tokens', () async {
      expect((await sut.hasAccessToken()).dataOrNull, isFalse);

      final saved = await sut.saveTokens(accessToken: 'a1', refreshToken: 'r1');
      expect(saved.isSuccess, isTrue);
      expect((await sut.getAccessToken()).dataOrNull, 'a1');
      expect((await sut.getRefreshToken()).dataOrNull, 'r1');
      expect((await sut.hasAccessToken()).dataOrNull, isTrue);

      expect((await sut.clearTokens()).isSuccess, isTrue);
      expect((await sut.getAccessToken()).dataOrNull, isNull);
      expect((await sut.getRefreshToken()).dataOrNull, isNull);
      expect(memory.data, isEmpty);
    });

    test('saveTokens without refresh token keeps the stored one', () async {
      await sut.saveTokens(accessToken: 'a1', refreshToken: 'r1');
      await sut.saveTokens(accessToken: 'a2');
      expect((await sut.getAccessToken()).dataOrNull, 'a2');
      expect((await sut.getRefreshToken()).dataOrNull, 'r1');
    });

    test('namespaces are isolated from each other', () async {
      final other = SecureTokenStorage(memory, namespace: 'other');
      await sut.saveAccessToken('mine');
      await other.saveAccessToken('theirs');
      expect((await sut.getAccessToken()).dataOrNull, 'mine');
      expect((await other.getAccessToken()).dataOrNull, 'theirs');
      await other.clearTokens();
      expect((await sut.getAccessToken()).dataOrNull, 'mine');
    });

    test('clearing one token leaves the other', () async {
      await sut.saveTokens(accessToken: 'a1', refreshToken: 'r1');
      await sut.clearAccessToken();
      expect((await sut.getAccessToken()).dataOrNull, isNull);
      expect((await sut.getRefreshToken()).dataOrNull, 'r1');
    });

    test('treats a stored empty string as no token', () async {
      memory.data[sut.accessTokenKey] = '';
      expect((await sut.getAccessToken()).dataOrNull, isNull);
      expect((await sut.hasAccessToken()).dataOrNull, isFalse);
    });

    test('preserves tokens with unusual characters verbatim', () async {
      const token = ' eyJ.päylöad.🔐\n ';
      await sut.saveAccessToken(token);
      expect((await sut.getAccessToken()).dataOrNull, token);
    });
  });

  group('saving', () {
    test('writes the access token under the namespaced key', () async {
      when(
        () => repo.write(key: any(named: 'key'), value: any(named: 'value')),
      ).thenAnswer((_) async => const Success(null));

      final result = await sut.saveAccessToken('abc');

      expect(result.isSuccess, isTrue);
      verify(() => repo.write(key: 'sbk.access_token', value: 'abc')).called(1);
    });

    test('rejects empty and blank tokens without touching storage', () async {
      for (final bad in ['', '   ', '\n\t']) {
        final access = await sut.saveAccessToken(bad);
        final refresh = await sut.saveRefreshToken(bad);
        for (final result in [access, refresh]) {
          expect(result, isA<Failure<void>>());
          final error = (result as Failure<void>).error;
          expect(error, isA<TokenException>());
          expect(error.code, TokenException.invalidToken);
        }
      }
      verifyNever(
        () => repo.write(key: any(named: 'key'), value: any(named: 'value')),
      );
    });

    test('passes storage failures through', () async {
      when(
        () => repo.write(key: any(named: 'key'), value: any(named: 'value')),
      ).thenAnswer((_) async => _storageFailure);

      final result = await sut.saveRefreshToken('abc');

      expect(result.isFailure, isTrue);
      expect((result as Failure<void>).error, isA<SecureStorageException>());
    });

    test('converts a thrown error into a TokenException', () async {
      final boom = StateError('boom');
      when(
        () => repo.write(key: any(named: 'key'), value: any(named: 'value')),
      ).thenThrow(boom);

      final result = await sut.saveAccessToken('abc');

      final error = (result as Failure<void>).error;
      expect(error, isA<TokenException>());
      expect(error.originalError, same(boom));
      expect(error.message, isNot(contains('abc')));
    });

    test('saveTokens validates both tokens before writing anything', () async {
      final result = await sut.saveTokens(accessToken: 'ok', refreshToken: ' ');

      expect((result as Failure<void>).error.code, TokenException.invalidToken);
      verifyNever(
        () => repo.write(key: any(named: 'key'), value: any(named: 'value')),
      );
    });

    test('saveTokens rejects an empty access token', () async {
      final result = await sut.saveTokens(accessToken: '', refreshToken: 'r');
      expect((result as Failure<void>).error.code, TokenException.invalidToken);
      verifyNever(
        () => repo.write(key: any(named: 'key'), value: any(named: 'value')),
      );
    });

    test('saveTokens stops when the access token cannot be saved', () async {
      when(
        () => repo.write(key: 'sbk.access_token', value: any(named: 'value')),
      ).thenAnswer((_) async => _storageFailure);

      final result = await sut.saveTokens(accessToken: 'a', refreshToken: 'r');

      expect(result.isFailure, isTrue);
      verifyNever(
        () => repo.write(key: 'sbk.refresh_token', value: any(named: 'value')),
      );
    });

    test('saveTokens reports a refresh token write failure', () async {
      when(
        () => repo.write(key: 'sbk.access_token', value: any(named: 'value')),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => repo.write(key: 'sbk.refresh_token', value: any(named: 'value')),
      ).thenAnswer((_) async => _storageFailure);

      final result = await sut.saveTokens(accessToken: 'a', refreshToken: 'r');

      expect(result.isFailure, isTrue);
      verify(() => repo.write(key: 'sbk.access_token', value: 'a')).called(1);
    });
  });

  group('reading', () {
    test('returns null when nothing is stored', () async {
      when(
        () => repo.read(key: any(named: 'key')),
      ).thenAnswer((_) async => const Success(null));

      expect((await sut.getAccessToken()).dataOrNull, isNull);
      expect((await sut.getAccessToken()).isSuccess, isTrue);
      expect((await sut.getRefreshToken()).isSuccess, isTrue);
    });

    test('passes storage failures through', () async {
      when(
        () => repo.read(key: any(named: 'key')),
      ).thenAnswer((_) async => _storageFailure);

      final result = await sut.getAccessToken();
      expect((result as Failure<String?>).error, isA<SecureStorageException>());
    });

    test('converts a thrown error into a TokenException', () async {
      when(() => repo.read(key: any(named: 'key'))).thenThrow(Exception('x'));

      final result = await sut.getRefreshToken();
      expect((result as Failure<String?>).error, isA<TokenException>());
    });

    test('hasAccessToken propagates read failures', () async {
      when(
        () => repo.read(key: any(named: 'key')),
      ).thenAnswer((_) async => _storageFailure);

      expect((await sut.hasAccessToken()).isFailure, isTrue);
    });
  });

  group('clearing', () {
    test('clearTokens deletes both keys', () async {
      when(
        () => repo.delete(key: any(named: 'key')),
      ).thenAnswer((_) async => const Success(null));

      expect((await sut.clearTokens()).isSuccess, isTrue);
      verify(() => repo.delete(key: 'sbk.access_token')).called(1);
      verify(() => repo.delete(key: 'sbk.refresh_token')).called(1);
    });

    test('clearTokens still clears the refresh token when the access token '
        'delete fails, and reports the failure', () async {
      when(
        () => repo.delete(key: 'sbk.access_token'),
      ).thenAnswer((_) async => _storageFailure);
      when(
        () => repo.delete(key: 'sbk.refresh_token'),
      ).thenAnswer((_) async => const Success(null));

      final result = await sut.clearTokens();

      expect(result.isFailure, isTrue);
      verify(() => repo.delete(key: 'sbk.refresh_token')).called(1);
    });

    test('clearTokens reports a refresh token delete failure', () async {
      when(
        () => repo.delete(key: 'sbk.access_token'),
      ).thenAnswer((_) async => const Success(null));
      when(
        () => repo.delete(key: 'sbk.refresh_token'),
      ).thenAnswer((_) async => _storageFailure);

      expect((await sut.clearTokens()).isFailure, isTrue);
    });

    test('converts a thrown error into a TokenException', () async {
      when(() => repo.delete(key: any(named: 'key'))).thenThrow(Exception('x'));

      final result = await sut.clearAccessToken();
      expect((result as Failure<void>).error, isA<TokenException>());
      final both = await sut.clearTokens();
      expect((both as Failure<void>).error, isA<TokenException>());
    });
  });
}
