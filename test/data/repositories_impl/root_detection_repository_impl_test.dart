import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/root_detection_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/root_detection_repository_impl.dart';

class MockRootDetectionDatasource extends Mock
    implements RootDetectionDatasource {}

void main() {
  late MockRootDetectionDatasource mockDs;
  late RootDetectionRepositoryImpl sut;

  setUp(() {
    mockDs = MockRootDetectionDatasource();
    sut = RootDetectionRepositoryImpl(mockDs);
  });

  test('returns Success(true) when rooted', () async {
    when(() => mockDs.isDeviceRooted()).thenAnswer((_) async => true);

    final result = await sut.isDeviceRooted();

    expect(result, isA<Success<bool>>());
    expect(result.dataOrNull, isTrue);
  });

  test('returns Success(false) when not rooted', () async {
    when(() => mockDs.isDeviceRooted()).thenAnswer((_) async => false);

    final result = await sut.isDeviceRooted();

    expect(result.dataOrNull, isFalse);
  });

  test('returns Failure when datasource throws', () async {
    when(() => mockDs.isDeviceRooted())
        .thenThrow(Exception('platform error'));

    final result = await sut.isDeviceRooted();

    expect(result, isA<Failure<bool>>());
  });
}
