import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// A simple static logger for SecureBankKit.
///
/// Logging is disabled by default. Call [SecurityLogger.enable] to
/// start receiving debug output.
///
/// Logging is **always off in release builds** unless
/// `enable(allowInRelease: true)` is used explicitly. Never log secrets –
/// wrap sensitive values with [SecurityLogger.redact].
class SecurityLogger {
  SecurityLogger._();

  /// Placeholder used when a value is fully masked.
  static const String redactedPlaceholder = '[REDACTED]';

  static bool _enabled = false;

  /// Visible for testing – overrides release-mode detection.
  @visibleForTesting
  static bool? debugReleaseModeOverride;

  /// Visible for testing – receives every emitted log line.
  @visibleForTesting
  static void Function(String message)? debugSink;

  static bool get _isRelease => debugReleaseModeOverride ?? kReleaseMode;

  /// Enable logging output.
  ///
  /// In release builds this is a no-op unless [allowInRelease] is `true`.
  static void enable({bool allowInRelease = false}) {
    if (_isRelease && !allowInRelease) {
      _enabled = false;
      return;
    }
    _enabled = true;
  }

  /// Disable logging output.
  static void disable() => _enabled = false;

  /// Whether logging is currently enabled.
  static bool get isEnabled => _enabled;

  /// Masks a sensitive [value] so it can be logged safely.
  ///
  /// Keeps at most [visibleStart] leading and [visibleEnd] trailing
  /// characters and replaces the rest with [mask]. Values that are too short
  /// to be partially shown without leaking most of their content (less than
  /// twice the visible length) are fully replaced by [redactedPlaceholder].
  ///
  /// ```dart
  /// SecurityLogger.redact('eyJhbGciOiJIUzI1NiJ9.payload.sig', visibleEnd: 4);
  /// // => '****.sig'
  /// ```
  static String redact(
    String? value, {
    int visibleStart = 0,
    int visibleEnd = 0,
    String mask = '****',
  }) {
    if (value == null) return 'null';
    if (value.isEmpty) return '';
    final start = visibleStart < 0 ? 0 : visibleStart;
    final end = visibleEnd < 0 ? 0 : visibleEnd;
    final visible = start + end;
    if (visible == 0 || value.length < visible * 2) {
      return redactedPlaceholder;
    }
    return '${value.substring(0, start)}$mask'
        '${value.substring(value.length - end)}';
  }

  static final List<RegExp> _sensitivePatterns = <RegExp>[
    // JSON Web Tokens.
    RegExp(r'eyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*'),
    // Authorization header values.
    RegExp(r'(?<=\b(?:Bearer|Basic)\s)[A-Za-z0-9._~+/=-]{8,}'),
    // key=value / "key": "value" style secrets.
    RegExp(
      r'''(?<=\b(?:password|passwd|pwd|secret|token|access_token|refresh_token|api_key|apikey|pin|otp|cvv)["']?\s*[:=]\s*["']?)[^\s"',;&}]+''',
      caseSensitive: false,
    ),
    // Payment card numbers (13–19 digits, optional space/dash separators).
    RegExp(r'\b(?:\d[ -]?){12,18}\d\b'),
  ];

  /// Scrubs well-known secret shapes (JWTs, bearer tokens, `password=...`,
  /// card numbers) out of a free-form log [message].
  static String sanitize(String message) {
    var out = message;
    for (final pattern in _sensitivePatterns) {
      out = out.replaceAll(pattern, redactedPlaceholder);
    }
    return out;
  }

  static void _emit(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enabled) return;
    final safe = sanitize(message);
    debugSink?.call(safe);
    developer.log(
      safe,
      name: 'SecureBankKit',
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Log an informational message.
  static void info(String message) => _emit(message);

  /// Log a warning.
  static void warning(String message) => _emit('⚠ $message');

  /// Log an error with an optional [error] object and [stackTrace].
  static void error(String message, {Object? error, StackTrace? stackTrace}) =>
      _emit('✖ $message', error: error, stackTrace: stackTrace);
}
