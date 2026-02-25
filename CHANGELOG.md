# Changelog

All notable changes to this project will be documented in this file.

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
