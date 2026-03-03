# flutter_security_suite

A Flutter plugin for mobile app security, providing root/jailbreak detection, certificate pinning, app integrity verification, screenshot protection, and encrypted secure storage — with native implementations for Android (Kotlin) and iOS (Swift).

[![pub.dev](https://img.shields.io/pub/v/flutter_security_suite.svg)](https://pub.dev/packages/flutter_security_suite)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)]()

> **Note:** This is an open-source project maintained by an individual developer. For applications with strict compliance requirements (banking, healthcare, payments), also evaluate [freeRASP by Talsec](https://pub.dev/packages/freerasp) — a vendor-backed solution with active threat intelligence updates.

---

## Features

| Feature | Android | iOS |
|---------|---------|-----|
| Root/Jailbreak Detection | su binary & app detection | Cydia, dylib scanning, file checks |
| Certificate Pinning | SHA-256 SPKI fingerprint | SHA-256 SPKI fingerprint |
| App Integrity | Debug flag & installer validation | Debugger detection via sysctl |
| Screenshot Protection | `FLAG_SECURE` window flag | Secure UITextField overlay |
| Secure Storage | EncryptedSharedPreferences (AES-256) | iOS Keychain (SecItem API) |

---

## Alternatives

Before choosing this package, consider which tool fits your needs:

| Package | Maintained by | Best for |
|---------|--------------|----------|
| **flutter_security_suite** (this) | Individual (open-source) | Learning, prototypes, open auditing |
| [freerasp](https://pub.dev/packages/freerasp) | Talsec (company) | Production apps requiring active threat intel |
| [flutter_ios_security_suite](https://pub.dev/packages/flutter_ios_security_suite) | Individual (open-source) | iOS-only jailbreak checks |

---

## Limitations & Security Considerations

- **Root/jailbreak detection is heuristic.** Determined attackers with advanced tooling (e.g. Magisk with Zygisk modules) can bypass file-based and package-based checks. This package provides a reasonable baseline, not a guarantee.
- **Certificate pinning is implemented in pure Dart** over a raw `SecureSocket`. It does not intercept traffic from native SDKs, WebViews, or third-party libraries that open their own connections.
- **Screenshot protection on iOS** uses a `UITextField` overlay, which blocks the standard iOS screenshot API. It does not prevent screen recording via QuickTime or AirPlay mirroring.
- **This package has no affiliation with any financial institution or payment network.** The internal `SecureBankKit` naming is a legacy implementation detail, not a certification.
- **No active threat-intelligence feed.** New bypass techniques will not be addressed automatically; you must update the package manually.

---

## Getting Started

### Installation

```yaml
dependencies:
  flutter_security_suite: ^1.0.3
```

### Platform Setup

**Android** — No additional setup required. Min SDK: 23.

**iOS** — Minimum deployment target: iOS 12.0. If using jailbreak detection with the Cydia URL scheme check, add to your `Info.plist`:

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

Pin the **Subject Public Key Info (SPKI)** SHA-256 hash. This survives certificate renewals as long as the key pair stays the same.

```dart
final kit = SecureBankKit.initialize(
  enablePinning: true,
  certificatePins: {
    'api.example.com': ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
  },
);
```

To extract the SPKI pin from a live host:

```bash
openssl s_client -connect api.example.com:443 -servername api.example.com 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64
```

### Screenshot Protection

```dart
await kit.screenshotProtection.enable();
await kit.screenshotProtection.disable();
```

### Secure Storage

```dart
await kit.secureStorage.write(key: 'auth_token', value: 'jwt_abc123');
final token = await kit.secureStorage.read(key: 'auth_token');
await kit.secureStorage.delete(key: 'auth_token');
await kit.secureStorage.deleteAll();
```

### Error Handling

```dart
final result = await someSecurityOperation();

result.fold(
  onSuccess: (data) => print('Result: $data'),
  onFailure: (error) => print('Error: ${error.message}'),
);

if (result.isSuccess) {
  final value = result.dataOrNull;
}
```

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

## How It Works

### Root/Jailbreak Detection

**Android:**
- Scans system paths for `su` binaries (`/sbin/su`, `/system/bin/su`, etc.)
- Detects rooting apps via `PackageManager` (SuperSU, Magisk, etc.)
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
- `isAppStoreBuild()` checks for absence of `embedded.mobileprovision` (distinguishes App Store from TestFlight/dev builds)

### Secure Storage

**Android:** `EncryptedSharedPreferences` — key encryption: AES-256-SIV, value encryption: AES-256-GCM

**iOS:** Keychain via `SecItem` API — accessibility: `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

---

## Project Structure

```
flutter_security_suite/
├── lib/
│   ├── flutter_security_suite.dart       # Main export
│   ├── secure_bank_kit.dart              # Public API facade
│   ├── core/                             # SecurityResult, exceptions, logger
│   ├── domain/                           # Entities, use cases, repository contracts
│   ├── data/                             # Datasource & repository implementations
│   └── platform/
│       └── method_channel_security.dart  # MethodChannel bridge
├── android/src/main/kotlin/              # Kotlin native handlers
├── ios/Classes/                          # Swift native handlers
├── example/                              # Demo application
└── test/                                 # 11 test files, 47 unit tests
```

---

## Testing

```bash
flutter test
```

Coverage includes platform (MethodChannel mocks), domain (use cases with mocked repositories), and data (repository impls with mocked datasources) layers — both success and failure paths.

---

## Requirements

| | Minimum |
|---|---|
| Flutter | >= 3.10.0 |
| Dart SDK | >= 3.0.0 |
| Android | API 23 (Marshmallow) |
| iOS | 12.0 |

---

## Contributing

Contributions and bug reports are welcome. Please open an issue before submitting a large pull request.

---

## License

MIT — see [LICENSE](LICENSE).