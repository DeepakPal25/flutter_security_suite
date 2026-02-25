# Flutter Security Suite (SecureBankKit)

A comprehensive, enterprise-grade Flutter security plugin providing root/jailbreak detection, certificate pinning, app integrity verification, screenshot protection, and encrypted secure storage.

Built with **Clean Architecture** principles and full native support for both **Android** (Kotlin) and **iOS** (Swift).

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.10.0-02569B.svg)](https://flutter.dev)

---

## Features

| Feature | Android | iOS | Description |
|---------|---------|-----|-------------|
| Root/Jailbreak Detection | su binary & app detection | Cydia, dylib scanning, file checks | Detects compromised devices |
| Certificate Pinning | SHA-256 fingerprint validation | SHA-256 fingerprint validation | Prevents MITM attacks |
| App Integrity | Debug flag & installer validation | Debugger & provisioning checks | Detects tampering |
| Screenshot Protection | `FLAG_SECURE` window flag | Secure UITextField overlay | Blocks screen capture |
| Secure Storage | EncryptedSharedPreferences (AES-256) | iOS Keychain (SecItem API) | Encrypted key-value storage |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│   PUBLIC API (SecureBankKit)                 │  Consumer-facing facade
├─────────────────────────────────────────────┤
│   DOMAIN (Entities, UseCases, Repositories) │  Business logic & contracts
├─────────────────────────────────────────────┤
│   DATA (Datasources, Repository Impls)      │  Implementation layer
├─────────────────────────────────────────────┤
│   PLATFORM (MethodChannel Bridge)           │  Flutter ↔ Native bridge
├─────────────────────────────────────────────┤
│   CORE (Result types, Exceptions, Logger)   │  Shared utilities
└─────────────────────────────────────────────┘
```

---

## Getting Started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_security_suite:
    git:
      url: https://github.com/DeepakPal25/flutter_security_suite.git
```

### Platform Setup

**Android** - No additional setup required. Min SDK: 21.

**iOS** - Minimum deployment target: iOS 12.0. If using jailbreak detection with Cydia URL scheme check, add to your `Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>cydia</string>
</array>
```

---

## Usage

### Initialize

```dart
import 'package:flutter_security_suite/flutter_security_suite.dart';

final kit = SecureBankKit.initialize(
  enableRootDetection: true,
  enableAppIntegrity: true,
  enablePinning: false,
  enableLogging: false,
  certificatePins: {},
);
```

### Run Security Check

```dart
final status = await kit.runSecurityCheck();

if (status.isSecure) {
  // Device is clean - proceed normally
} else {
  if (status.isRooted) print('Device is rooted/jailbroken');
  if (!status.isAppIntegrityValid) print('App integrity compromised');
  if (!status.isCertificatePinningValid) print('Certificate pinning failed');
}
```

### Certificate Pinning

```dart
final kit = SecureBankKit.initialize(
  enablePinning: true,
  certificatePins: {
    'api.example.com': ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
  },
);

final status = await kit.runSecurityCheck();
print('Certificate valid: ${status.isCertificatePinningValid}');
```

### Screenshot Protection

```dart
// Block screenshots and screen recording
await kit.screenshotProtection.enable();

// Re-enable screenshots
await kit.screenshotProtection.disable();
```

### Secure Storage

```dart
// Write encrypted data
await kit.secureStorage.write(key: 'auth_token', value: 'jwt_abc123');

// Read decrypted data
final token = await kit.secureStorage.read(key: 'auth_token');

// Delete a key
await kit.secureStorage.delete(key: 'auth_token');

// Clear all stored data
await kit.secureStorage.deleteAll();
```

### Error Handling

The plugin uses a type-safe `SecurityResult<T>` sealed class:

```dart
final result = await someSecurityOperation();

result.fold(
  onSuccess: (data) => print('Result: $data'),
  onFailure: (error) => print('Error: ${error.message}'),
);

// Or use convenience accessors
if (result.isSuccess) {
  final value = result.dataOrNull;
}
```

---

## How It Works

### Root/Jailbreak Detection

**Android:**
- Scans system paths for `su` binaries (`/sbin/su`, `/system/bin/su`, etc.)
- Detects rooting apps (SuperSU, Magisk Manager, etc.)
- Checks build tags for `test-keys`

**iOS:**
- Checks for known jailbreak files (Cydia, MobileSubstrate, bash, ssh, apt)
- Scans loaded dylibs for suspicious modules (FridaGadget, SubstrateLoader, etc.)
- Tests Cydia URL scheme availability
- Attempts writing to restricted `/private/` paths

### App Integrity

**Android:**
- Verifies the app is not marked as debuggable
- Validates installer source (Google Play, Amazon, Huawei)

**iOS:**
- Detects debugger attachment via `sysctl` (P_TRACED flag)
- Checks for `embedded.mobileprovision` file presence

### Secure Storage

**Android:** Uses `EncryptedSharedPreferences` with:
- Key encryption: AES-256-SIV
- Value encryption: AES-256-GCM

**iOS:** Uses Keychain via `SecItem` API with:
- Accessibility: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

---

## Project Structure

```
flutter_security_suite/
├── lib/
│   ├── flutter_security_suite.dart       # Main export
│   ├── secure_bank_kit.dart              # Public API facade
│   ├── core/
│   │   ├── exceptions/                   # SecurityException hierarchy
│   │   ├── result/                       # SecurityResult sealed class
│   │   └── utils/                        # Logger utility
│   ├── domain/
│   │   ├── entities/                     # SecurityStatus entity
│   │   ├── repositories/                 # 5 abstract repository contracts
│   │   └── usecases/                     # 5 use cases
│   ├── data/
│   │   ├── datasources/                  # 5 datasource implementations
│   │   └── repositories_impl/           # 5 repository implementations
│   └── platform/
│       └── method_channel_security.dart  # MethodChannel bridge
├── android/src/main/kotlin/              # Kotlin native handlers
├── ios/Classes/                          # Swift native handlers
├── example/                              # Demo application
└── test/                                 # 11 test files (47 tests)
```

---

## Testing

Run all tests:

```bash
flutter test
```

**Coverage:**
- **Platform layer** - MethodChannel mock tests for all method calls
- **Domain layer** - UseCase tests with mocked repositories (success & failure paths)
- **Data layer** - Repository implementation tests with mocked datasources

---

## Requirements

| | Minimum |
|---|---|
| Flutter | >= 3.10.0 |
| Dart SDK | >= 3.10.4 |
| Android | API 21 (Lollipop) |
| iOS | 12.0 |

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
