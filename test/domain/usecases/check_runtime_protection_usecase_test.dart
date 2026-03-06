import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/repositories/runtime_protection_repository.dart';
import 'package:flutter_security_suite/domain/usecases/check_runtime_protection_usecase.dart';

class MockRuntimeProtectionRepository extends Mock
    implements RuntimeProtectionRepository {}

void main() {
  late MockRuntimeProtectionRepository mockRepo;
  late CheckRuntimeProtectionUseCase sut;

  setUp(() {
    mockRepo = MockRuntimeProtectionRepository();
    sut = CheckRuntimeProtectionUseCase(mockRepo);
  });

  test('returns Success(true) when runtime hooking is detected', () async {
    when(() => mockRepo.isRuntimeHooked())
        .thenAnswer((_) async => const Success(true));

    final result = await sut();

    expect(result.dataOrNull, isTrue);
  });

  test('returns Success(false) when no hooking is detected', () async {
    when(() => mockRepo.isRuntimeHooked())
        .thenAnswer((_) async => const Success(false));

    final result = await sut();

    expect(result.dataOrNull, isFalse);
  });

  test('returns Failure on repository error', () async {
    when(() => mockRepo.isRuntimeHooked()).thenAnswer(
      (_) async => Failure(
        const PlatformSecurityException(
          platform: 'native',
          message: 'runtime protection check failed',
        ),
      ),
    );

    final result = await sut();

    expect(result, isA<Failure<bool>>());
  });
}

