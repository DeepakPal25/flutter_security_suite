import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/emulator_detection_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/emulator_detection_repository_impl.dart';

class MockEmulatorDetectionDatasource extends Mock
    implements EmulatorDetectionDatasource {}

void main() {
  late MockEmulatorDetectionDatasource mockDs;
  late EmulatorDetectionRepositoryImpl sut;

  setUp(() {
    mockDs = MockEmulatorDetectionDatasource();
    sut = EmulatorDetectionRepositoryImpl(mockDs);
  });

  test('returns Success(true) when running on emulator', () async {
    when(() => mockDs.isEmulator()).thenAnswer((_) async => true);

    final result = await sut.isEmulator();

    expect(result, isA<Success<bool>>());
    expect(result.dataOrNull, isTrue);
  });

  test('returns Success(false) when running on real device', () async {
    when(() => mockDs.isEmulator()).thenAnswer((_) async => false);

    final result = await sut.isEmulator();

    expect(result.dataOrNull, isFalse);
  });

  test('returns Failure when datasource throws', () async {
    when(() => mockDs.isEmulator()).thenThrow(Exception('platform error'));

    final result = await sut.isEmulator();

    expect(result, isA<Failure<bool>>());
  });
}
