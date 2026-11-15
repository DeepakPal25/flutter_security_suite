import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/biometric_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/biometric_repository_impl.dart';
import 'package:flutter_security_suite/domain/entities/biometric_availability.dart';

class MockBiometricDatasource extends Mock implements BiometricDatasource {}

void main() {
  late MockBiometricDatasource ds;
  late BiometricRepositoryImpl sut;

  setUp(() {
    ds = MockBiometricDatasource();
    sut = BiometricRepositoryImpl(ds);
  });

  void stubAuth(Future<bool> Function() answer) {
    when(
      () => ds.authenticate(
        reason: any(named: 'reason'),
        allowDeviceCredential: any(named: 'allowDeviceCredential'),
        cancelLabel: any(named: 'cancelLabel'),
      ),
    ).thenAnswer((_) => answer());
  }

  BiometricException failureOf(SecurityResult<Object?> result) {
    expect(result.isFailure, isTrue);
    final error = (result as Failure).error;
    expect(error, isA<BiometricException>());
    return error as BiometricException;
  }

  group('checkAvailability', () {
    test('parses the native reply', () async {
      when(() => ds.availability()).thenAnswer(
        (_) async => {'available': true, 'type': 'fingerprint'},
      );
      expect(
        (await sut.checkAvailability()).dataOrNull,
        const BiometricAvailability(
          isAvailable: true,
          type: BiometricType.fingerprint,
        ),
      );
    });

    test('reports not enrolled', () async {
      when(() => ds.availability()).thenAnswer(
        (_) async => {
          'available': false,
          'type': 'none',
          'reason': BiometricException.notEnrolled,
        },
      );
      final data = (await sut.checkAvailability()).dataOrNull!;
      expect(data.isAvailable, isFalse);
      expect(data.reason, BiometricException.notEnrolled);
    });

    test('an empty reply is "unavailable", not a failure', () async {
      when(() => ds.availability()).thenAnswer((_) async => {});
      expect(
        (await sut.checkAvailability()).dataOrNull,
        BiometricAvailability.unavailable,
      );
    });

    test('maps a missing plugin to notAvailable', () async {
      when(() => ds.availability()).thenThrow(MissingPluginException());
      final error = failureOf(await sut.checkAvailability());
      expect(error.code, BiometricException.notAvailable);
      expect(error.originalError, isA<MissingPluginException>());
    });

    test('maps an unexpected error to the generic code', () async {
      when(() => ds.availability()).thenThrow(StateError('boom'));
      final error = failureOf(await sut.checkAvailability());
      expect(error.code, BiometricException.failed);
      expect(error.message, contains('boom'));
    });
  });

  group('authenticate', () {
    test('returns true when the user authenticates', () async {
      stubAuth(() async => true);
      final result = await sut.authenticate(reason: 'Confirm payment');
      expect(result.dataOrNull, isTrue);
      verify(
        () => ds.authenticate(
          reason: 'Confirm payment',
          allowDeviceCredential: true,
          cancelLabel: null,
        ),
      ).called(1);
    });

    test('returns Success(false) when the user cancels', () async {
      stubAuth(() async => false);
      final result = await sut.authenticate(reason: 'Confirm payment');
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isFalse);
    });

    test('forwards allowDeviceCredential and a trimmed cancel label',
        () async {
      stubAuth(() async => true);
      await sut.authenticate(
        reason: '  Unlock  ',
        allowDeviceCredential: false,
        cancelLabel: '  Not now ',
      );
      verify(
        () => ds.authenticate(
          reason: 'Unlock',
          allowDeviceCredential: false,
          cancelLabel: 'Not now',
        ),
      ).called(1);
    });

    test('treats a blank cancel label as absent', () async {
      stubAuth(() async => true);
      await sut.authenticate(reason: 'Unlock', cancelLabel: '   ');
      verify(
        () => ds.authenticate(
          reason: 'Unlock',
          allowDeviceCredential: true,
          cancelLabel: null,
        ),
      ).called(1);
    });

    test('rejects an empty or blank reason without prompting', () async {
      for (final reason in ['', '   ', '\n\t']) {
        final error = failureOf(await sut.authenticate(reason: reason));
        expect(error.code, BiometricException.invalidArguments);
      }
      verifyNever(
        () => ds.authenticate(
          reason: any(named: 'reason'),
          allowDeviceCredential: any(named: 'allowDeviceCredential'),
          cancelLabel: any(named: 'cancelLabel'),
        ),
      );
    });

    test('passes known native codes through', () async {
      for (final code in [
        BiometricException.notAvailable,
        BiometricException.notEnrolled,
        BiometricException.lockedOut,
        BiometricException.passcodeNotSet,
        BiometricException.noActivity,
        BiometricException.inProgress,
        BiometricException.invalidArguments,
        BiometricException.failed,
      ]) {
        stubAuth(() => Future.error(PlatformException(code: code, message: 'm')));
        final error = failureOf(await sut.authenticate(reason: 'Unlock'));
        expect(error.code, code);
        expect(error.message, 'm');
        expect(error.originalError, isA<PlatformException>());
      }
    });

    test('maps generic plugin codes', () async {
      stubAuth(() => Future.error(PlatformException(code: 'NO_ACTIVITY')));
      expect(
        failureOf(await sut.authenticate(reason: 'Unlock')).code,
        BiometricException.noActivity,
      );

      stubAuth(() => Future.error(PlatformException(code: 'INVALID_ARGS')));
      expect(
        failureOf(await sut.authenticate(reason: 'Unlock')).code,
        BiometricException.invalidArguments,
      );
    });

    test('maps unknown codes to the generic failure with a default message',
        () async {
      stubAuth(() => Future.error(PlatformException(code: 'WHATEVER')));
      final error = failureOf(await sut.authenticate(reason: 'Unlock'));
      expect(error.code, BiometricException.failed);
      expect(error.message, 'Biometric authentication failed');
    });

    test('maps a missing plugin to notAvailable', () async {
      stubAuth(() => Future.error(MissingPluginException()));
      expect(
        failureOf(await sut.authenticate(reason: 'Unlock')).code,
        BiometricException.notAvailable,
      );
    });

    test('maps a synchronous throw', () async {
      when(
        () => ds.authenticate(
          reason: any(named: 'reason'),
          allowDeviceCredential: any(named: 'allowDeviceCredential'),
          cancelLabel: any(named: 'cancelLabel'),
        ),
      ).thenThrow(ArgumentError('bad'));
      final error = failureOf(await sut.authenticate(reason: 'Unlock'));
      expect(error.code, BiometricException.failed);
      expect(error.originalError, isA<ArgumentError>());
    });

    test('can succeed after a failed attempt', () async {
      stubAuth(
        () => Future.error(
          PlatformException(code: BiometricException.lockedOut),
        ),
      );
      expect((await sut.authenticate(reason: 'Unlock')).isFailure, isTrue);
      stubAuth(() async => true);
      expect((await sut.authenticate(reason: 'Unlock')).dataOrNull, isTrue);
    });
  });
}
