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
export 'core/result/security_result.dart';

// Domain entities
export 'domain/entities/security_status.dart';

// Public facade
export 'secure_bank_kit.dart';
