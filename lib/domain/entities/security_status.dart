/// Immutable snapshot of all security checks.
class SecurityStatus {
  final bool isRooted;
  final bool isAppIntegrityValid;
  final bool isCertificatePinningValid;

  const SecurityStatus({
    required this.isRooted,
    required this.isAppIntegrityValid,
    required this.isCertificatePinningValid,
  });

  /// `true` when the device is not rooted, app integrity is valid,
  /// and certificate pinning has passed.
  bool get isSecure =>
      !isRooted && isAppIntegrityValid && isCertificatePinningValid;

  @override
  String toString() =>
      'SecurityStatus(isSecure=$isSecure, isRooted=$isRooted, '
      'appIntegrity=$isAppIntegrityValid, '
      'certPinning=$isCertificatePinningValid)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityStatus &&
          other.isRooted == isRooted &&
          other.isAppIntegrityValid == isAppIntegrityValid &&
          other.isCertificatePinningValid == isCertificatePinningValid;

  @override
  int get hashCode =>
      Object.hash(isRooted, isAppIntegrityValid, isCertificatePinningValid);
}
