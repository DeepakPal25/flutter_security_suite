import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/anti_tamper_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/anti_tamper_repository_impl.dart';
import 'package:flutter_security_suite/domain/entities/anti_tamper_status.dart';

class MockAntiTamperDatasource extends Mock implements AntiTamperDatasource {}

void main() {
  late MockAntiTamperDatasource ds;
  late AntiTamperRepositoryImpl sut;

  setUp(() {
    ds = MockAntiTamperDatasource();
    sut = AntiTamperRepositoryImpl(ds);
  });

  void expectPlatformFailure(SecurityResult<Object?> result, String prefix) {
    expect(result.isFailure, isTrue);
    final error = (result as Failure).error;
    expect(error, isA<PlatformSecurityException>());
    expect(error.message, startsWith(prefix));
    expect(error.originalError, isNotNull);
  }

  group('isDebuggerAttached', () {
    test('returns the native value', () async {
      when(() => ds.isDebuggerAttached()).thenAnswer((_) async => true);
      expect((await sut.isDebuggerAttached()).dataOrNull, isTrue);

      when(() => ds.isDebuggerAttached()).thenAnswer((_) async => false);
      expect((await sut.isDebuggerAttached()).dataOrNull, isFalse);
    });

    test('wraps a platform error', () async {
      when(() => ds.isDebuggerAttached())
          .thenThrow(PlatformException(code: 'ERR'));
      expectPlatformFailure(
        await sut.isDebuggerAttached(),
        'Debugger detection failed',
      );
      verify(() => ds.isDebuggerAttached()).called(1);
    });

    test('wraps an asynchronous error', () async {
      when(() => ds.isDebuggerAttached())
          .thenAnswer((_) => Future.error(StateError('boom')));
      expectPlatformFailure(
        await sut.isDebuggerAttached(),
        'Debugger detection failed',
      );
    });
  });

  group('hasInjectedLibraries', () {
    test('returns the native value', () async {
      when(() => ds.hasInjectedLibraries()).thenAnswer((_) async => true);
      expect((await sut.hasInjectedLibraries()).dataOrNull, isTrue);
    });

    test('wraps a missing plugin', () async {
      when(() => ds.hasInjectedLibraries())
          .thenThrow(MissingPluginException('no impl'));
      expectPlatformFailure(
        await sut.hasInjectedLibraries(),
        'Injected library detection failed',
      );
    });
  });

  group('denyDebuggerAttachment', () {
    test('returns the native value', () async {
      when(() => ds.denyDebuggerAttachment()).thenAnswer((_) async => false);
      expect((await sut.denyDebuggerAttachment()).dataOrNull, isFalse);
    });

    test('wraps an error', () async {
      when(() => ds.denyDebuggerAttachment()).thenThrow(Exception('denied'));
      expectPlatformFailure(
        await sut.denyDebuggerAttachment(),
        'Deny debugger attachment failed',
      );
    });
  });

  group('check', () {
    test('combines both checks', () async {
      when(() => ds.isDebuggerAttached()).thenAnswer((_) async => false);
      when(() => ds.hasInjectedLibraries()).thenAnswer((_) async => true);

      final result = await sut.check();

      expect(
        result.dataOrNull,
        const AntiTamperStatus(
          isDebuggerAttached: false,
          hasInjectedLibraries: true,
        ),
      );
      expect(result.dataOrNull!.isCompromised, isTrue);
    });

    test('reports a clean device', () async {
      when(() => ds.isDebuggerAttached()).thenAnswer((_) async => false);
      when(() => ds.hasInjectedLibraries()).thenAnswer((_) async => false);
      expect((await sut.check()).dataOrNull!.isCompromised, isFalse);
    });

    test('fails when the debugger check fails, without a partial result',
        () async {
      when(() => ds.isDebuggerAttached()).thenThrow(Exception('x'));
      when(() => ds.hasInjectedLibraries()).thenAnswer((_) async => false);

      final result = await sut.check();

      expectPlatformFailure(result, 'Anti-tamper check failed');
      expect(result.dataOrNull, isNull);
      verifyNever(() => ds.hasInjectedLibraries());
    });

    test('fails when the injection check fails', () async {
      when(() => ds.isDebuggerAttached()).thenAnswer((_) async => true);
      when(() => ds.hasInjectedLibraries()).thenThrow(Exception('x'));
      expectPlatformFailure(await sut.check(), 'Anti-tamper check failed');
    });
  });
}
