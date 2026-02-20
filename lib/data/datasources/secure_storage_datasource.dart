import '../../platform/method_channel_security.dart';

/// Datasource that delegates secure-storage operations to the
/// platform via [MethodChannelSecurity].
class SecureStorageDatasource {
  final MethodChannelSecurity _channel;

  const SecureStorageDatasource(this._channel);

  Future<void> write({required String key, required String value}) =>
      _channel.secureStorageWrite(key: key, value: value);

  Future<String?> read({required String key}) =>
      _channel.secureStorageRead(key: key);

  Future<void> delete({required String key}) =>
      _channel.secureStorageDelete(key: key);

  Future<void> deleteAll() => _channel.secureStorageDeleteAll();
}
