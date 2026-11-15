import '../../platform/method_channel_security.dart';

class BiometricDatasource {
  final MethodChannelSecurity _channel;

  const BiometricDatasource(this._channel);

  Future<Map<String, dynamic>> availability() =>
      _channel.biometricAvailability();

  Future<bool> authenticate({
    required String reason,
    required bool allowDeviceCredential,
    String? cancelLabel,
  }) => _channel.biometricAuthenticate(
    reason: reason,
    allowDeviceCredential: allowDeviceCredential,
    cancelLabel: cancelLabel,
  );
}
