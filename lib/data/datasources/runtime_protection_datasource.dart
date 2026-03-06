import '../../platform/method_channel_security.dart';

class RuntimeProtectionDatasource {
  final MethodChannelSecurity _channel;

  const RuntimeProtectionDatasource(this._channel);

  Future<bool> isRuntimeHooked() => _channel.isRuntimeHooked();
}
