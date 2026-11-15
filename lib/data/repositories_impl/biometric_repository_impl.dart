import 'package:flutter/services.dart';

import '../../core/exceptions/security_exception.dart';
import '../../core/result/security_result.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/biometric_availability.dart';
import '../../domain/repositories/biometric_repository.dart';
import '../datasources/biometric_datasource.dart';

class BiometricRepositoryImpl implements BiometricRepository {
  static const Set<String> _knownCodes = <String>{
    BiometricException.notAvailable,
    BiometricException.notEnrolled,
    BiometricException.lockedOut,
    BiometricException.passcodeNotSet,
    BiometricException.noActivity,
    BiometricException.inProgress,
    BiometricException.invalidArguments,
    BiometricException.failed,
  };

  final BiometricDatasource _datasource;

  const BiometricRepositoryImpl(this._datasource);

  @override
  Future<SecurityResult<BiometricAvailability>> checkAvailability() async {
    try {
      SecurityLogger.info('Checking biometric availability');
      final map = await _datasource.availability();
      return Success(BiometricAvailability.fromMap(map));
    } catch (e, st) {
      SecurityLogger.error(
        'Biometric availability check failed',
        error: e,
        stackTrace: st,
      );
      return Failure(_mapError(e));
    }
  }

  @override
  Future<SecurityResult<bool>> authenticate({
    required String reason,
    bool allowDeviceCredential = true,
    String? cancelLabel,
  }) async {
    final trimmedReason = reason.trim();
    if (trimmedReason.isEmpty) {
      return const Failure(
        BiometricException(
          code: BiometricException.invalidArguments,
          message: 'A non-empty reason is required for biometric prompts',
        ),
      );
    }
    final trimmedCancel = cancelLabel?.trim();
    try {
      SecurityLogger.info('Requesting biometric authentication');
      final ok = await _datasource.authenticate(
        reason: trimmedReason,
        allowDeviceCredential: allowDeviceCredential,
        cancelLabel: (trimmedCancel == null || trimmedCancel.isEmpty)
            ? null
            : trimmedCancel,
      );
      return Success(ok);
    } catch (e, st) {
      SecurityLogger.error(
        'Biometric authentication failed',
        error: e,
        stackTrace: st,
      );
      return Failure(_mapError(e));
    }
  }

  BiometricException _mapError(Object error) {
    if (error is MissingPluginException) {
      return BiometricException(
        code: BiometricException.notAvailable,
        message: 'Biometric authentication is not supported on this platform',
        originalError: error,
      );
    }
    if (error is PlatformException) {
      final code = switch (error.code) {
        'NO_ACTIVITY' => BiometricException.noActivity,
        'INVALID_ARGS' => BiometricException.invalidArguments,
        final c when _knownCodes.contains(c) => c,
        _ => BiometricException.failed,
      };
      return BiometricException(
        code: code,
        message: error.message ?? 'Biometric authentication failed',
        originalError: error,
      );
    }
    return BiometricException(
      message: 'Biometric authentication failed: $error',
      originalError: error,
    );
  }
}
