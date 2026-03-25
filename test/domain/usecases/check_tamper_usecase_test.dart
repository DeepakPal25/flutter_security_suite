import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/repositories/tamper_detection_repository.dart';
import 'package:flutter_security_suite/domain/usecases/check_tamper_usecase.dart';

class MockTamperDetectionRepository extends Mock
    implements TamperDetectionRepository {}

void main() {
  late MockTamperDetectionRepository mockRepo;
  late CheckTamperUseCase sut;

  setUp(() {
    mockRepo = MockTamperDetectionRepository();
    sut = CheckTamperUseCase(mockRepo);
  });

  group('isTampered', () {
    test('returns Success(true) when app is tampered', () async {
      when(() => mockRepo.isTampered())
          .thenAnswer((_) async => const Success(true));

      final result = await sut();

      expect(result.dataOrNull, isTrue);
    });

    test('returns Success(false) when app is not tampered', () async {
      when(() => mockRepo.isTampered())
          .thenAnswer((_) async => const Success(false));

      final result = await sut();

      expect(result.dataOrNull, isFalse);
    });

    test('returns Failure on repository error', () async {
      when(() => mockRepo.isTampered()).thenAnswer(
        (_) async => const Failure(
          PlatformSecurityException(
            platform: 'native',
            message: 'tamper check failed',
          ),
        ),
      );

      final result = await sut();

      expect(result, isA<Failure<bool>>());
    });
  });

  group('getSignatureHash', () {
    test('returns Success with hash string', () async {
      when(() => mockRepo.getSignatureHash())
          .thenAnswer((_) async => const Success('abc123'));

      final result = await sut.getSignatureHash();

      expect(result.dataOrNull, 'abc123');
    });

    test('returns Success(null) when hash is unavailable', () async {
      when(() => mockRepo.getSignatureHash())
          .thenAnswer((_) async => const Success(null));

      final result = await sut.getSignatureHash();

      expect(result.dataOrNull, isNull);
    });
  });
}
