import '../../platform/method_channel_security.dart';

class EmulatorDetectionDatasource {
  final MethodChannelSecurity _channel;

  const EmulatorDetectionDatasource(this._channel);

  Future<bool> isEmulator() => _channel.isEmulator();
}
