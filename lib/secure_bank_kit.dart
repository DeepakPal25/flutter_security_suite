import 'dart:io';

import 'core/network/certificate_pinner.dart';
import 'core/result/security_result.dart';
import 'core/utils/logger.dart';
import 'data/datasources/anti_tamper_datasource.dart';
import 'data/datasources/app_integrity_datasource.dart';
import 'data/datasources/biometric_datasource.dart';
import 'data/datasources/certificate_pinning_datasource.dart';
import 'data/datasources/emulator_detection_datasource.dart';
import 'data/datasources/pasteboard_datasource.dart';
import 'data/datasources/root_detection_datasource.dart';
import 'data/datasources/runtime_protection_datasource.dart';
import 'data/datasources/screen_capture_datasource.dart';
import 'data/datasources/screen_recording_datasource.dart';
import 'data/datasources/screenshot_protection_datasource.dart';
import 'data/datasources/secure_storage_datasource.dart';
import 'data/datasources/tamper_detection_datasource.dart';
import 'data/repositories_impl/anti_tamper_repository_impl.dart';
import 'data/repositories_impl/app_integrity_repository_impl.dart';
import 'data/repositories_impl/biometric_repository_impl.dart';
import 'data/repositories_impl/certificate_pinning_repository_impl.dart';
import 'data/repositories_impl/emulator_detection_repository_impl.dart';
import 'data/repositories_impl/pasteboard_repository_impl.dart';
import 'data/repositories_impl/root_detection_repository_impl.dart';
import 'data/repositories_impl/runtime_protection_repository_impl.dart';
import 'data/repositories_impl/screen_capture_repository_impl.dart';
import 'data/repositories_impl/screen_recording_repository_impl.dart';
import 'data/repositories_impl/screenshot_protection_repository_impl.dart';
import 'data/repositories_impl/secure_storage_repository_impl.dart';
import 'data/repositories_impl/tamper_detection_repository_impl.dart';
import 'domain/entities/anti_tamper_status.dart';
import 'domain/entities/biometric_availability.dart';
import 'domain/entities/obfuscation_status.dart';
import 'domain/entities/screen_capture_event.dart';
import 'domain/entities/security_status.dart';
import 'domain/repositories/biometric_repository.dart';
import 'domain/usecases/biometric_auth_usecase.dart';
import 'domain/usecases/check_anti_tamper_usecase.dart';
import 'domain/usecases/check_app_integrity_usecase.dart';
import 'domain/usecases/check_emulator_usecase.dart';
import 'domain/usecases/check_root_status_usecase.dart';
import 'domain/usecases/check_runtime_protection_usecase.dart';
import 'domain/usecases/check_screen_recording_usecase.dart';
import 'domain/usecases/check_tamper_usecase.dart';
import 'domain/usecases/monitor_screen_capture_usecase.dart';
import 'domain/usecases/pasteboard_usecase.dart';
import 'domain/usecases/secure_storage_usecase.dart';
import 'domain/usecases/toggle_screenshot_protection_usecase.dart';
import 'domain/usecases/validate_certificate_usecase.dart';
import 'managers/app_lock_manager.dart';
import 'managers/build_hardening_inspector.dart';
import 'managers/secure_token_storage.dart';
import 'managers/string_obfuscator.dart';
import 'managers/session_manager.dart';
import 'managers/token_expiry_manager.dart';
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

  /// Debugger and dynamic-library injection detection.
  late final AntiTamper antiTamper;

  /// Live screen recording / mirroring and screenshot monitoring.
  late final ScreenCapture screenCapture;

  /// Local-only, auto-expiring clipboard for sensitive values.
  late final Pasteboard pasteboard;

  /// Public-key / certificate pinning helpers (pinned `HttpClient`, checks).
  late final CertificatePinning certificatePinning;

  /// Biometric / device-credential authentication.
  late final Biometrics biometrics;

  /// String/secret obfuscation and release-build hardening status.
  late final Obfuscation obfuscation;

  /// Access / refresh token persistence on top of secure storage.
  final SecureTokenStorage tokenStorage;

  /// Token expiry tracking and single-flight refresh.
  final TokenExpiryManager tokenExpiry;

  final BiometricRepository _biometricRepository;

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
    required CheckAntiTamperUseCase checkAntiTamper,
    required MonitorScreenCaptureUseCase monitorScreenCapture,
    required PasteboardUseCase pasteboardUseCase,
    required BiometricAuthUseCase biometricAuth,
    required BiometricRepository biometricRepository,
    required this.tokenStorage,
    required this.tokenExpiry,
    required PinningMode pinningMode,
    required SecurityContext? pinningSecurityContext,
  }) : _biometricRepository = biometricRepository,
       _enableRootDetection = enableRootDetection,
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
    antiTamper = AntiTamper._(checkAntiTamper);
    screenCapture = ScreenCapture._(monitorScreenCapture);
    pasteboard = Pasteboard._(pasteboardUseCase);
    certificatePinning = CertificatePinning._(
      certificatePins,
      pinningMode,
      pinningSecurityContext,
      validateCertificate,
    );
    biometrics = Biometrics._(biometricAuth);
    obfuscation = Obfuscation._();
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

    /// What the pins in [certificatePins] are hashes of: the certificate's
    /// public key (default, survives certificate renewal) or the whole
    /// certificate.
    PinningMode pinningMode = PinningMode.publicKey,

    /// Trust store used for pinned connections. Leave `null` to use the
    /// platform trust store; pass one to trust a private CA.
    SecurityContext? pinningSecurityContext,

    /// Prefix for the secure-storage keys used by [tokenStorage] and
    /// [tokenExpiry].
    String tokenNamespace = 'sbk',
  }) {
    if (enableLogging) {
      SecurityLogger.enable();
    }

    final channel = MethodChannelSecurity();

    // Datasources
    final certDs           = CertificatePinningDatasource(
      mode: pinningMode,
      securityContext: pinningSecurityContext,
    );
    final rootDs           = RootDetectionDatasource(channel);
    final screenshotDs     = ScreenshotProtectionDatasource(channel);
    final integrityDs      = AppIntegrityDatasource(channel);
    final storageDs        = SecureStorageDatasource(channel);
    final emulatorDs       = EmulatorDetectionDatasource(channel);
    final recordingDs      = ScreenRecordingDatasource(channel);
    final tamperDs         = TamperDetectionDatasource(channel);
    final runtimeDs        = RuntimeProtectionDatasource(channel);
    final antiTamperDs     = AntiTamperDatasource(channel);
    final screenCaptureDs  = ScreenCaptureDatasource(channel);
    final pasteboardDs     = PasteboardDatasource(channel);
    final biometricDs      = BiometricDatasource(channel);

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
    final antiTamperRepo   = AntiTamperRepositoryImpl(antiTamperDs);
    final captureRepo      = ScreenCaptureRepositoryImpl(screenCaptureDs);
    final pasteboardRepo   = PasteboardRepositoryImpl(pasteboardDs);
    final biometricRepo    = BiometricRepositoryImpl(biometricDs);

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
    final checkAntiTamper  = CheckAntiTamperUseCase(antiTamperRepo);
    final monitorCapture   = MonitorScreenCaptureUseCase(captureRepo);
    final pasteboardUc     = PasteboardUseCase(pasteboardRepo);
    final biometricAuth    = BiometricAuthUseCase(biometricRepo);

    // Managers
    final tokenStorage = SecureTokenStorage(
      storageRepo,
      namespace: tokenNamespace,
    );
    final tokenExpiry = TokenExpiryManager(
      storage: storageRepo,
      tokenStorage: tokenStorage,
    );

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
      checkAntiTamper: checkAntiTamper,
      monitorScreenCapture: monitorCapture,
      pasteboardUseCase: pasteboardUc,
      biometricAuth: biometricAuth,
      biometricRepository: biometricRepo,
      tokenStorage: tokenStorage,
      tokenExpiry: tokenExpiry,
      pinningMode: pinningMode,
      pinningSecurityContext: pinningSecurityContext,
    );
  }

  /// Creates an inactivity-based [SessionManager] wired to this kit's token
  /// storage, so tokens are wiped when the session times out.
  ///
  /// The caller owns the returned manager and must `dispose()` it.
  SessionManager createSessionManager({
    required Duration timeout,
    bool clearTokensOnExpiry = true,
  }) => SessionManager(
    timeout: timeout,
    tokenStorage: tokenStorage,
    tokenExpiry: tokenExpiry,
    clearTokensOnExpiry: clearTokensOnExpiry,
  );

  /// Creates an [AppLockManager] that locks the app when it is backgrounded
  /// and unlocks it with biometrics / device credential.
  ///
  /// Call `start()` on the result to begin observing the app lifecycle and
  /// `dispose()` when done.
  AppLockManager createAppLockManager({
    Duration gracePeriod = Duration.zero,
    bool lockOnStart = false,
    String reason = 'Unlock to continue',
    bool allowDeviceCredential = true,
  }) => AppLockManager(
    biometrics: _biometricRepository,
    gracePeriod: gracePeriod,
    lockOnStart: lockOnStart,
    reason: reason,
    allowDeviceCredential: allowDeviceCredential,
  );

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

/// Sub-accessor for debugger and dynamic-library injection detection.
class AntiTamper {
  final CheckAntiTamperUseCase _useCase;

  AntiTamper._(this._useCase);

  /// Runs both checks.
  Future<SecurityResult<AntiTamperStatus>> check() => _useCase();

  Future<SecurityResult<bool>> isDebuggerAttached() =>
      _useCase.isDebuggerAttached();

  Future<SecurityResult<bool>> hasInjectedLibraries() =>
      _useCase.hasInjectedLibraries();

  /// Asks the OS to refuse debugger attachment for the rest of the process
  /// lifetime. Do not call this in debug builds: on iOS it detaches (and
  /// kills) a debug session.
  Future<SecurityResult<bool>> denyDebuggerAttachment() =>
      _useCase.denyDebuggerAttachment();
}

/// Sub-accessor for live screen-capture monitoring.
class ScreenCapture {
  final MonitorScreenCaptureUseCase _useCase;

  ScreenCapture._(this._useCase);

  /// All capture events (recording / mirroring changes and screenshots).
  Stream<ScreenCaptureEvent> get events => _useCase();

  /// Emits `true` when recording / mirroring starts and `false` when it
  /// stops.
  Stream<bool> get onCaptureChanged => events
      .where((e) => e.type == ScreenCaptureEventType.captureChanged)
      .map((e) => e.isCaptured ?? false);

  /// Emits whenever the user takes a screenshot (iOS, Android 14+).
  Stream<void> get onScreenshot => events
      .where((e) => e.type == ScreenCaptureEventType.screenshot)
      .map<void>((_) {});

  /// Whether the screen is being recorded or mirrored right now.
  Future<SecurityResult<bool>> isCaptured() => _useCase.isCaptured();
}

/// Sub-accessor for the protected clipboard.
class Pasteboard {
  final PasteboardUseCase _useCase;

  Pasteboard._(this._useCase);

  /// Copies [value] as local-only / sensitive and removes it again after
  /// [expiresAfter] (default 60 seconds, at most one hour).
  Future<SecurityResult<void>> copy(
    String value, {
    Duration expiresAfter = PasteboardUseCase.defaultExpiry,
  }) => _useCase.copy(value: value, expiresAfter: expiresAfter);

  /// Clears the clipboard. With [onlyIfOwned] it is only cleared while it
  /// still holds the value written by [copy].
  Future<SecurityResult<bool>> clear({bool onlyIfOwned = false}) =>
      _useCase.clear(onlyIfOwned: onlyIfOwned);
}

/// Sub-accessor for certificate / public-key pinning.
class CertificatePinning {
  final Map<String, List<String>> _pins;
  final PinningMode _mode;
  final SecurityContext? _securityContext;
  final ValidateCertificateUseCase _validate;

  CertificatePinning._(
    this._pins,
    this._mode,
    this._securityContext,
    this._validate,
  );

  /// Builds a [CertificatePinner] from the pins passed to
  /// `SecureBankKit.initialize`.
  ///
  /// Throws [ArgumentError] if a configured host or pin is malformed.
  CertificatePinner pinner({bool rejectUnpinnedHosts = false}) =>
      CertificatePinner(
        pins: _pins,
        mode: _mode,
        rejectUnpinnedHosts: rejectUnpinnedHosts,
      );

  /// Returns an `HttpClient` that refuses connections to pinned hosts whose
  /// certificate does not match a configured pin.
  HttpClient createHttpClient({
    bool rejectUnpinnedHosts = false,
    Duration? connectionTimeout,
  }) => pinner(rejectUnpinnedHosts: rejectUnpinnedHosts).createHttpClient(
    context: _securityContext,
    connectionTimeout: connectionTimeout,
  );

  /// Connects to [host] (optionally `host:port`) and checks its certificate
  /// against [pins], or against the pins configured for that host when
  /// [pins] is omitted.
  Future<SecurityResult<bool>> validate(String host, {List<String>? pins}) =>
      _validate(host: host, pins: pins ?? _pins[host] ?? const []);
}

/// Sub-accessor for biometric authentication.
class Biometrics {
  final BiometricAuthUseCase _useCase;

  Biometrics._(this._useCase);

  Future<SecurityResult<BiometricAvailability>> checkAvailability() =>
      _useCase.checkAvailability();

  /// Shows the system prompt. `Success(true)` = authenticated,
  /// `Success(false)` = cancelled by the user, `Failure` = could not run.
  Future<SecurityResult<bool>> authenticate({
    required String reason,
    bool allowDeviceCredential = true,
    String? cancelLabel,
  }) => _useCase.authenticate(
    reason: reason,
    allowDeviceCredential: allowDeviceCredential,
    cancelLabel: cancelLabel,
  );
}

/// Sub-accessor for obfuscation: scrambling embedded string secrets so they
/// are not visible in the binary, and reporting the build's hardening status.
///
/// ```dart
/// // Hide an embedded constant from static inspection:
/// final token = kit.obfuscation.obfuscator('build-seed').obfuscate('api-key');
///
/// // Refuse sensitive flows in a build that was not hardened:
/// if (!kit.obfuscation.buildStatus.isHardened) {
///   // debug / un-obfuscated build shipped by mistake
/// }
/// ```
class Obfuscation {
  final BuildHardeningInspector _inspector;

  Obfuscation._({BuildHardeningInspector inspector = const BuildHardeningInspector()})
    : _inspector = inspector;

  /// Returns a [StringObfuscator] seeded with [secret]. Use the same
  /// [secret] to `obfuscate` a value offline and `reveal` it at runtime.
  StringObfuscator obfuscator(String secret) => StringObfuscator(secret);

  /// How the running build was compiled (release/debug/profile and whether
  /// Dart symbols look obfuscated). See [ObfuscationStatus].
  ObfuscationStatus get buildStatus => _inspector.inspect();
}
