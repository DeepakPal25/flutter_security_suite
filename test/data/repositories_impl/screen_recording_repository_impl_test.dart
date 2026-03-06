import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/screen_recording_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/screen_recording_repository_impl.dart';

class MockScreenRecordingDatasource extends Mock
    implements ScreenRecordingDatasource {}

void main() {
  late MockScreenRecordingDatasource mockDs;
  late ScreenRecordingRepositoryImpl sut;

  setUp(() {
    mockDs = MockScreenRecordingDatasource();
    sut = ScreenRecordingRepositoryImpl(mockDs);
  });

  test('returns Success(true) when screen is being recorded', () async {
    when(() => mockDs.isScreenBeingRecorded()).thenAnswer((_) async => true);

    final result = await sut.isScreenBeingRecorded();

    expect(result, isA<Success<bool>>());
    expect(result.dataOrNull, isTrue);
  });

  test('returns Success(false) when screen is not being recorded', () async {
    when(() => mockDs.isScreenBeingRecorded()).thenAnswer((_) async => false);

    final result = await sut.isScreenBeingRecorded();

    expect(result.dataOrNull, isFalse);
  });

  test('returns Failure when datasource throws', () async {
    when(() => mockDs.isScreenBeingRecorded())
        .thenThrow(Exception('platform error'));

    final result = await sut.isScreenBeingRecorded();

    expect(result, isA<Failure<bool>>());
  });
}
