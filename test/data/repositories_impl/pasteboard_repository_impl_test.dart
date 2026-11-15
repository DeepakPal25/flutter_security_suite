import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/pasteboard_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/pasteboard_repository_impl.dart';

class MockPasteboardDatasource extends Mock implements PasteboardDatasource {}

void main() {
  late MockPasteboardDatasource ds;
  late PasteboardRepositoryImpl sut;

  setUp(() {
    ds = MockPasteboardDatasource();
    sut = PasteboardRepositoryImpl(ds);
    when(
      () => ds.copy(
        value: any(named: 'value'),
        expiresAfterMs: any(named: 'expiresAfterMs'),
      ),
    ).thenAnswer((_) async {});
  });

  void verifyNoCopy() => verifyNever(
    () => ds.copy(
      value: any(named: 'value'),
      expiresAfterMs: any(named: 'expiresAfterMs'),
    ),
  );

  group('copy', () {
    test('forwards the value and the expiry in milliseconds', () async {
      final result = await sut.copy(
        value: '4111 1111 1111 1111',
        expiresAfter: const Duration(seconds: 30),
      );
      expect(result.isSuccess, isTrue);
      verify(
        () => ds.copy(value: '4111 1111 1111 1111', expiresAfterMs: 30000),
      ).called(1);
    });

    test('keeps whitespace and unicode intact', () async {
      const value = '  pä55 wörd 🔐\n';
      await sut.copy(value: value, expiresAfter: const Duration(seconds: 1));
      verify(() => ds.copy(value: value, expiresAfterMs: 1000)).called(1);
    });

    test('rejects an empty value', () async {
      final result = await sut.copy(
        value: '',
        expiresAfter: const Duration(seconds: 30),
      );
      final error = (result as Failure).error;
      expect(error, isA<InvalidArgumentSecurityException>());
      expect(error.code, 'INVALID_ARGUMENT');
      verifyNoCopy();
    });

    test('rejects a zero or negative expiry', () async {
      for (final expiry in [Duration.zero, const Duration(seconds: -5)]) {
        final result = await sut.copy(value: 'otp', expiresAfter: expiry);
        expect(
          (result as Failure).error,
          isA<InvalidArgumentSecurityException>(),
        );
      }
      verifyNoCopy();
    });

    test('accepts exactly one hour and rejects anything longer', () async {
      expect(
        (await sut.copy(value: 'otp', expiresAfter: const Duration(hours: 1)))
            .isSuccess,
        isTrue,
      );
      verify(() => ds.copy(value: 'otp', expiresAfterMs: 3600000)).called(1);

      final result = await sut.copy(
        value: 'otp',
        expiresAfter: const Duration(hours: 1, milliseconds: 1),
      );
      expect(
        (result as Failure).error,
        isA<InvalidArgumentSecurityException>(),
      );
      verifyNoCopy();
    });

    test('rounds a sub-millisecond expiry up to 1 ms', () async {
      await sut.copy(
        value: 'otp',
        expiresAfter: const Duration(microseconds: 10),
      );
      verify(() => ds.copy(value: 'otp', expiresAfterMs: 1)).called(1);
    });

    test('wraps a platform error and does not leak the value', () async {
      when(
        () => ds.copy(
          value: any(named: 'value'),
          expiresAfterMs: any(named: 'expiresAfterMs'),
        ),
      ).thenThrow(PlatformException(code: 'PASTEBOARD_ERROR', message: 'no'));

      final result = await sut.copy(
        value: 'super-secret-otp',
        expiresAfter: const Duration(seconds: 30),
      );

      final error = (result as Failure).error;
      expect(error, isA<PlatformSecurityException>());
      expect(error.message, startsWith('Pasteboard copy failed'));
      expect(error.message, isNot(contains('super-secret-otp')));
    });

    test('wraps a missing plugin', () async {
      when(
        () => ds.copy(
          value: any(named: 'value'),
          expiresAfterMs: any(named: 'expiresAfterMs'),
        ),
      ).thenAnswer((_) => Future.error(MissingPluginException()));
      final result = await sut.copy(
        value: 'otp',
        expiresAfter: const Duration(seconds: 30),
      );
      expect((result as Failure).error, isA<PlatformSecurityException>());
    });
  });

  group('clear', () {
    test('defaults to an unconditional clear', () async {
      when(() => ds.clear(onlyIfOwned: false)).thenAnswer((_) async => true);
      expect((await sut.clear()).dataOrNull, isTrue);
      verify(() => ds.clear(onlyIfOwned: false)).called(1);
    });

    test('forwards onlyIfOwned and reports "nothing cleared"', () async {
      when(() => ds.clear(onlyIfOwned: true)).thenAnswer((_) async => false);
      final result = await sut.clear(onlyIfOwned: true);
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isFalse);
    });

    test('wraps an error', () async {
      when(() => ds.clear(onlyIfOwned: any(named: 'onlyIfOwned')))
          .thenThrow(PlatformException(code: 'ERR'));
      final error = ((await sut.clear()) as Failure).error;
      expect(error, isA<PlatformSecurityException>());
      expect(error.message, startsWith('Pasteboard clear failed'));
    });
  });
}
