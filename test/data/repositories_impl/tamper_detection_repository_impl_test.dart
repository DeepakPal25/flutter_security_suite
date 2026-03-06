import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/tamper_detection_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/tamper_detection_repository_impl.dart';

class MockTamperDetectionDatasource extends Mock
    implements TamperDetectionDatasource {}

void main() {
  late MockTamperDetectionDatasource mockDs;
  late TamperDetectionRepositoryImpl sut;

  setUp(() {
    mockDs = MockTamperDetectionDatasource();
    sut = TamperDetectionRepositoryImpl(mockDs);
  });

  group('isTampered', () {
    test('returns Success(true) when app is tampered', () async {
      when(() => mockDs.isTampered()).thenAnswer((_) async => true);

      final result = await sut.isTampered();

      expect(result, isA<Success<bool>>());
      expect(result.dataOrNull, isTrue);
    });

    test('returns Success(false) when app is not tampered', () async {
      when(() => mockDs.isTampered()).thenAnswer((_) async => false);

      final result = await sut.isTampered();

      expect(result.dataOrNull, isFalse);
    });

    test('returns Failure when datasource throws', () async {
      when(() => mockDs.isTampered()).thenThrow(Exception('platform error'));

      final result = await sut.isTampered();

      expect(result, isA<Failure<bool>>());
    });
  });

  group('getSignatureHash', () {
    test('returns Success with hash string', () async {
      when(() => mockDs.getSignatureHash())
          .thenAnswer((_) async => 'abc123hash');

      final result = await sut.getSignatureHash();

      expect(result, isA<Success<String?>>());
      expect(result.dataOrNull, 'abc123hash');
    });

    test('returns Success(null) when hash is unavailable', () async {
      when(() => mockDs.getSignatureHash()).thenAnswer((_) async => null);

      final result = await sut.getSignatureHash();

      expect(result.dataOrNull, isNull);
    });

    test('returns Failure when datasource throws', () async {
      when(() => mockDs.getSignatureHash())
          .thenThrow(Exception('platform error'));

      final result = await sut.getSignatureHash();

      expect(result, isA<Failure<String?>>());
    });
  });
}
