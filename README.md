# flutter_security_suite

A Flutter plugin for mobile app security — root/jailbreak, emulator, tamper and debugger detection, runtime protection, certificate (public-key) pinning, screen capture monitoring and screenshot protection, clipboard protection, biometric authentication with app lock, session timeout, and encrypted token storage. Native implementations for Android (Kotlin) and iOS (Swift).

[![pub.dev](https://img.shields.io/pub/v/flutter_security_suite.svg)](https://pub.dev/packages/flutter_security_suite)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)]()

---

## Features

| Feature | Android | iOS |
|---------|---------|-----|
| Root / Jailbreak Detection | `su` binary & dangerous-app detection | Cydia, dylib scan, writable-path check |
| **Emulator Detection** | Build props + QEMU device files | `targetEnvironment(simulator)` + env vars |
| **Screen Recording Detection** | `DisplayManager` presentation display check | `UIScreen.isCaptured` (iOS 11+) |
| **Tamper Detection** | APK signing-cert presence + SHA-256 hash | Bundle ID mismatch + `_CodeSignature` check |
| **Runtime Protection** | Frida port, `/proc/maps`, Xposed, debugger | Frida port, dylib scan, Frida env vars |
| Certificate Pinning | SHA-256 SPKI fingerprint | SHA-256 SPKI fingerprint |
| App Integrity | Debug flag & installer validation | Debugger detection via `sysctl` |
| Screenshot Protection | `FLAG_SECURE` window flag | Secure `UITextField` overlay |
| Secure Storage | EncryptedSharedPreferences (AES-256) | iOS Keychain (`SecItem` API) |
| **Anti-Tamper Detection** | `Debug.isDebuggerConnected`, `TracerPid`, `/proc/self/maps` scan | `sysctl` `P_TRACED`, dyld image scan, `PT_DENY_ATTACH` |
| **Screen Capture Monitoring** | Presentation displays + screenshot callback (API 34+) | `UIScreen.capturedDidChange` + screenshot notification |
| **Pasteboard Protection** | `EXTRA_IS_SENSITIVE` (API 33+) + timed clear | `UIPasteboard` `localOnly` + `expirationDate` |
| **Biometric Authentication** | `BiometricPrompt` | `LAContext` (Face ID / Touch ID / passcode) |
| **Token Storage & Expiry** | Built on Secure Storage | Built on Secure Storage |
| **Session Manager / App Lock** | Dart (inactivity timer, lifecycle observer) | Dart (inactivity timer, lifecycle observer) |
| **Redacting Logger** | `SecurityLogger.redact()` — off in release builds | same |

---

## Limitations & Security Considerations

- **Root/jailbreak detection is heuristic.** Advanced tooling such as Magisk with Zygisk modules can bypass file-based and package-based checks. This package provides a strong baseline, not a guarantee.
- **Emulator detection on Android is heuristic.** Build property spoofing can defeat it; the iOS Simulator check (`#if targetEnvironment(simulator)`) is compile-time reliable.
- **Screen recording detection on Android** detects mirroring/casting via virtual displays. Local file recording (e.g. the built-in screen recorder writing to MP4) cannot be reliably detected at the application level — use `FLAG_SECURE` (`screenshotProtection.enable()`) as the primary mitigation.
- **Tamper detection** catches unsophisticated repacking. A skilled attacker can re-sign an app and produce a valid `_CodeSignature`. For stronger guarantees use Google Play Integrity API / Apple App Attest in addition to this package.
- **Runtime protection checks can themselves be hooked** if Frida is already running. Layers of obfuscation and server-side attestation complement these checks.
- **Certificate pinning is implemented in pure Dart** over a raw `SecureSocket`. It does not intercept traffic from native SDKs, WebViews, or third-party libraries that manage their own connections.
- **No active threat-intelligence feed.** New bypass techniques will not be addressed automatically; update the package to get the latest checks.

---

## Getting Started

### Installation

```yaml
dependencies:
  flutter_security_suite: ^1.2.0
```

### Platform Setup

**Android** — Min SDK: 23. No setup is needed unless you use biometrics (or `AppLockManager`), in which case your activity must extend `FlutterFragmentActivity`:

```kotlin
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity()
```

The plugin declares the `DETECT_SCREEN_CAPTURE` permission; screenshot events are only delivered on Android 14 (API 34) and newer.

**iOS** — Minimum deployment target: iOS 12.0. For jailbreak detection with the Cydia URL scheme, add to `Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
    <string>cydia</string>
</array>
```

For Face ID (biometrics / app lock), also add:

```xml
<key>NSFaceIDUsageDescription</key>
<string>Unlock the app with Face ID.</string>
```

---

## Usage

### Initialize

```dart
import 'package:flutter_security_suite/flutter_security_suite.dart';

final kit = SecureBankKit.initialize(
  enableRootDetection: true,
  enableAppIntegrity: true,
  enableEmulatorDetection: true,
  enableScreenRecordingDetection: false, // opt-in
  enableTamperDetection: true,
  enableRuntimeProtection: true,
  enablePinning: false,
  enableLogging: false,
  certificatePins: {},
);
```

### Run a Full Security Check

```dart
final status = await kit.runSecurityCheck();

if (status.isSecure) {
  // All enabled checks passed — proceed normally.
} else {
  if (status.isRooted)              print('Device is rooted / jailbroken');
  if (status.isEmulator)            print('Running on emulator / simulator');
  if (status.isScreenBeingRecorded) print('Screen is being recorded');
  if (status.isTampered)            print('App has been tampered with');
  if (status.isRuntimeHooked)       print('Runtime hooking framework detected');
  if (!status.isAppIntegrityValid)  print('App integrity check failed');
  if (!status.isCertificatePinningValid) print('Certificate pinning failed');
}
```

### Emulator Detection

```dart
final status = await kit.runSecurityCheck();
if (status.isEmulator) {
  // Block automated attacks or reverse-engineering sessions.
}
```

### Screen Recording Detection

```dart
final status = await kit.runSecurityCheck();
if (status.isScreenBeingRecorded) {
  // Show warning overlay or temporarily hide sensitive content.
}
```

### Tamper Detection

```dart
final status = await kit.runSecurityCheck();
if (status.isTampered) {
  // APK / IPA has been re-signed or modified — terminate session.
}
```

**One-time setup — discover your signing certificate hash:**

```dart
// Run this once in a debug build to find your SHA-256 cert fingerprint.
final result = await kit.tamperDetection.getSignatureHash();
result.fold(
  onSuccess: (hash) => print('Pin this in your config: $hash'),
  onFailure: (e)    => print('Error: ${e.message}'),
);
```

### Runtime Protection

```dart
final status = await kit.runSecurityCheck();
if (status.isRuntimeHooked) {
  // Frida / Xposed / debugger detected — abort sensitive operations.
}
```

### Certificate Pinning

Pin the **Subject Public Key Info (SPKI)** SHA-256 hash. This survives certificate renewals as long as the key pair is unchanged.

```dart
final kit = SecureBankKit.initialize(
  enablePinning: true,
  certificatePins: {
    'api.example.com': ['sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='],
  },
);
```

Extract the SPKI pin from a live host:

```bash
openssl s_client -connect api.example.com:443 -servername api.example.com 2>/dev/null \
  | openssl x509 -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64
```

To actually enforce the pins on your traffic, use the pinned `HttpClient` (a `SecurityContext` passed to `initialize` is reused):

```dart
final client = kit.certificatePinning.createHttpClient(
  rejectUnpinnedHosts: true, // optional: block hosts with no pins at all
);

// One-off check of a host against its configured pins:
final ok = await kit.certificatePinning.validate('api.example.com');
```

Notes:

- `dart:io` only exposes the **leaf** certificate, so pins must be leaf pins — always ship a backup pin for your next key.
- Connections through an HTTP proxy tunnel are refused for pinned hosts.
- Malformed pins or an empty pin list throw `ArgumentError` instead of silently never matching.
- `pinningMode: PinningMode.certificate` pins the whole certificate instead (breaks on every renewal).

### Anti-Tamper Detection

```dart
final result = await kit.antiTamper.check();
result.fold(
  onSuccess: (status) {
    if (status.isCompromised) {
      // status.isDebuggerAttached / status.hasInjectedLibraries
    }
  },
  onFailure: (e) => print(e.message),
);

// iOS: ask the kernel to refuse debugger attachment (no-op in debug builds).
await kit.antiTamper.denyDebuggerAttachment();
```

### Screen Capture Monitoring

```dart
final sub = kit.screenCapture.onCaptureChanged.listen((isCaptured) {
  // show / hide a privacy overlay
});
kit.screenCapture.onScreenshot.listen((_) => print('screenshot taken'));

final captured = await kit.screenCapture.isCaptured();

await sub.cancel(); // in dispose()
```

### Pasteboard Protection

```dart
await kit.pasteboard.copy(
  accountNumber,
  expiresAfter: const Duration(seconds: 30), // default: 60 s
);
await kit.pasteboard.clear(onlyIfOwned: true);
```

On iOS the value is local-only (no Universal Clipboard) and expires natively. On Android the clip is flagged sensitive and cleared by a timer; Android 10+ only lets the foreground app touch the clipboard, so the clear may be skipped while the app is in the background.

### Biometric Authentication

```dart
final availability = await kit.biometrics.checkAvailability();

final result = await kit.biometrics.authenticate(
  reason: 'Confirm the transfer',
  allowDeviceCredential: true, // passcode / PIN fallback
);
result.fold(
  onSuccess: (authenticated) {/* false = user cancelled */},
  onFailure: (e) {/* e.code: BIOMETRIC_NOT_AVAILABLE, BIOMETRIC_LOCKED_OUT, … */},
);
```

### Tokens, Sessions and App Lock

```dart
await kit.tokenStorage.saveTokens(accessToken: access, refreshToken: refresh);
await kit.tokenExpiry.setExpiresIn(const Duration(minutes: 15));

// Refreshes only when (nearly) expired; concurrent callers share one refresh.
final token = await kit.tokenExpiry.refreshIfNeeded(
  (refreshToken) async {
    final r = await api.refresh(refreshToken!);
    return RefreshedTokens(
      accessToken: r.accessToken,
      refreshToken: r.refreshToken,
      expiresAt: r.expiresAt,
    );
  },
  buffer: const Duration(minutes: 1),
);

// Inactivity timeout — wipes tokens when it fires.
final session = kit.createSessionManager(timeout: const Duration(minutes: 5));
session.onSessionExpired.listen((_) => goToLogin());
session.startSession();
session.recordActivity(); // call on user interaction

// Lock after 30 s in the background, unlock with biometrics.
final appLock = kit.createAppLockManager(
  gracePeriod: const Duration(seconds: 30),
  reason: 'Unlock to continue',
)..start();
appLock.lockStateChanges.listen((locked) {/* show lock screen */});
await appLock.unlock();
```

Dispose both managers (`dispose()`) when you are done with them.

### Logging and Redaction

Logging is off by default and stays off in release builds unless you call `SecurityLogger.enable(allowInRelease: true)`.

```dart
SecurityLogger.redact('4111111111111111', visibleEnd: 4); // ****1111
SecurityLogger.redact(null);                              // null
```

### Screenshot Protection

```dart
await kit.screenshotProtection.enable();
await kit.screenshotProtection.disable();
```

> **Tip:** Combine with screen recording detection. Enable protection to make the screen appear black in recordings even when `isScreenBeingRecorded` is `true`.

### Secure Storage

```dart
await kit.secureStorage.write(key: 'auth_token', value: 'jwt_abc123');
final token = await kit.secureStorage.read(key: 'auth_token');
await kit.secureStorage.delete(key: 'auth_token');
await kit.secureStorage.deleteAll();
```

### Error Handling

All operations return a `SecurityResult<T>`:

```dart
final result = await someSecurityOperation();

result.fold(
  onSuccess: (data) => print('Result: $data'),
  onFailure: (error) => print('Error: ${error.message}'),
);

// Or use the null-safe helper:
final value = result.dataOrNull;
```

---

## SecurityStatus Fields

| Field | Type | Meaning |
|---|---|---|
| `isSecure` | `bool` | `true` only when all enabled checks pass |
| `isRooted` | `bool` | Device is rooted (Android) or jailbroken (iOS) |
| `isEmulator` | `bool` | Running on an emulator or iOS Simulator |
| `isScreenBeingRecorded` | `bool` | Screen is being captured or mirrored |
| `isTampered` | `bool` | App bundle / APK shows signs of tampering |
| `isRuntimeHooked` | `bool` | Frida / Xposed / debugger is active |
| `isAppIntegrityValid` | `bool` | App is not debuggable and from a trusted source |
| `isCertificatePinningValid` | `bool` | TLS certificate matches the pinned SPKI hash |

---

## Architecture

```
┌─────────────────────────────────────────────┐
│   PUBLIC API (SecureBankKit)                │  Consumer-facing facade
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

### Root / Jailbreak Detection

**Android:** Scans system paths for `su` binaries, detects rooting apps via PackageManager (SuperSU, Magisk, etc.), checks build tags for `test-keys`.

**iOS:** Checks for Cydia/jailbreak files, scans loaded dylibs for Substrate/Frida/Cycript, tests Cydia URL scheme, attempts writes to restricted `/private/` paths.

### Emulator Detection

**Android:** Inspects `Build.FINGERPRINT`, `Build.MODEL`, `Build.HARDWARE` (goldfish/ranchu), `Build.MANUFACTURER` (Genymotion) and QEMU-specific device files.

**iOS:** Compile-time `#if targetEnvironment(simulator)` flag plus runtime check of Simulator-specific environment variables (`SIMULATOR_DEVICE_NAME`, `SIMULATOR_UDID`).

### Screen Recording Detection

**iOS:** `UIScreen.main.isCaptured` returns `true` when the screen is recorded via ReplayKit, mirrored via AirPlay, or captured via QuickTime/Xcode USB.

**Android:** `DisplayManager.getDisplays(DISPLAY_CATEGORY_PRESENTATION)` — non-empty means a virtual display exists for casting/mirroring.

### Tamper Detection

**Android:** Verifies the APK signing certificate is present via `PackageManager.GET_SIGNING_CERTIFICATES`. Exposes `getSigningCertificateHash()` (SHA-256 hex) for custom certificate pinning.

**iOS:** Checks `Bundle.bundleIdentifier` matches `CFBundleIdentifier` in `Info.plist`, and verifies the `_CodeSignature/` directory exists in the app bundle.

### Runtime Protection

**Both platforms:** Attempts TCP connection to Frida server port `27042`; scans loaded dylibs / `/proc/self/maps` for Frida strings; checks Xposed framework files (Android); checks Frida environment variables (iOS); detects attached debugger.

### App Integrity

**Android:** Verifies `FLAG_DEBUGGABLE` is absent and installer is a trusted store (Google Play, Amazon, Huawei).

**iOS:** Detects debugger via `sysctl` P_TRACED flag. `isAppStoreBuild()` additionally checks for absence of `embedded.mobileprovision`.

### Certificate Pinning

Pins the SHA-256 SPKI fingerprint. Verified in Dart before the HTTP request body is sent. Survives certificate renewal if the key pair is unchanged.

### Secure Storage

**Android:** `EncryptedSharedPreferences` — AES-256-SIV key encryption, AES-256-GCM value encryption.

**iOS:** Keychain via `SecItem` API — accessibility `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

---

## Project Structure

```
flutter_security_suite/
├── lib/
│   ├── flutter_security_suite.dart        # Main export
│   ├── secure_bank_kit.dart               # Public API facade
│   ├── core/                              # SecurityResult, exceptions, logger, CertificatePinner
│   ├── managers/                          # Token storage / expiry, session, app lock
│   ├── domain/
│   │   ├── entities/security_status.dart  # SecurityStatus (7 fields)
│   │   ├── repositories/                  # 13 repository contracts
│   │   └── usecases/                      # 13 use cases
│   ├── data/
│   │   ├── datasources/                   # 13 datasources
│   │   └── repositories_impl/             # 13 repository implementations
│   └── platform/
│       └── method_channel_security.dart   # MethodChannel bridge
├── android/src/main/kotlin/               # 12 Kotlin native handlers
├── ios/.../Sources/                       # 12 Swift native handlers
├── example/                               # Demo application
└── test/                                  # Unit tests
```

---

## Testing

```bash
flutter test
```

Tests cover platform (MethodChannel mocks), domain (use cases with mocked repositories), and data (repository impls with mocked datasources) layers — both success and failure paths.

---

## Requirements

| | Minimum |
|---|---|
| Flutter | >= 3.22.0 (example app: >= 3.27.0) |
| Dart SDK | >= 3.4.0 |
| Android | API 23 (Marshmallow) |
| iOS | 12.0 |

---

## Alternatives

- [**flutter_jailbreak_detection**](https://pub.dev/packages/flutter_jailbreak_detection) — focused solely on root/jailbreak
- [**flutter_secure_storage**](https://pub.dev/packages/flutter_secure_storage) — encrypted key-value storage only
- [**ssl_pinning_plugin**](https://pub.dev/packages/ssl_pinning_plugin) — certificate pinning only

This package provides a broader security baseline in a single dependency.

---

## Contributing

Contributions and bug reports are welcome. Please open an issue before submitting a large pull request.

---

## License

MIT — see [LICENSE](LICENSE).
