/// Kind of a [ScreenCaptureEvent].
enum ScreenCaptureEventType {
  /// Screen recording / mirroring started or stopped.
  captureChanged,

  /// The user took a screenshot.
  screenshot,
}

/// An event emitted by the native screen-capture monitor.
class ScreenCaptureEvent {
  final ScreenCaptureEventType type;

  /// For [ScreenCaptureEventType.captureChanged]: whether the screen is now
  /// being recorded / mirrored. Always `null` for screenshots.
  final bool? isCaptured;

  const ScreenCaptureEvent.captureChanged({required bool this.isCaptured})
    : type = ScreenCaptureEventType.captureChanged;

  const ScreenCaptureEvent.screenshot()
    : type = ScreenCaptureEventType.screenshot,
      isCaptured = null;

  /// Parses a raw platform event. Returns `null` for anything malformed so a
  /// bad native payload can never crash a listener.
  static ScreenCaptureEvent? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final type = raw['type'];
    if (type == 'screenshot') return const ScreenCaptureEvent.screenshot();
    if (type == 'captureChanged') {
      final captured = raw['isCaptured'];
      if (captured is bool) {
        return ScreenCaptureEvent.captureChanged(isCaptured: captured);
      }
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScreenCaptureEvent &&
          other.type == type &&
          other.isCaptured == isCaptured;

  @override
  int get hashCode => Object.hash(type, isCaptured);

  @override
  String toString() => type == ScreenCaptureEventType.screenshot
      ? 'ScreenCaptureEvent.screenshot()'
      : 'ScreenCaptureEvent.captureChanged(isCaptured: $isCaptured)';
}
