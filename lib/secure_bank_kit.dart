import 'core/result/security_result.dart';
import 'core/utils/logger.dart';
import 'data/datasources/app_integrity_datasource.dart';
import 'data/datasources/certificate_pinning_datasource.dart';
import 'data/datasources/emulator_detection_datasource.dart';
import 'data/datasources/root_detection_datasource.dart';
import 'data/datasources/runtime_protection_datasource.dart';
import 'data/datasources/screen_recording_datasource.dart';
import 'data/datasources/screenshot_protection_datasource.dart';
import 'data/datasources/secure_storage_datasource.dart';
import 'data/datasources/tamper_detection_datasource.dart';
import 'data/repositories_impl/app_integrity_repository_impl.dart';
import 'data/repositories_impl/certificate_pinning_repository_impl.dart';
import 'data/repositories_impl/emulator_detection_repository_impl.dart';
import 'data/repositories_impl/root_detection_repository_impl.dart';
import 'data/repositories_impl/runtime_protection_repository_impl.dart';
import 'data/repositories_impl/screen_recording_repository_impl.dart';
import 'data/repositories_impl/screenshot_protection_repository_impl.dart';
import 'data/repositories_impl/secure_storage_repository_impl.dart';
import 'data/repositories_impl/tamper_detection_repository_impl.dart';
import 'domain/entities/security_status.dart';
import 'domain/usecases/check_app_integrity_usecase.dart';
import 'domain/usecases/check_emulator_usecase.dart';
import 'domain/usecases/check_root_status_usecase.dart';
import 'domain/usecases/check_runtime_protection_usecase.dart';
import 'domain/usecases/check_screen_recording_usecase.dart';
import 'domain/usecases/check_tamper_usecase.dart';
import 'domain/usecases/secure_storage_usecase.dart';
import 'domain/usecases/toggle_screenshot_protection_usecase.dart';
import 'domain/usecases/validate_certificate_usecase.dart';
import 'platform/method_channel_security.dart';

/// Public facade for the SecureBankKit security plugin.
///
/// ```dart
/// final kit = SecureBankKit.initialize(
///   enableRootDetection: true,
///   enablePinning: true,
///   certificatePins: {'api.bank.com': ['sha256/AAAA...']},
/// );
///
/// final status = await kit.runSecurityCheck();
/// if (!status.isSecure) { /* handle */ }
/// ```
class SecureBankKit {
  final bool _enableRootDetection;
  final bool _enablePinning;
  final bool _enableAppIntegrity;
  final bool _enableEmulatorDetection;
  final bool _enableScreenRecordingDetection;
  final bool _enableTamperDetection;
  final bool _enableRuntimeProtection;
  final Map<String, List<String>> _certificatePins;

  final CheckRootStatusUseCase _checkRoot;
  final ValidateCertificateUseCase _validateCertificate;
  final CheckAppIntegrityUseCase _checkAppIntegrity;
  final CheckEmulatorUseCase _checkEmulator;
  final CheckScreenRecordingUseCase _checkScreenRecording;
  final CheckTamperUseCase _checkTamper;
  final CheckRuntimeProtectionUseCase _checkRuntimeProtection;

  late final ScreenshotProtection screenshotProtection;
  late final SecureStorage secureStorage;
  late final TamperDetection tamperDetection;

  SecureBankKit._({
    required bool enableRootDetection,
    required bool enablePinning,
    required bool enableAppIntegrity,
    required bool enableEmulatorDetection,
    required bool enableScreenRecordingDetection,
    required bool enableTamperDetection,
    required bool enableRuntimeProtection,
    required Map<String, List<String>> certificatePins,
    required CheckRootStatusUseCase checkRoot,
    required ValidateCertificateUseCase validateCertificate,
    required CheckAppIntegrityUseCase checkAppIntegrity,
    required CheckEmulatorUseCase checkEmulator,
    required CheckScreenRecordingUseCase checkScreenRecording,
    required CheckTamperUseCase checkTamper,
    required CheckRuntimeProtectionUseCase checkRuntimeProtection,
    required ToggleScreenshotProtectionUseCase toggleScreenshot,
    required SecureStorageUseCase secureStorageUseCase,
  }) : _enableRootDetection = enableRootDetection,
       _enablePinning = enablePinning,
       _enableAppIntegrity = enableAppIntegrity,
       _enableEmulatorDetection = enableEmulatorDetection,
       _enableScreenRecordingDetection = enableScreenRecordingDetection,
       _enableTamperDetection = enableTamperDetection,
       _enableRuntimeProtection = enableRuntimeProtection,
       _certificatePins = certificatePins,
       _checkRoot = checkRoot,
       _validateCertificate = validateCertificate,
       _checkAppIntegrity = checkAppIntegrity,
       _checkEmulator = checkEmulator,
       _checkScreenRecording = checkScreenRecording,
       _checkTamper = checkTamper,
       _checkRuntimeProtection = checkRuntimeProtection {
    screenshotProtection = ScreenshotProtection._(toggleScreenshot);
    secureStorage = SecureStorage._(secureStorageUseCase);
    tamperDetection = TamperDetection._(checkTamper);
  }

  /// Creates and returns a fully-wired [SecureBankKit] instance.
  factory SecureBankKit.initialize({
    bool enableRootDetection = true,
    bool enablePinning = false,
    bool enableAppIntegrity = true,
    bool enableEmulatorDetection = true,
    bool enableScreenRecordingDetection = false,
    bool enableTamperDetection = true,
    bool enableRuntimeProtection = true,
    bool enableLogging = false,
    Map<String, List<String>> certificatePins = const {},
  }) {
    if (enableLogging) {
      SecurityLogger.enable();
    }

    final channel = MethodChannelSecurity();

    // Datasources
    final certDs           = CertificatePinningDatasource();
    final rootDs           = RootDetectionDatasource(channel);
    final screenshotDs     = ScreenshotProtectionDatasource(channel);
    final integrityDs      = AppIntegrityDatasource(channel);
    final storageDs        = SecureStorageDatasource(channel);
    final emulatorDs       = EmulatorDetectionDatasource(channel);
    final recordingDs      = ScreenRecordingDatasource(channel);
    final tamperDs         = TamperDetectionDatasource(channel);
    final runtimeDs        = RuntimeProtectionDatasource(channel);

    // Repositories
    final certRepo         = CertificatePinningRepositoryImpl(certDs);
    final rootRepo         = RootDetectionRepositoryImpl(rootDs);
    final screenshotRepo   = ScreenshotProtectionRepositoryImpl(screenshotDs);
    final integrityRepo    = AppIntegrityRepositoryImpl(integrityDs);
    final storageRepo      = SecureStorageRepositoryImpl(storageDs);
    final emulatorRepo     = EmulatorDetectionRepositoryImpl(emulatorDs);
    final recordingRepo    = ScreenRecordingRepositoryImpl(recordingDs);
    final tamperRepo       = TamperDetectionRepositoryImpl(tamperDs);
    final runtimeRepo      = RuntimeProtectionRepositoryImpl(runtimeDs);

    // Use cases
    final checkRoot        = CheckRootStatusUseCase(rootRepo);
    final validateCert     = ValidateCertificateUseCase(certRepo);
    final checkIntegrity   = CheckAppIntegrityUseCase(integrityRepo);
    final toggleScreenshot = ToggleScreenshotProtectionUseCase(screenshotRepo);
    final secureStorageUc  = SecureStorageUseCase(storageRepo);
    final checkEmulator    = CheckEmulatorUseCase(emulatorRepo);
    final checkRecording   = CheckScreenRecordingUseCase(recordingRepo);
    final checkTamper      = CheckTamperUseCase(tamperRepo);
    final checkRuntime     = CheckRuntimeProtectionUseCase(runtimeRepo);

    SecurityLogger.info('SecureBankKit initialized');

    return SecureBankKit._(
      enableRootDetection: enableRootDetection,
      enablePinning: enablePinning,
      enableAppIntegrity: enableAppIntegrity,
      enableEmulatorDetection: enableEmulatorDetection,
      enableScreenRecordingDetection: enableScreenRecordingDetection,
      enableTamperDetection: enableTamperDetection,
      enableRuntimeProtection: enableRuntimeProtection,
      certificatePins: certificatePins,
      checkRoot: checkRoot,
      validateCertificate: validateCert,
      checkAppIntegrity: checkIntegrity,
      checkEmulator: checkEmulator,
      checkScreenRecording: checkRecording,
      checkTamper: checkTamper,
      checkRuntimeProtection: checkRuntime,
      toggleScreenshot: toggleScreenshot,
      secureStorageUseCase: secureStorageUc,
    );
  }

  /// Runs all enabled security checks and returns a [SecurityStatus].
  Future<SecurityStatus> runSecurityCheck() async {
    bool isRooted               = false;
    bool isAppIntegrityValid    = true;
    bool isCertPinningValid     = true;
    bool isEmulator             = false;
    bool isScreenBeingRecorded  = false;
    bool isTampered             = false;
    bool isRuntimeHooked        = false;

    if (_enableRootDetection) {
      final result = await _checkRoot();
      // Fail secure: if the check itself errors, treat as potentially rooted.
      isRooted = result.dataOrNull ?? true;
    }

    if (_enableAppIntegrity) {
      final result = await _checkAppIntegrity();
      isAppIntegrityValid = result.dataOrNull ?? false;
    }

    if (_enablePinning) {
      for (final entry in _certificatePins.entries) {
        final result = await _validateCertificate(
          host: entry.key,
          pins: entry.value,
        );
        if (result.dataOrNull != true) {
          isCertPinningValid = false;
          break;
        }
      }
    }

    if (_enableEmulatorDetection) {
      final result = await _checkEmulator();
      isEmulator = result.dataOrNull ?? false;
    }

    if (_enableScreenRecordingDetection) {
      final result = await _checkScreenRecording();
      isScreenBeingRecorded = result.dataOrNull ?? false;
    }

    if (_enableTamperDetection) {
      final result = await _checkTamper();
      // Fail secure: assume tampered if the check itself errors.
      isTampered = result.dataOrNull ?? true;
    }

    if (_enableRuntimeProtection) {
      final result = await _checkRuntimeProtection();
      isRuntimeHooked = result.dataOrNull ?? false;
    }

    final status = SecurityStatus(
      isRooted: isRooted,
      isAppIntegrityValid: isAppIntegrityValid,
      isCertificatePinningValid: isCertPinningValid,
      isEmulator: isEmulator,
      isScreenBeingRecorded: isScreenBeingRecorded,
      isTampered: isTampered,
      isRuntimeHooked: isRuntimeHooked,
    );

    SecurityLogger.info('Security check complete: $status');
    return status;
  }
}

/// Sub-accessor for screenshot protection operations.
class ScreenshotProtection {
  final ToggleScreenshotProtectionUseCase _useCase;

  ScreenshotProtection._(this._useCase);

  Future<SecurityResult<void>> enable() => _useCase(enable: true);
  Future<SecurityResult<void>> disable() => _useCase(enable: false);
}

/// Sub-accessor for tamper detection utilities.
///
/// Useful for one-time certificate pinning setup:
/// ```dart
/// final hash = await kit.tamperDetection.getSignatureHash();
/// print('Pin this in your config: $hash');
/// ```
class TamperDetection {
  final CheckTamperUseCase _useCase;

  TamperDetection._(this._useCase);

  Future<SecurityResult<bool>> check() => _useCase();

  /// Returns the SHA-256 hex fingerprint of the app's signing certificate.
  Future<SecurityResult<String?>> getSignatureHash() =>
      _useCase.getSignatureHash();
}

/// Sub-accessor for secure storage operations.
class SecureStorage {
  final SecureStorageUseCase _useCase;

  SecureStorage._(this._useCase);

  Future<SecurityResult<void>> write({
    required String key,
    required String value,
  }) => _useCase.write(key: key, value: value);

  Future<SecurityResult<String?>> read({required String key}) =>
      _useCase.read(key: key);

  Future<SecurityResult<void>> delete({required String key}) =>
      _useCase.delete(key: key);

  Future<SecurityResult<void>> deleteAll() => _useCase.deleteAll();
}
