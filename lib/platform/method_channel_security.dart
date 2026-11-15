import 'package:flutter/services.dart';

/// Single method channel bridge to native Android/iOS code.
///
/// All calls use the `feature#action` naming convention, e.g.
/// `root#isDeviceRooted`, `screenshot#enable`.
class MethodChannelSecurity {
  static const MethodChannel _channel = MethodChannel(
    'com.securebankkit/security',
  );

  static const EventChannel _screenCaptureEvents = EventChannel(
    'com.securebankkit/screen_capture_events',
  );

  /// Visible for testing – allows injection of a mock channel.
  static MethodChannel get channel => _channel;

  /// Visible for testing – the screen-capture event channel.
  static EventChannel get screenCaptureEventChannel => _screenCaptureEvents;

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

  // ── Anti-Tamper ───────────────────────────────────

  Future<bool> isDebuggerAttached() async {
    final result = await _channel.invokeMethod<bool>(
      'antitamper#isDebuggerAttached',
    );
    return result ?? false;
  }

  Future<bool> hasInjectedLibraries() async {
    final result = await _channel.invokeMethod<bool>(
      'antitamper#hasInjectedLibraries',
    );
    return result ?? false;
  }

  /// Returns `true` when debugger attachment is (now) denied for the process.
  Future<bool> denyDebuggerAttachment() async {
    final result = await _channel.invokeMethod<bool>('antitamper#denyDebugger');
    return result ?? false;
  }

  // ── Screen Capture Monitoring ─────────────────────

  Future<bool> isScreenCaptured() async {
    final result = await _channel.invokeMethod<bool>('screencapture#isCaptured');
    return result ?? false;
  }

  /// Raw native screen-capture events. Each event is a map such as
  /// `{'type': 'captureChanged', 'isCaptured': true}` or
  /// `{'type': 'screenshot'}`.
  Stream<dynamic> screenCaptureEvents() =>
      _screenCaptureEvents.receiveBroadcastStream();

  // ── Pasteboard Protection ─────────────────────────

  Future<void> pasteboardCopy({
    required String value,
    required int expiresAfterMs,
  }) async {
    await _channel.invokeMethod<void>('pasteboard#copy', {
      'value': value,
      'expiresAfterMs': expiresAfterMs,
    });
  }

  /// Clears the clipboard. When [onlyIfOwned] is `true` the clipboard is only
  /// cleared if it still holds the value last written by this plugin.
  /// Returns `true` when the clipboard was cleared.
  Future<bool> pasteboardClear({bool onlyIfOwned = false}) async {
    final result = await _channel.invokeMethod<bool>('pasteboard#clear', {
      'onlyIfOwned': onlyIfOwned,
    });
    return result ?? false;
  }

  // ── Biometric Authentication ──────────────────────

  /// Returns a map: `{'available': bool, 'type': String, 'reason': String?}`.
  Future<Map<String, dynamic>> biometricAvailability() async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'biometric#availability',
    );
    return result ?? const <String, dynamic>{};
  }

  /// Returns `true` on success and `false` when the user cancelled.
  /// Throws a [PlatformException] for every other failure.
  Future<bool> biometricAuthenticate({
    required String reason,
    required bool allowDeviceCredential,
    String? cancelLabel,
  }) async {
    final result = await _channel.invokeMethod<bool>('biometric#authenticate', {
      'reason': reason,
      'allowDeviceCredential': allowDeviceCredential,
      if (cancelLabel != null) 'cancelLabel': cancelLabel,
    });
    return result ?? false;
  }
}
