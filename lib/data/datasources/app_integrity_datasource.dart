import '../../platform/method_channel_security.dart';

/// Datasource that delegates app-integrity checks to the
/// platform via [MethodChannelSecurity].
class AppIntegrityDatasource {
  final MethodChannelSecurity _channel;

  const AppIntegrityDatasource(this._channel);

  Future<bool> isAppIntegrityValid() => _channel.isAppIntegrityValid();
}
