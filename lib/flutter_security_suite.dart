/// SecureBankKit – Enterprise-grade Flutter security plugin.
///
/// ```dart
/// import 'package:flutter_security_suite/flutter_security_suite.dart';
///
/// final kit = SecureBankKit.initialize(
///   enableRootDetection: true,
///   enablePinning: true,
///   certificatePins: {'api.bank.com': ['sha256/AAAA...']},
/// );
/// ```
library;

// Core
export 'core/exceptions/security_exception.dart';
export 'core/network/certificate_pinner.dart';
export 'core/result/security_result.dart';
export 'core/utils/logger.dart';

// Domain entities
export 'domain/entities/anti_tamper_status.dart';
export 'domain/entities/biometric_availability.dart';
export 'domain/entities/obfuscation_status.dart';
export 'domain/entities/pin_lockout_state.dart';
export 'domain/entities/screen_capture_event.dart';
export 'domain/entities/security_status.dart';

// Domain contracts needed to use the managers stand-alone
export 'domain/repositories/biometric_repository.dart';
export 'domain/repositories/secure_storage_repository.dart';

// Managers
export 'managers/app_lock_manager.dart';
export 'managers/build_hardening_inspector.dart';
export 'managers/pin_lock_manager.dart';
export 'managers/secure_token_storage.dart';
export 'managers/session_manager.dart';
export 'managers/string_obfuscator.dart';
export 'managers/token_expiry_manager.dart';

// Widgets
export 'widgets/privacy_guard.dart';

// Public facade
export 'secure_bank_kit.dart';
