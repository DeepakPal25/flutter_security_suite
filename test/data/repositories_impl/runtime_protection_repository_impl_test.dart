import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/runtime_protection_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/runtime_protection_repository_impl.dart';

class MockRuntimeProtectionDatasource extends Mock
    implements RuntimeProtectionDatasource {}

void main() {
  late MockRuntimeProtectionDatasource mockDs;
  late RuntimeProtectionRepositoryImpl sut;

  setUp(() {
    mockDs = MockRuntimeProtectionDatasource();
    sut = RuntimeProtectionRepositoryImpl(mockDs);
  });

  test('returns Success(true) when runtime hooking is detected', () async {
    when(() => mockDs.isRuntimeHooked()).thenAnswer((_) async => true);

    final result = await sut.isRuntimeHooked();

    expect(result, isA<Success<bool>>());
    expect(result.dataOrNull, isTrue);
  });

  test('returns Success(false) when no hooking is detected', () async {
    when(() => mockDs.isRuntimeHooked()).thenAnswer((_) async => false);

    final result = await sut.isRuntimeHooked();

    expect(result.dataOrNull, isFalse);
  });

  test('returns Failure when datasource throws', () async {
    when(() => mockDs.isRuntimeHooked())
        .thenThrow(Exception('platform error'));

    final result = await sut.isRuntimeHooked();

    expect(result, isA<Failure<bool>>());
  });
}
