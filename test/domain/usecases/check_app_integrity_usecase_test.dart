import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/repositories/app_integrity_repository.dart';
import 'package:flutter_security_suite/domain/usecases/check_app_integrity_usecase.dart';

class MockAppIntegrityRepository extends Mock
    implements AppIntegrityRepository {}

void main() {
  late MockAppIntegrityRepository mockRepo;
  late CheckAppIntegrityUseCase sut;

  setUp(() {
    mockRepo = MockAppIntegrityRepository();
    sut = CheckAppIntegrityUseCase(mockRepo);
  });

  test('returns Success(true) when app integrity is valid', () async {
    when(
      () => mockRepo.isAppIntegrityValid(),
    ).thenAnswer((_) async => const Success(true));

    final result = await sut();

    expect(result, isA<Success<bool>>());
    expect(result.dataOrNull, isTrue);
    verify(() => mockRepo.isAppIntegrityValid()).called(1);
  });

  test('returns Success(false) when app is tampered', () async {
    when(
      () => mockRepo.isAppIntegrityValid(),
    ).thenAnswer((_) async => const Success(false));

    final result = await sut();

    expect(result.dataOrNull, isFalse);
  });

  test('returns Failure on platform error', () async {
    when(() => mockRepo.isAppIntegrityValid()).thenAnswer(
      (_) async => Failure(
        PlatformSecurityException(platform: 'native', message: 'check failed'),
      ),
    );

    final result = await sut();

    expect(result, isA<Failure<bool>>());
  });
}
