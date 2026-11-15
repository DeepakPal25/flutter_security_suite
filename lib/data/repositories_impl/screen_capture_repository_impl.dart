import 'dart:async';

import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/screen_capture_event.dart';
import '../../domain/repositories/screen_capture_repository.dart';
import '../datasources/screen_capture_datasource.dart';

class ScreenCaptureRepositoryImpl implements ScreenCaptureRepository {
  final ScreenCaptureDatasource _datasource;

  ScreenCaptureRepositoryImpl(this._datasource);

  late final Stream<ScreenCaptureEvent> _events = _datasource.events.transform(
    StreamTransformer<dynamic, ScreenCaptureEvent>.fromHandlers(
      handleData: (raw, sink) {
        final event = ScreenCaptureEvent.tryParse(raw);
        if (event == null) {
          SecurityLogger.warning('Ignoring malformed screen capture event');
          return;
        }
        sink.add(event);
      },
      handleError: (error, stackTrace, sink) {
        SecurityLogger.error(
          'Screen capture monitoring failed',
          error: error,
          stackTrace: stackTrace,
        );
        sink.addError(
          PlatformSecurityException(
            platform: 'native',
            message: 'Screen capture monitoring failed: $error',
            originalError: error,
          ),
          stackTrace,
        );
      },
    ),
  );

  @override
  Stream<ScreenCaptureEvent> get events => _events;

  @override
  Future<SecurityResult<bool>> isCaptured() async {
    try {
      SecurityLogger.info('Checking screen capture status');
      return Success(await _datasource.isCaptured());
    } catch (e, st) {
      SecurityLogger.error(
        'Screen capture check failed',
        error: e,
        stackTrace: st,
      );
      return Failure(
        PlatformSecurityException(
          platform: 'native',
          message: 'Screen capture check failed: $e',
          originalError: e,
        ),
      );
    }
  }
}
