import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_security_suite/core/exceptions/security_exception.dart';
import 'package:flutter_security_suite/core/result/security_result.dart';
import 'package:flutter_security_suite/data/datasources/screen_capture_datasource.dart';
import 'package:flutter_security_suite/data/repositories_impl/screen_capture_repository_impl.dart';
import 'package:flutter_security_suite/domain/entities/screen_capture_event.dart';

class MockScreenCaptureDatasource extends Mock
    implements ScreenCaptureDatasource {}

void main() {
  late MockScreenCaptureDatasource ds;
  late StreamController<dynamic> native;
  late ScreenCaptureRepositoryImpl sut;

  setUp(() {
    ds = MockScreenCaptureDatasource();
    native = StreamController<dynamic>.broadcast();
    when(() => ds.events).thenAnswer((_) => native.stream);
    sut = ScreenCaptureRepositoryImpl(ds);
  });

  tearDown(() => native.close());

  group('events', () {
    test('parses native events in order', () async {
      final received = <ScreenCaptureEvent>[];
      final sub = sut.events.listen(received.add);

      native
        ..add({'type': 'captureChanged', 'isCaptured': true})
        ..add({'type': 'screenshot'})
        ..add({'type': 'captureChanged', 'isCaptured': false});
      await pumpEventQueue();

      expect(received, const [
        ScreenCaptureEvent.captureChanged(isCaptured: true),
        ScreenCaptureEvent.screenshot(),
        ScreenCaptureEvent.captureChanged(isCaptured: false),
      ]);
      await sub.cancel();
    });

    test('drops malformed events and keeps the stream alive', () async {
      final received = <ScreenCaptureEvent>[];
      final errors = <Object>[];
      final sub = sut.events.listen(received.add, onError: errors.add);

      native
        ..add(null)
        ..add('screenshot')
        ..add({'type': 'captureChanged'})
        ..add({'type': 'captureChanged', 'isCaptured': 'yes'})
        ..add(42)
        ..add({'type': 'screenshot'});
      await pumpEventQueue();

      expect(received, const [ScreenCaptureEvent.screenshot()]);
      expect(errors, isEmpty);
      await sub.cancel();
    });

    test('wraps stream errors and keeps delivering afterwards', () async {
      final received = <ScreenCaptureEvent>[];
      final errors = <Object>[];
      final sub = sut.events.listen(received.add, onError: errors.add);

      native
        ..addError(PlatformException(code: 'CAPTURE_ERROR'))
        ..add({'type': 'screenshot'});
      await pumpEventQueue();

      expect(errors.single, isA<PlatformSecurityException>());
      expect(
        (errors.single as PlatformSecurityException).message,
        startsWith('Screen capture monitoring failed'),
      );
      expect(
        (errors.single as PlatformSecurityException).originalError,
        isA<PlatformException>(),
      );
      expect(received, const [ScreenCaptureEvent.screenshot()]);
      await sub.cancel();
    });

    test('returns the same stream so the native sink is shared', () {
      expect(identical(sut.events, sut.events), isTrue);
      verify(() => ds.events).called(1);
    });

    test('supports several listeners', () async {
      final a = <ScreenCaptureEvent>[];
      final b = <ScreenCaptureEvent>[];
      final subA = sut.events.listen(a.add);
      final subB = sut.events.listen(b.add);

      native.add({'type': 'screenshot'});
      await pumpEventQueue();

      expect(a, hasLength(1));
      expect(b, hasLength(1));
      await subA.cancel();
      await subB.cancel();
    });

    test('a cancelled listener stops receiving, others continue', () async {
      final a = <ScreenCaptureEvent>[];
      final b = <ScreenCaptureEvent>[];
      final subA = sut.events.listen(a.add);
      final subB = sut.events.listen(b.add);
      await subA.cancel();

      native.add({'type': 'screenshot'});
      await pumpEventQueue();

      expect(a, isEmpty);
      expect(b, hasLength(1));
      await subB.cancel();
    });

    test('does not touch the datasource until events are requested', () {
      final lazyDs = MockScreenCaptureDatasource();
      ScreenCaptureRepositoryImpl(lazyDs);
      verifyNever(() => lazyDs.events);
    });
  });

  group('isCaptured', () {
    test('returns the native value', () async {
      when(() => ds.isCaptured()).thenAnswer((_) async => true);
      expect((await sut.isCaptured()).dataOrNull, isTrue);
      when(() => ds.isCaptured()).thenAnswer((_) async => false);
      expect((await sut.isCaptured()).dataOrNull, isFalse);
    });

    test('wraps an error', () async {
      when(() => ds.isCaptured()).thenThrow(PlatformException(code: 'ERR'));
      final error = ((await sut.isCaptured()) as Failure).error;
      expect(error, isA<PlatformSecurityException>());
      expect(error.message, startsWith('Screen capture check failed'));
    });
  });
}
