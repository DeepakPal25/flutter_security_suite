import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/repositories/screen_recording_repository.dart';
import 'package:flutter_security_suite/domain/usecases/check_screen_recording_usecase.dart';

class MockScreenRecordingRepository extends Mock
    implements ScreenRecordingRepository {}

void main() {
  late MockScreenRecordingRepository mockRepo;
  late CheckScreenRecordingUseCase sut;

  setUp(() {
    mockRepo = MockScreenRecordingRepository();
    sut = CheckScreenRecordingUseCase(mockRepo);
  });

  test('returns Success(true) when screen is being recorded', () async {
    when(() => mockRepo.isScreenBeingRecorded())
        .thenAnswer((_) async => const Success(true));

    final result = await sut();

    expect(result.dataOrNull, isTrue);
  });

  test('returns Success(false) when screen is not being recorded', () async {
    when(() => mockRepo.isScreenBeingRecorded())
        .thenAnswer((_) async => const Success(false));

    final result = await sut();

    expect(result.dataOrNull, isFalse);
  });

  test('returns Failure on repository error', () async {
    when(() => mockRepo.isScreenBeingRecorded()).thenAnswer(
      (_) async => const Failure(
        PlatformSecurityException(
          platform: 'native',
          message: 'recording check failed',
        ),
      ),
    );

    final result = await sut();

    expect(result, isA<Failure<bool>>());
  });
}
