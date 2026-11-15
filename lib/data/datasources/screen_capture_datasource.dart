import '../../platform/method_channel_security.dart';

class ScreenCaptureDatasource {
  final MethodChannelSecurity _channel;

  ScreenCaptureDatasource(this._channel);

  /// A single shared broadcast stream. The native side only supports one
  /// event sink, so every Dart listener must go through the same stream.
  late final Stream<dynamic> _events = _channel.screenCaptureEvents();

  Stream<dynamic> get events => _events;

  Future<bool> isCaptured() => _channel.isScreenCaptured();
}
