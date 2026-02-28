import 'core/result/security_result.dart';
import 'core/utils/logger.dart';
import 'data/datasources/app_integrity_datasource.dart';
import 'data/datasources/certificate_pinning_datasource.dart';
import 'data/datasources/root_detection_datasource.dart';
import 'data/datasources/screenshot_protection_datasource.dart';
import 'data/datasources/secure_storage_datasource.dart';
import 'data/repositories_impl/app_integrity_repository_impl.dart';
import 'data/repositories_impl/certificate_pinning_repository_impl.dart';
import 'data/repositories_impl/root_detection_repository_impl.dart';
import 'data/repositories_impl/screenshot_protection_repository_impl.dart';
import 'data/repositories_impl/secure_storage_repository_impl.dart';
import 'domain/entities/security_status.dart';
import 'domain/usecases/check_app_integrity_usecase.dart';
import 'domain/usecases/check_root_status_usecase.dart';
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
  final Map<String, List<String>> _certificatePins;

  final CheckRootStatusUseCase _checkRoot;
  final ValidateCertificateUseCase _validateCertificate;
  final CheckAppIntegrityUseCase _checkAppIntegrity;

  late final ScreenshotProtection screenshotProtection;
  late final SecureStorage secureStorage;

  SecureBankKit._({
    required bool enableRootDetection,
    required bool enablePinning,
    required bool enableAppIntegrity,
    required Map<String, List<String>> certificatePins,
    required CheckRootStatusUseCase checkRoot,
    required ValidateCertificateUseCase validateCertificate,
    required CheckAppIntegrityUseCase checkAppIntegrity,
    required ToggleScreenshotProtectionUseCase toggleScreenshot,
    required SecureStorageUseCase secureStorageUseCase,
  }) : _enableRootDetection = enableRootDetection,
       _enablePinning = enablePinning,
       _enableAppIntegrity = enableAppIntegrity,
       _certificatePins = certificatePins,
       _checkRoot = checkRoot,
       _validateCertificate = validateCertificate,
       _checkAppIntegrity = checkAppIntegrity {
    screenshotProtection = ScreenshotProtection._(toggleScreenshot);
    secureStorage = SecureStorage._(secureStorageUseCase);
  }

  /// Creates and returns a fully-wired [SecureBankKit] instance.
  factory SecureBankKit.initialize({
    bool enableRootDetection = true,
    bool enablePinning = false,
    bool enableAppIntegrity = true,
    bool enableLogging = false,
    Map<String, List<String>> certificatePins = const {},
  }) {
    if (enableLogging) {
      SecurityLogger.enable();
    }

    final channel = MethodChannelSecurity();

    // Datasources
    final certDs = CertificatePinningDatasource();
    final rootDs = RootDetectionDatasource(channel);
    final screenshotDs = ScreenshotProtectionDatasource(channel);
    final integrityDs = AppIntegrityDatasource(channel);
    final storageDs = SecureStorageDatasource(channel);

    // Repositories
    final certRepo = CertificatePinningRepositoryImpl(certDs);
    final rootRepo = RootDetectionRepositoryImpl(rootDs);
    final screenshotRepo = ScreenshotProtectionRepositoryImpl(screenshotDs);
    final integrityRepo = AppIntegrityRepositoryImpl(integrityDs);
    final storageRepo = SecureStorageRepositoryImpl(storageDs);

    // Use cases
    final checkRoot = CheckRootStatusUseCase(rootRepo);
    final validateCert = ValidateCertificateUseCase(certRepo);
    final checkIntegrity = CheckAppIntegrityUseCase(integrityRepo);
    final toggleScreenshot = ToggleScreenshotProtectionUseCase(screenshotRepo);
    final secureStorageUc = SecureStorageUseCase(storageRepo);

    SecurityLogger.info('SecureBankKit initialized');

    return SecureBankKit._(
      enableRootDetection: enableRootDetection,
      enablePinning: enablePinning,
      enableAppIntegrity: enableAppIntegrity,
      certificatePins: certificatePins,
      checkRoot: checkRoot,
      validateCertificate: validateCert,
      checkAppIntegrity: checkIntegrity,
      toggleScreenshot: toggleScreenshot,
      secureStorageUseCase: secureStorageUc,
    );
  }

  /// Runs all enabled security checks and returns a [SecurityStatus].
  Future<SecurityStatus> runSecurityCheck() async {
    bool isRooted = false;
    bool isAppIntegrityValid = true;
    bool isCertPinningValid = true;

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

    final status = SecurityStatus(
      isRooted: isRooted,
      isAppIntegrityValid: isAppIntegrityValid,
      isCertificatePinningValid: isCertPinningValid,
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
