import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/screenshot_protection_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/screenshot_protection_repository_impl.dart';

class MockScreenshotProtectionDatasource extends Mock
    implements ScreenshotProtectionDatasource {}

void main() {
  late MockScreenshotProtectionDatasource mockDs;
  late ScreenshotProtectionRepositoryImpl sut;

  setUp(() {
    mockDs = MockScreenshotProtectionDatasource();
    sut = ScreenshotProtectionRepositoryImpl(mockDs);
  });

  group('enableProtection', () {
    test('returns Success when datasource succeeds', () async {
      when(() => mockDs.enable()).thenAnswer((_) async {});

      final result = await sut.enableProtection();

      expect(result, isA<Success<void>>());
      verify(() => mockDs.enable()).called(1);
    });

    test('returns Failure when datasource throws', () async {
      when(() => mockDs.enable()).thenThrow(Exception('no activity'));

      final result = await sut.enableProtection();

      expect(result, isA<Failure<void>>());
    });
  });

  group('disableProtection', () {
    test('returns Success when datasource succeeds', () async {
      when(() => mockDs.disable()).thenAnswer((_) async {});

      final result = await sut.disableProtection();

      expect(result, isA<Success<void>>());
      verify(() => mockDs.disable()).called(1);
    });

    test('returns Failure when datasource throws', () async {
      when(() => mockDs.disable()).thenThrow(Exception('error'));

      final result = await sut.disableProtection();

      expect(result, isA<Failure<void>>());
    });
  });
}
