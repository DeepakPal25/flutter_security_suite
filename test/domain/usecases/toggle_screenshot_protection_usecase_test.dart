import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/repositories/screenshot_protection_repository.dart';
import 'package:flutter_security_suite/domain/usecases/toggle_screenshot_protection_usecase.dart';

class MockScreenshotProtectionRepository extends Mock
    implements ScreenshotProtectionRepository {}

void main() {
  late MockScreenshotProtectionRepository mockRepo;
  late ToggleScreenshotProtectionUseCase sut;

  setUp(() {
    mockRepo = MockScreenshotProtectionRepository();
    sut = ToggleScreenshotProtectionUseCase(mockRepo);
  });

  test('calls enableProtection when enable=true', () async {
    when(() => mockRepo.enableProtection())
        .thenAnswer((_) async => const Success(null));

    final result = await sut(enable: true);

    expect(result, isA<Success<void>>());
    verify(() => mockRepo.enableProtection()).called(1);
    verifyNever(() => mockRepo.disableProtection());
  });

  test('calls disableProtection when enable=false', () async {
    when(() => mockRepo.disableProtection())
        .thenAnswer((_) async => const Success(null));

    final result = await sut(enable: false);

    expect(result, isA<Success<void>>());
    verify(() => mockRepo.disableProtection()).called(1);
    verifyNever(() => mockRepo.enableProtection());
  });

  test('returns Failure on platform error', () async {
    when(() => mockRepo.enableProtection()).thenAnswer((_) async => Failure(
          PlatformSecurityException(
            platform: 'native',
            message: 'no activity',
          ),
        ));

    final result = await sut(enable: true);

    expect(result, isA<Failure<void>>());
  });
}
