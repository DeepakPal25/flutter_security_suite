/// Kind of biometric sensor available on the device.
enum BiometricType {
  /// No biometric hardware, or nothing enrolled.
  none,
  fingerprint,
  face,
  iris,

  /// Biometrics are available but the platform does not say which kind
  /// (common on Android) or several kinds are present.
  generic,
}

/// Whether biometric authentication can be used right now.
class BiometricAvailability {
  /// `true` when a biometric prompt can be shown.
  final bool isAvailable;

  final BiometricType type;

  /// Machine-readable reason when [isAvailable] is `false`
  /// (e.g. `BIOMETRIC_NOT_ENROLLED`). `null` when available.
  final String? reason;

  const BiometricAvailability({
    required this.isAvailable,
    this.type = BiometricType.none,
    this.reason,
  });

  /// Fail-secure default used when the platform reply cannot be understood.
  static const BiometricAvailability unavailable = BiometricAvailability(
    isAvailable: false,
  );

  /// Parses the native reply defensively; unknown / missing fields fall back
  /// to "not available".
  factory BiometricAvailability.fromMap(Map<Object?, Object?> map) {
    final available = map['available'] == true;
    final rawType = map['type'];
    final rawReason = map['reason'];
    var type = BiometricType.none;
    if (rawType is String) {
      for (final candidate in BiometricType.values) {
        if (candidate.name == rawType) {
          type = candidate;
          break;
        }
      }
    }
    if (available && type == BiometricType.none) type = BiometricType.generic;
    return BiometricAvailability(
      isAvailable: available,
      type: type,
      reason: available ? null : (rawReason is String ? rawReason : null),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiometricAvailability &&
          other.isAvailable == isAvailable &&
          other.type == type &&
          other.reason == reason;

  @override
  int get hashCode => Object.hash(isAvailable, type, reason);

  @override
  String toString() =>
      'BiometricAvailability(isAvailable: $isAvailable, type: ${type.name}, '
      'reason: $reason)';
}
