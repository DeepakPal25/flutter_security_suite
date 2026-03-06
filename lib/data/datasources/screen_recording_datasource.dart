import '../../platform/method_channel_security.dart';

class ScreenRecordingDatasource {
  final MethodChannelSecurity _channel;

  const ScreenRecordingDatasource(this._channel);

  Future<bool> isScreenBeingRecorded() => _channel.isScreenBeingRecorded();
}
