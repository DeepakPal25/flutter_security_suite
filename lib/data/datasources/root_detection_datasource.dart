import '../../platform/method_channel_security.dart';

/// Datasource that delegates root/jailbreak detection to the
/// platform via [MethodChannelSecurity].
class RootDetectionDatasource {
  final MethodChannelSecurity _channel;

  const RootDetectionDatasource(this._channel);

  Future<bool> isDeviceRooted() => _channel.isDeviceRooted();
}
