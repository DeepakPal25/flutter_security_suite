import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/domain/repositories/certificate_pinning_repository.dart';
import 'package:flutter_security_suite/domain/usecases/validate_certificate_usecase.dart';

class MockCertificatePinningRepository extends Mock
    implements CertificatePinningRepository {}

void main() {
  late MockCertificatePinningRepository mockRepo;
  late ValidateCertificateUseCase sut;

  setUp(() {
    mockRepo = MockCertificatePinningRepository();
    sut = ValidateCertificateUseCase(mockRepo);
  });

  const host = 'api.bank.com';
  const pins = ['sha256/AAAA'];

  test('returns Success(true) when certificate is valid', () async {
    when(
      () => mockRepo.validateCertificate(host: host, pins: pins),
    ).thenAnswer((_) async => const Success(true));

    final result = await sut(host: host, pins: pins);

    expect(result, isA<Success<bool>>());
    expect(result.dataOrNull, isTrue);
    verify(
      () => mockRepo.validateCertificate(host: host, pins: pins),
    ).called(1);
  });

  test('returns Failure when validation fails', () async {
    when(() => mockRepo.validateCertificate(host: host, pins: pins)).thenAnswer(
      (_) async => Failure(
        CertificatePinningException(host: host, message: 'connection failed'),
      ),
    );

    final result = await sut(host: host, pins: pins);

    expect(result, isA<Failure<bool>>());
  });
}
