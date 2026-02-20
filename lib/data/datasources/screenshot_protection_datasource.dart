import '../../platform/method_channel_security.dart';

/// Datasource that delegates screenshot protection to the
/// platform via [MethodChannelSecurity].
class ScreenshotProtectionDatasource {
  final MethodChannelSecurity _channel;

  const ScreenshotProtectionDatasource(this._channel);

  Future<void> enable() => _channel.enableScreenshotProtection();

  Future<void> disable() => _channel.disableScreenshotProtection();
}
