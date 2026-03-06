import 'package:flutter/services.dart';

/// Single method channel bridge to native Android/iOS code.
///
/// All calls use the `feature#action` naming convention, e.g.
/// `root#isDeviceRooted`, `screenshot#enable`.
class MethodChannelSecurity {
  static const MethodChannel _channel = MethodChannel(
    'com.securebankkit/security',
  );

  /// Visible for testing – allows injection of a mock channel.
  static MethodChannel get channel => _channel;

  // ── Root / Jailbreak ─────────────────────────────────────────

  Future<bool> isDeviceRooted() async {
    final result = await _channel.invokeMethod<bool>('root#isDeviceRooted');
    return result ?? false;
  }

  // ── Screenshot Protection ────────────────────────────────────

  Future<void> enableScreenshotProtection() async {
    await _channel.invokeMethod<void>('screenshot#enable');
  }

  Future<void> disableScreenshotProtection() async {
    await _channel.invokeMethod<void>('screenshot#disable');
  }

  // ── App Integrity ────────────────────────────────────────────

  Future<bool> isAppIntegrityValid() async {
    final result = await _channel.invokeMethod<bool>('integrity#isValid');
    return result ?? false;
  }

  // ── Secure Storage ───────────────────────────────────────────

  Future<void> secureStorageWrite({
    required String key,
    required String value,
  }) async {
    await _channel.invokeMethod<void>('storage#write', {
      'key': key,
      'value': value,
    });
  }

  Future<String?> secureStorageRead({required String key}) async {
    return _channel.invokeMethod<String>('storage#read', {'key': key});
  }

  Future<void> secureStorageDelete({required String key}) async {
    await _channel.invokeMethod<void>('storage#delete', {'key': key});
  }

  Future<void> secureStorageDeleteAll() async {
    await _channel.invokeMethod<void>('storage#deleteAll');
  }

  // ── Emulator Detection ────────────────────────────

  Future<bool> isEmulator() async {
    final result = await _channel.invokeMethod<bool>('emulator#isEmulator');
    return result ?? false;
  }

  // ── Screen Recording Detection ────────────────────

  Future<bool> isScreenBeingRecorded() async {
    final result = await _channel.invokeMethod<bool>('recording#isRecording');
    return result ?? false;
  }

  // ── Tamper Detection ──────────────────────────────

  Future<bool> isTampered() async {
    final result = await _channel.invokeMethod<bool>('tamper#isTampered');
    return result ?? true; // Fail secure: assume tampered on error.
  }

  Future<String?> getSignatureHash() async {
    return _channel.invokeMethod<String>('tamper#getSignatureHash');
  }

  // ── Runtime Protection ────────────────────────────

  Future<bool> isRuntimeHooked() async {
    final result = await _channel.invokeMethod<bool>('runtime#isHooked');
    return result ?? false;
  }
}
