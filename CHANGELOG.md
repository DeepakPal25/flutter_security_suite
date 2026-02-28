# Changelog

All notable changes to this project will be documented in this file.

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
