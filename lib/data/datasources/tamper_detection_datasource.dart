import '../../platform/method_channel_security.dart';

class TamperDetectionDatasource {
  final MethodChannelSecurity _channel;

  const TamperDetectionDatasource(this._channel);

  Future<bool> isTampered() => _channel.isTampered();

  Future<String?> getSignatureHash() => _channel.getSignatureHash();
}
