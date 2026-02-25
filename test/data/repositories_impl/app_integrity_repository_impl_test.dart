import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/app_integrity_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/app_integrity_repository_impl.dart';

class MockAppIntegrityDatasource extends Mock
    implements AppIntegrityDatasource {}

void main() {
  late MockAppIntegrityDatasource mockDs;
  late AppIntegrityRepositoryImpl sut;

  setUp(() {
    mockDs = MockAppIntegrityDatasource();
    sut = AppIntegrityRepositoryImpl(mockDs);
  });

  test('returns Success(true) when integrity is valid', () async {
    when(() => mockDs.isAppIntegrityValid()).thenAnswer((_) async => true);

    final result = await sut.isAppIntegrityValid();

    expect(result, isA<Success<bool>>());
    expect(result.dataOrNull, isTrue);
  });

  test('returns Success(false) when integrity is invalid', () async {
    when(() => mockDs.isAppIntegrityValid()).thenAnswer((_) async => false);

    final result = await sut.isAppIntegrityValid();

    expect(result.dataOrNull, isFalse);
  });

  test('returns Failure when datasource throws', () async {
    when(
      () => mockDs.isAppIntegrityValid(),
    ).thenThrow(Exception('check failed'));

    final result = await sut.isAppIntegrityValid();

    expect(result, isA<Failure<bool>>());
  });
}
