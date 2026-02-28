import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/repositories/root_detection_repository.dart';
import 'package:flutter_security_suite/domain/usecases/check_root_status_usecase.dart';

class MockRootDetectionRepository extends Mock
    implements RootDetectionRepository {}

void main() {
  late MockRootDetectionRepository mockRepo;
  late CheckRootStatusUseCase sut;

  setUp(() {
    mockRepo = MockRootDetectionRepository();
    sut = CheckRootStatusUseCase(mockRepo);
  });

  test('returns Success(true) when device is rooted', () async {
    when(
      () => mockRepo.isDeviceRooted(),
    ).thenAnswer((_) async => const Success(true));

    final result = await sut();

    expect(result, isA<Success<bool>>());
    expect(result.dataOrNull, isTrue);
    verify(() => mockRepo.isDeviceRooted()).called(1);
  });

  test('returns Success(false) when device is not rooted', () async {
    when(
      () => mockRepo.isDeviceRooted(),
    ).thenAnswer((_) async => const Success(false));

    final result = await sut();

    expect(result.dataOrNull, isFalse);
  });

  test('returns Failure on platform error', () async {
    when(() => mockRepo.isDeviceRooted()).thenAnswer(
      (_) async => Failure(
        PlatformSecurityException(platform: 'native', message: 'failed'),
      ),
    );

    final result = await sut();

    expect(result, isA<Failure<bool>>());
    verify(() => mockRepo.isDeviceRooted()).called(1);
  });
}
