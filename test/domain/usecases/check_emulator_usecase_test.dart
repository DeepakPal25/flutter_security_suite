import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/repositories/emulator_detection_repository.dart';
import 'package:flutter_security_suite/domain/usecases/check_emulator_usecase.dart';

class MockEmulatorDetectionRepository extends Mock
    implements EmulatorDetectionRepository {}

void main() {
  late MockEmulatorDetectionRepository mockRepo;
  late CheckEmulatorUseCase sut;

  setUp(() {
    mockRepo = MockEmulatorDetectionRepository();
    sut = CheckEmulatorUseCase(mockRepo);
  });

  test('returns Success(true) when device is emulator', () async {
    when(() => mockRepo.isEmulator())
        .thenAnswer((_) async => const Success(true));

    final result = await sut();

    expect(result.dataOrNull, isTrue);
  });

  test('returns Success(false) when device is real', () async {
    when(() => mockRepo.isEmulator())
        .thenAnswer((_) async => const Success(false));

    final result = await sut();

    expect(result.dataOrNull, isFalse);
  });

  test('returns Failure on repository error', () async {
    when(() => mockRepo.isEmulator()).thenAnswer(
      (_) async => Failure(
        const PlatformSecurityException(
          platform: 'native',
          message: 'emulator check failed',
        ),
      ),
    );

    final result = await sut();

    expect(result, isA<Failure<bool>>());
  });
}
