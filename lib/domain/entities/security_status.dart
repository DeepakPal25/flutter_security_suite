/// Immutable snapshot of all security checks.
class SecurityStatus {
  final bool isRooted;
  final bool isAppIntegrityValid;
  final bool isCertificatePinningValid;
  final bool isEmulator;
  final bool isScreenBeingRecorded;
  final bool isTampered;
  final bool isRuntimeHooked;

  const SecurityStatus({
    required this.isRooted,
    required this.isAppIntegrityValid,
    required this.isCertificatePinningValid,
    this.isEmulator = false,
    this.isScreenBeingRecorded = false,
    this.isTampered = false,
    this.isRuntimeHooked = false,
  });

  /// `true` when all enabled security checks pass.
  bool get isSecure =>
      !isRooted &&
      !isEmulator &&
      !isScreenBeingRecorded &&
      !isTampered &&
      !isRuntimeHooked &&
      isAppIntegrityValid &&
      isCertificatePinningValid;

  @override
  String toString() =>
      'SecurityStatus(isSecure=$isSecure, isRooted=$isRooted, '
      'isEmulator=$isEmulator, isScreenBeingRecorded=$isScreenBeingRecorded, '
      'isTampered=$isTampered, isRuntimeHooked=$isRuntimeHooked, '
      'appIntegrity=$isAppIntegrityValid, certPinning=$isCertificatePinningValid)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SecurityStatus &&
          other.isRooted == isRooted &&
          other.isAppIntegrityValid == isAppIntegrityValid &&
          other.isCertificatePinningValid == isCertificatePinningValid &&
          other.isEmulator == isEmulator &&
          other.isScreenBeingRecorded == isScreenBeingRecorded &&
          other.isTampered == isTampered &&
          other.isRuntimeHooked == isRuntimeHooked;

  @override
  int get hashCode => Object.hash(
        isRooted,
        isAppIntegrityValid,
        isCertificatePinningValid,
        isEmulator,
        isScreenBeingRecorded,
        isTampered,
        isRuntimeHooked,
      );
}
