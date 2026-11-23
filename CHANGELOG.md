# Changelog

All notable changes to this project will be documented in this file.

## 1.3.0 - 2026-11-23

### Added
- **String obfuscation** (`kit.obfuscation.obfuscator(secret)`): reversible SHA-256 keystream (counter mode) XOR obfuscation for embedded string constants (API URLs, keys, feature flags), with a fresh random salt per call and Base64Url output. Pure Dart, no platform channel. Documented as obfuscation, not encryption.
- **Build hardening status** (`kit.obfuscation.buildStatus`): reports `isReleaseBuild` / `isDebugBuild` / `isProfileBuild` and a best-effort `symbolsLikelyStripped` heuristic for `--obfuscate`, with an `isHardened` convenience getter. Exposed via the new `ObfuscationStatus` entity and `BuildHardeningInspector`.

## 1.2.0 - 2026-11-15

### Added
- **Anti-tamper detection** (`kit.antiTamper`): debugger detection, injected-library detection (Frida, Substrate, Xposed, …) and `denyDebuggerAttachment()` (iOS `PT_DENY_ATTACH`).
- **Screen capture monitoring** (`kit.screenCapture`): `isCaptured()` plus `events`, `onCaptureChanged` and `onScreenshot` streams for recording / mirroring changes and screenshots.
- **Pasteboard protection** (`kit.pasteboard`): local-only, auto-expiring clipboard copy and `clear({onlyIfOwned})`.
- **Biometric authentication** (`kit.biometrics`): `checkAvailability()` and `authenticate()` with optional device-credential fallback and typed `BiometricException` error codes.
- **Secure token storage** (`kit.tokenStorage`) and **token expiry management** (`kit.tokenExpiry`) with de-duplicated `refreshIfNeeded()`.
- **SessionManager** (`kit.createSessionManager`): inactivity timeout that can wipe tokens on expiry.
- **AppLockManager** (`kit.createAppLockManager`): locks the app after a background grace period and unlocks with biometrics.
- **CertificatePinner** / `kit.certificatePinning.pinner()` and `createHttpClient()` for SPKI public-key pinning on every connection.
- `SecurityLogger.redact()` and `SecurityLogger.sanitize()`.

### Changed
- `SecurityLogger` is silent in release builds unless enabled with `enable(allowInRelease: true)`.
- Certificate pin validation is stricter: malformed or empty pin lists throw `ArgumentError` instead of silently never matching.
- Minimum SDK constraints raised to match what the code actually needs: Flutter `>=3.22.0`, Dart `>=3.4.0` (example app: Flutter `>=3.27.0`).
- Android: added `androidx.biometric` dependency and the `DETECT_SCREEN_CAPTURE` permission (API 34+ screenshot detection).

### Fixed
- Android: release builds no longer fail in R8 with "Missing class" errors from Tink; the plugin now ships consumer ProGuard rules.
- iOS: Swift Package Manager product renamed to `flutter-security-suite` so apps with SwiftPM enabled can resolve the plugin.

### Setup notes
- Biometrics on Android require the host activity to extend `FlutterFragmentActivity`.
- Biometrics on iOS require `NSFaceIDUsageDescription` in `Info.plist`.

## 1.1.1 - 2026-03-25

### Fixed

- Shortened pubspec description to comply with pub.dev 60–180 character guideline

## 1.1.0 - 2026-03-07

### Added

- Emulator / simulator detection (Android: Build props + QEMU device files; iOS: `targetEnvironment(simulator)` + Simulator env vars)
- Screen recording detection (Android: `DisplayManager` presentation display check; iOS: `UIScreen.isCaptured`)
- Tamper detection (Android: APK signing certificate verification + `getSigningCertificateHash()`; iOS: bundle ID consistency + `_CodeSignature` directory check)
- Runtime protection: Frida server port check, `/proc/self/maps` scan, Xposed files (Android); Frida dylib scan + env vars (iOS); debugger detection on both platforms
- `SecurityStatus` gains 4 new fields: `isEmulator`, `isScreenBeingRecorded`, `isTampered`, `isRuntimeHooked`
- `TamperDetection` sub-accessor on `SecureBankKit` exposes `getSignatureHash()` for one-time certificate pinning setup
- 34 new unit tests (81 total, all passing)
- Updated example app with status cards and new feature buttons


## 1.0.5 - 2026-03-04

### Changed

- Removed all third-party package references from README and CHANGELOG

## 1.0.4 - 2026-03-03

### Changed

- Removed "enterprise-grade" marketing language from package description and README
- Added **Limitations** section documenting root-detection bypass vectors, Dart-only pinning scope, iOS screenshot gaps, and absence of active threat-intel feed
- Fixed README installation snippet (was showing git URL instead of pub.dev dependency)
- Fixed README SDK minimum version (was `3.10.4`, actual constraint is `3.0.0`)
- Fixed README Android min SDK (was API 21, actual requirement is API 23 for EncryptedSharedPreferences)
- Added SPKI pin extraction shell command to certificate pinning docs
- Removed personal GitHub funding link from pubspec

## 1.0.3 - 2026-02-28

### Fixed

- **Dart**: Fixed invalid `sdk: ^3.10.4` constraint (was unresolvable) to `>=3.0.0 <4.0.0`
- **Dart**: Fixed `flutter_lints: ^6.0.0` (non-existent version) to `^4.0.0`
- **Dart**: Certificate pinning now hashes the Subject Public Key Info (SPKI) instead of the full DER certificate — pins now survive certificate renewals when the key pair stays the same
- **Dart**: Added 10-second connection timeout to certificate pinning HTTP client
- **Dart**: Fixed response body drain when certificate is `null` (connection leak)
- **Dart**: Root check fail-safe now defaults to `true` (assumed rooted) on platform error instead of `false`
- **Android**: Migrated `SecureStorageHandler` from deprecated `MasterKeys` API to `MasterKey.Builder`; instance is now cached in a thread-safe singleton
- **Android**: Replaced `Runtime.exec()` shell command in `RootDetectionHandler` with `PackageManager.getPackageInfo()` — fixes resource leak and broken behaviour on API 30+ (SELinux blocks shell exec)
- **Android**: Added `<queries>` entries to `AndroidManifest.xml` for root-app package visibility on Android 11+
- **Android**: Fixed activity TOCTOU race in screenshot handler by capturing activity reference before `runOnUiThread` lambda
- **Android**: Set `minSdk=23` (required by security-crypto) and `targetSdk=34`
- **iOS**: Removed incorrect `window.layer` sublayer manipulation in `ScreenshotHandler` that caused visual corruption
- **iOS**: `ScreenshotHandler.enable/disable` now accept a completion callback so the Flutter result is sent only after protection is actually applied
- **iOS**: `AppIntegrityHandler.isAppIntegrityValid()` now only checks for debugger attachment — provisioning profile check moved to new `isAppStoreBuild()` method so TestFlight builds are no longer incorrectly blocked
- **iOS**: Renamed `checkFork()` to `checkCydiaInstalled()` with accurate documentation about `LSApplicationQueriesSchemes` requirement
- **iOS**: `delete()` and `deleteAll()` in `SecureBankKitPlugin` now properly report keychain errors to Dart
- **iOS**: Fixed `Package.swift` library name from `flutter-security-suite` (hyphen) to `flutter_security_suite` — SPM integration was silently broken
- **iOS**: Synced podspec version to `1.0.3`
- **Tests**: Added `verify()` call to failure-path tests in use case test suite
- **Tests**: Replaced empty `RunnerTests.testExample()` with an actual assertion

## 1.0.2 - 2026-02-25

### Improved

- Added Swift Package Manager support for iOS (Package.swift)
- Added PrivacyInfo.xcprivacy manifest for iOS privacy compliance
- Fixed dart formatting across all source and test files
- Migrated iOS source files to SPM-compatible directory structure

## 1.0.1 - 2026-02-25

### Fixed

- Updated iOS podspec homepage and author metadata
- Added pub.dev topics for better discoverability (security, encryption, root-detection, certificate-pinning, storage)
- Added funding link

## 1.0.0 - 2026-02-25

### Added

- **Root/Jailbreak Detection**
  - Android: su binary scanning, rooting app detection, build tag validation
  - iOS: Jailbreak file checks, dylib scanning, Cydia URL scheme detection, restricted path write test

- **Certificate Pinning**
  - SHA-256 fingerprint validation against configurable pin sets
  - Pure-Dart HTTPS implementation with per-host pin support

- **App Integrity Verification**
  - Android: Debuggable flag check, installer source validation (Google Play, Amazon, Huawei)
  - iOS: Debugger attachment detection via sysctl, provisioning profile check

- **Screenshot Protection**
  - Android: FLAG_SECURE window flag management
  - iOS: Secure UITextField overlay to block screen capture

- **Secure Storage**
  - Android: EncryptedSharedPreferences with AES-256-GCM/SIV encryption
  - iOS: Keychain storage via SecItem API with device-only accessibility

- **Clean Architecture**
  - Core layer with type-safe `SecurityResult<T>` sealed class, exception hierarchy, and logger
  - Domain layer with entities, repository contracts, and use cases
  - Data layer with datasources and repository implementations
  - Platform layer with MethodChannel bridge (`com.securebankkit/security`)
  - Public API facade (`SecureBankKit`) with factory initialization

- **Testing**
  - 47 unit tests covering platform, domain, and data layers
  - Full success and failure path coverage

- **Example App**
  - Material 3 demo app demonstrating all security features
  - Android and iOS platform support

- **Project**
  - MIT License
  - Comprehensive README with architecture docs and usage examples
