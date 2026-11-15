import 'dart:async';

import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/managers/secure_token_storage.dart';
import 'package:flutter_security_suite/managers/token_expiry_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_storage.dart';

const _access = 'sbk.access_token';
const _refresh = 'sbk.refresh_token';
const _expiry = 'sbk.token_expiry';

void main() {
  final start = DateTime.utc(2026, 1, 1, 12);
  late DateTime clock;
  late FakeStorage storage;
  late SecureTokenStorage tokens;
  late TokenExpiryManager sut;

  setUp(() {
    clock = start;
    storage = FakeStorage();
    tokens = SecureTokenStorage(storage);
    sut = TokenExpiryManager(
      storage: storage,
      tokenStorage: tokens,
      now: () => clock,
    );
  });

  TokenException tokenError(SecurityResult<Object?> result) {
    expect(result, isA<Failure<Object?>>());
    final error = (result as Failure<Object?>).error;
    expect(error, isA<TokenException>());
    return error as TokenException;
  }

  group('construction', () {
    test('rejects a negative refresh buffer', () {
      expect(
        () => TokenExpiryManager(
          storage: storage,
          tokenStorage: tokens,
          defaultRefreshBuffer: const Duration(seconds: -1),
        ),
        throwsArgumentError,
      );
    });

    test('accepts a zero refresh buffer', () {
      final manager = TokenExpiryManager(
        storage: storage,
        tokenStorage: tokens,
        defaultRefreshBuffer: Duration.zero,
      );
      expect(manager.defaultRefreshBuffer, Duration.zero);
    });

    test('derives the expiry key from the token namespace', () {
      final manager = TokenExpiryManager(
        storage: storage,
        tokenStorage: SecureTokenStorage(storage, namespace: 'bank'),
      );
      expect(manager.expiryKey, 'bank.token_expiry');
      expect(sut.expiryKey, _expiry);
    });

    test('is not refreshing initially', () {
      expect(sut.isRefreshing, isFalse);
    });
  });

  group('setExpiry / getExpiry', () {
    test('round-trips a UTC expiry', () async {
      final at = start.add(const Duration(hours: 1));
      expect((await sut.setExpiry(at)).isSuccess, isTrue);
      expect(storage.data[_expiry], '${at.millisecondsSinceEpoch}');
      final read = await sut.getExpiry();
      expect(read.dataOrNull, at);
      expect(read.dataOrNull!.isUtc, isTrue);
    });

    test('normalises a local time to UTC', () async {
      final local = DateTime(2026, 6, 1, 10, 30);
      await sut.setExpiry(local);
      final read = (await sut.getExpiry()).dataOrNull!;
      expect(read.isUtc, isTrue);
      expect(read.isAtSameMomentAs(local), isTrue);
    });

    test('setExpiresIn is relative to the injected clock', () async {
      await sut.setExpiresIn(const Duration(minutes: 15));
      expect(
        (await sut.getExpiry()).dataOrNull,
        start.add(const Duration(minutes: 15)),
      );
    });

    test('a negative lifetime is stored as already expired', () async {
      await sut.setExpiresIn(const Duration(minutes: -5));
      expect(await sut.isTokenExpired(), isTrue);
    });

    test('returns null when nothing is stored', () async {
      final read = await sut.getExpiry();
      expect(read.isSuccess, isTrue);
      expect(read.dataOrNull, isNull);
    });

    test('returns null for corrupt values', () async {
      for (final raw in ['', '   ', 'abc', '12.5', '1e3', 'null']) {
        storage.data[_expiry] = raw;
        final read = await sut.getExpiry();
        expect(read.isSuccess, isTrue, reason: 'raw: "$raw"');
        expect(read.dataOrNull, isNull, reason: 'raw: "$raw"');
      }
    });

    test('tolerates surrounding whitespace', () async {
      storage.data[_expiry] = '  ${start.millisecondsSinceEpoch}\n';
      expect((await sut.getExpiry()).dataOrNull, start);
    });

    test('returns null for a value outside the DateTime range', () async {
      storage.data[_expiry] = '8640000000000001';
      expect((await sut.getExpiry()).dataOrNull, isNull);
      storage.data[_expiry] = '99999999999999999999999999';
      expect((await sut.getExpiry()).dataOrNull, isNull);
    });

    test('passes a storage read failure through', () async {
      storage.failReads.add(_expiry);
      final read = await sut.getExpiry();
      expect(read.isFailure, isTrue);
      expect((read as Failure).error, isA<SecureStorageException>());
    });

    test('wraps a throwing read', () async {
      storage.throwReads.add(_expiry);
      final error = tokenError(await sut.getExpiry());
      expect(error.message, 'Reading the expiry failed');
      expect(error.originalError, isA<StateError>());
    });

    test('passes a storage write failure through', () async {
      storage.failWrites.add(_expiry);
      expect((await sut.setExpiry(start)).isFailure, isTrue);
    });

    test('wraps a throwing write', () async {
      storage.throwWrites.add(_expiry);
      final error = tokenError(await sut.setExpiry(start));
      expect(error.message, 'Saving the expiry failed');
    });
  });

  group('clearExpiry', () {
    test('removes the stored expiry', () async {
      await sut.setExpiry(start);
      expect((await sut.clearExpiry()).isSuccess, isTrue);
      expect(storage.data.containsKey(_expiry), isFalse);
    });

    test('succeeds when nothing is stored', () async {
      expect((await sut.clearExpiry()).isSuccess, isTrue);
    });

    test('passes a delete failure through', () async {
      storage.failDeletes.add(_expiry);
      expect((await sut.clearExpiry()).isFailure, isTrue);
    });

    test('wraps a throwing delete', () async {
      storage.throwDeletes.add(_expiry);
      final error = tokenError(await sut.clearExpiry());
      expect(error.message, 'Clearing the expiry failed');
    });
  });

  group('isTokenExpired', () {
    test('is true without a stored expiry', () async {
      expect(await sut.isTokenExpired(), isTrue);
    });

    test('is true for a corrupt expiry', () async {
      storage.data[_expiry] = 'garbage';
      expect(await sut.isTokenExpired(), isTrue);
    });

    test('is true when the expiry cannot be read', () async {
      await sut.setExpiry(start.add(const Duration(hours: 1)));
      storage.failReads.add(_expiry);
      expect(await sut.isTokenExpired(), isTrue);
      storage.failReads.clear();
      storage.throwReads.add(_expiry);
      expect(await sut.isTokenExpired(), isTrue);
    });

    test('is false before the expiry', () async {
      await sut.setExpiry(start.add(const Duration(milliseconds: 1)));
      expect(await sut.isTokenExpired(), isFalse);
    });

    test('is true exactly at the expiry', () async {
      await sut.setExpiry(start);
      expect(await sut.isTokenExpired(), isTrue);
    });

    test('is true after the expiry', () async {
      await sut.setExpiry(start.add(const Duration(minutes: 1)));
      clock = start.add(const Duration(minutes: 2));
      expect(await sut.isTokenExpired(), isTrue);
    });

    test('ignores the refresh buffer', () async {
      await sut.setExpiry(start.add(const Duration(seconds: 30)));
      expect(await sut.isTokenExpired(), isFalse);
      expect(await sut.shouldRefreshToken(), isTrue);
    });

    test('works with a local-time clock', () async {
      final manager = TokenExpiryManager(
        storage: storage,
        tokenStorage: tokens,
        now: () => start.toLocal(),
      );
      await manager.setExpiry(start.add(const Duration(minutes: 5)));
      expect(await manager.isTokenExpired(), isFalse);
    });
  });

  group('shouldRefreshToken', () {
    test('is true without a stored expiry', () async {
      expect(await sut.shouldRefreshToken(), isTrue);
    });

    test('is false outside the default buffer', () async {
      await sut.setExpiry(start.add(const Duration(seconds: 61)));
      expect(await sut.shouldRefreshToken(), isFalse);
    });

    test('is true exactly at the buffer boundary', () async {
      await sut.setExpiry(start.add(const Duration(seconds: 60)));
      expect(await sut.shouldRefreshToken(), isTrue);
    });

    test('honours a custom buffer', () async {
      await sut.setExpiry(start.add(const Duration(minutes: 5)));
      expect(
        await sut.shouldRefreshToken(buffer: const Duration(minutes: 10)),
        isTrue,
      );
      expect(
        await sut.shouldRefreshToken(buffer: const Duration(minutes: 1)),
        isFalse,
      );
    });

    test('clamps a negative buffer to zero', () async {
      await sut.setExpiry(start.add(const Duration(seconds: 1)));
      expect(
        await sut.shouldRefreshToken(buffer: const Duration(hours: -1)),
        isFalse,
      );
      await sut.setExpiry(start);
      expect(
        await sut.shouldRefreshToken(buffer: const Duration(hours: -1)),
        isTrue,
      );
    });
  });

  group('refreshIfNeeded', () {
    late int calls;
    late List<String?> received;

    Future<RefreshedTokens> refresher(String? refreshToken) async {
      calls++;
      received.add(refreshToken);
      return RefreshedTokens(
        accessToken: 'new-access-$calls',
        refreshToken: 'new-refresh-$calls',
        expiresAt: clock.add(const Duration(hours: 1)),
      );
    }

    setUp(() {
      calls = 0;
      received = [];
    });

    Future<void> seed({Duration validFor = const Duration(hours: 1)}) async {
      await tokens.saveTokens(accessToken: 'old-access', refreshToken: 'old-r');
      await sut.setExpiry(clock.add(validFor));
    }

    test('returns the current token without refreshing when valid', () async {
      await seed();
      final result = await sut.refreshIfNeeded(refresher);
      expect(result.dataOrNull, 'old-access');
      expect(calls, 0);
    });

    test('refreshes an expired token and persists everything', () async {
      await seed(validFor: const Duration(seconds: -1));
      final result = await sut.refreshIfNeeded(refresher);
      expect(result.dataOrNull, 'new-access-1');
      expect(received, ['old-r']);
      expect(storage.data[_access], 'new-access-1');
      expect(storage.data[_refresh], 'new-refresh-1');
      expect(
        (await sut.getExpiry()).dataOrNull,
        start.add(const Duration(hours: 1)),
      );
      expect(sut.isRefreshing, isFalse);
    });

    test('refreshes inside the buffer window', () async {
      await seed(validFor: const Duration(seconds: 30));
      expect((await sut.refreshIfNeeded(refresher)).dataOrNull, 'new-access-1');
    });

    test('honours a per-call buffer', () async {
      await seed(validFor: const Duration(minutes: 5));
      await sut.refreshIfNeeded(refresher);
      expect(calls, 0);
      await sut.refreshIfNeeded(refresher, buffer: const Duration(minutes: 6));
      expect(calls, 1);
    });

    test('refreshes when no expiry is stored', () async {
      await tokens.saveTokens(accessToken: 'old-access', refreshToken: 'old-r');
      await sut.refreshIfNeeded(refresher);
      expect(calls, 1);
    });

    test('refreshes when the expiry is corrupt', () async {
      await seed();
      storage.data[_expiry] = 'not-a-number';
      await sut.refreshIfNeeded(refresher);
      expect(calls, 1);
    });

    test('refreshes when valid but the access token is missing', () async {
      await seed();
      storage.data.remove(_access);
      final result = await sut.refreshIfNeeded(refresher);
      expect(result.dataOrNull, 'new-access-1');
      expect(calls, 1);
    });

    test('force refreshes a still-valid token', () async {
      await seed();
      final result = await sut.refreshIfNeeded(refresher, force: true);
      expect(result.dataOrNull, 'new-access-1');
      expect(calls, 1);
    });

    test('fails without a refresh token and does not call refresher', () async {
      await tokens.saveAccessToken('old-access');
      final error = tokenError(await sut.refreshIfNeeded(refresher));
      expect(error.code, TokenException.noRefreshToken);
      expect(calls, 0);
      expect(storage.data[_access], 'old-access');
    });

    test('passes null to the refresher when a refresh token is optional',
        () async {
      final result = await sut.refreshIfNeeded(
        refresher,
        requireRefreshToken: false,
      );
      expect(result.isSuccess, isTrue);
      expect(received, [null]);
    });

    test('returns the storage failure when the refresh token is unreadable',
        () async {
      await seed(validFor: const Duration(seconds: -1));
      storage.failReads.add(_refresh);
      final result = await sut.refreshIfNeeded(refresher);
      expect(result.isFailure, isTrue);
      expect((result as Failure).error, isA<SecureStorageException>());
      expect(calls, 0);
    });

    test('a throwing refresher fails and leaves stored tokens alone', () async {
      await seed(validFor: const Duration(seconds: -1));
      final before = Map.of(storage.data);
      final error = tokenError(
        await sut.refreshIfNeeded((_) async => throw const FormatException('x')),
      );
      expect(error.code, TokenException.refreshFailed);
      expect(error.originalError, isA<FormatException>());
      expect(storage.data, before);
      expect(sut.isRefreshing, isFalse);
    });

    test('a synchronously throwing refresher is handled too', () async {
      await seed(validFor: const Duration(seconds: -1));
      final error = tokenError(
        await sut.refreshIfNeeded((_) => throw StateError('offline')),
      );
      expect(error.code, TokenException.refreshFailed);
    });

    test('can retry after a failed refresh', () async {
      await seed(validFor: const Duration(seconds: -1));
      final failed = await sut.refreshIfNeeded(
        (_) async => throw StateError('offline'),
      );
      expect(failed.isFailure, isTrue);
      final retried = await sut.refreshIfNeeded(refresher);
      expect(retried.dataOrNull, 'new-access-1');
    });

    test('rejects an empty or blank access token', () async {
      await seed(validFor: const Duration(seconds: -1));
      for (final bad in ['', '   ']) {
        final error = tokenError(
          await sut.refreshIfNeeded(
            (_) async => RefreshedTokens(accessToken: bad, expiresAt: clock),
          ),
        );
        expect(error.code, TokenException.refreshFailed);
        expect(error.message, 'Refresh returned an empty access token');
      }
      expect(storage.data[_access], 'old-access');
    });

    test('keeps the stored refresh token when none is rotated', () async {
      await seed(validFor: const Duration(seconds: -1));
      for (final rotated in [null, '', '  ']) {
        final result = await sut.refreshIfNeeded(
          (_) async => RefreshedTokens(
            accessToken: 'fresh',
            refreshToken: rotated,
            expiresAt: clock.add(const Duration(hours: 1)),
          ),
          force: true,
        );
        expect(result.dataOrNull, 'fresh');
        expect(storage.data[_refresh], 'old-r');
      }
    });

    test('returns the failure when saving the new token fails', () async {
      await seed(validFor: const Duration(seconds: -1));
      storage.failWrites.add(_access);
      final result = await sut.refreshIfNeeded(refresher);
      expect(result.isFailure, isTrue);
      expect(calls, 1);
    });

    test('returns the failure when saving the new expiry fails', () async {
      await seed(validFor: const Duration(seconds: -1));
      storage.failWrites.add(_expiry);
      final result = await sut.refreshIfNeeded(refresher);
      expect(result.isFailure, isTrue);
      // The expiry stays in the past, so the next call refreshes again.
      storage.failWrites.clear();
      expect((await sut.refreshIfNeeded(refresher)).isSuccess, isTrue);
      expect(calls, 2);
    });

    test('never throws when storage throws', () async {
      await seed(validFor: const Duration(seconds: -1));
      storage.throwWrites.add(_expiry);
      final result = await sut.refreshIfNeeded(refresher);
      expect(result.isFailure, isTrue);
    });

    test('concurrent calls share a single refresh', () async {
      await seed(validFor: const Duration(seconds: -1));
      final gate = Completer<RefreshedTokens>();
      Future<RefreshedTokens> slow(String? _) {
        calls++;
        return gate.future;
      }

      final first = sut.refreshIfNeeded(slow);
      final second = sut.refreshIfNeeded(slow);
      final third = sut.refreshIfNeeded(refresher, force: true);
      expect(identical(first, second), isTrue);
      expect(identical(first, third), isTrue);
      expect(sut.isRefreshing, isTrue);

      await pumpEventQueue();
      expect(calls, 1);
      gate.complete(
        RefreshedTokens(
          accessToken: 'shared',
          expiresAt: clock.add(const Duration(hours: 1)),
        ),
      );
      final results = await Future.wait([first, second, third]);
      expect(results.map((r) => r.dataOrNull), everyElement('shared'));
      expect(calls, 1);
      expect(sut.isRefreshing, isFalse);
    });

    test('concurrent callers all see the same failure', () async {
      await seed(validFor: const Duration(seconds: -1));
      final gate = Completer<RefreshedTokens>();
      final first = sut.refreshIfNeeded((_) => gate.future);
      final second = sut.refreshIfNeeded((_) => gate.future);
      await pumpEventQueue();
      gate.completeError(StateError('500'));
      final results = await Future.wait([first, second]);
      expect(results.every((r) => r.isFailure), isTrue);
      expect(sut.isRefreshing, isFalse);
    });

    test('a new refresh can start once the previous one finished', () async {
      await seed(validFor: const Duration(seconds: -1));
      await sut.refreshIfNeeded(refresher);
      clock = clock.add(const Duration(hours: 2));
      final again = await sut.refreshIfNeeded(refresher);
      expect(again.dataOrNull, 'new-access-2');
      expect(received, ['old-r', 'new-refresh-1']);
    });
  });
}
