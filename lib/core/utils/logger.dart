import 'dart:developer' as developer;

/// A simple static logger for SecureBankKit.
///
/// Logging is disabled by default. Call [SecurityLogger.enable] to
/// start receiving debug output.
class SecurityLogger {
  SecurityLogger._();

  static bool _enabled = false;

  /// Enable logging output.
  static void enable() => _enabled = true;

  /// Disable logging output.
  static void disable() => _enabled = false;

  /// Whether logging is currently enabled.
  static bool get isEnabled => _enabled;

  /// Log an informational message.
  static void info(String message) {
    if (_enabled) {
      developer.log(message, name: 'SecureBankKit');
    }
  }

  /// Log a warning.
  static void warning(String message) {
    if (_enabled) {
      developer.log('⚠ $message', name: 'SecureBankKit');
    }
  }

  /// Log an error with an optional [error] object and [stackTrace].
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (_enabled) {
      developer.log(
        '✖ $message',
        name: 'SecureBankKit',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
