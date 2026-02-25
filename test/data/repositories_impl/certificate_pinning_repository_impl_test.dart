import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/certificate_pinning_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/certificate_pinning_repository_impl.dart';

class MockCertificatePinningDatasource extends Mock
    implements CertificatePinningDatasource {}

void main() {
  late MockCertificatePinningDatasource mockDs;
  late CertificatePinningRepositoryImpl sut;

  setUp(() {
    mockDs = MockCertificatePinningDatasource();
    sut = CertificatePinningRepositoryImpl(mockDs);
  });

  const host = 'api.bank.com';
  const pins = ['sha256/AAAA'];

  test('returns Success(true) when datasource validates', () async {
    when(() => mockDs.validateCertificate(host: host, pins: pins))
        .thenAnswer((_) async => true);

    final result = await sut.validateCertificate(host: host, pins: pins);

    expect(result, isA<Success<bool>>());
    expect(result.dataOrNull, isTrue);
  });

  test('returns Success(false) when pin mismatch', () async {
    when(() => mockDs.validateCertificate(host: host, pins: pins))
        .thenAnswer((_) async => false);

    final result = await sut.validateCertificate(host: host, pins: pins);

    expect(result.dataOrNull, isFalse);
  });

  test('returns Failure when datasource throws', () async {
    when(() => mockDs.validateCertificate(host: host, pins: pins))
        .thenThrow(Exception('network error'));

    final result = await sut.validateCertificate(host: host, pins: pins);

    expect(result, isA<Failure<bool>>());
  });
}
