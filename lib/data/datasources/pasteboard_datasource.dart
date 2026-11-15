import '../../platform/method_channel_security.dart';

class PasteboardDatasource {
  final MethodChannelSecurity _channel;

  const PasteboardDatasource(this._channel);

  Future<void> copy({required String value, required int expiresAfterMs}) =>
      _channel.pasteboardCopy(value: value, expiresAfterMs: expiresAfterMs);

  Future<bool> clear({bool onlyIfOwned = false}) =>
      _channel.pasteboardClear(onlyIfOwned: onlyIfOwned);
}
