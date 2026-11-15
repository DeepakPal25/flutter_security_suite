import '../../platform/method_channel_security.dart';

class AntiTamperDatasource {
  final MethodChannelSecurity _channel;

  const AntiTamperDatasource(this._channel);

  Future<bool> isDebuggerAttached() => _channel.isDebuggerAttached();

  Future<bool> hasInjectedLibraries() => _channel.hasInjectedLibraries();

  Future<bool> denyDebuggerAttachment() => _channel.denyDebuggerAttachment();
}
