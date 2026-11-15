import 'dart:io';

import '../../core/network/certificate_pinner.dart';

/// Pure-Dart datasource for TLS certificate pinning validation.
///
/// Opens a TLS connection to the host, lets the platform validate the
/// certificate chain as usual, and then compares the SHA-256 fingerprint of
/// the leaf certificate's **Subject Public Key Info (SPKI)** (or of the whole
/// certificate, see [PinningMode]) against the provided pins.
///
/// Accepted pin formats: `sha256/<base64>`, bare base64 / base64url, or
/// 64 hex characters.
class CertificatePinningDatasource {
  /// Public key (default) or whole-certificate pinning.
  final PinningMode mode;

  /// Optional trust store, e.g. for a private CA. `null` uses the platform's.
  final SecurityContext? securityContext;

  CertificatePinningDatasource({
    this.mode = PinningMode.publicKey,
    this.securityContext,
  });

  /// Returns `true` when the certificate served by [host] matches one of
  /// [pins], `false` on a mismatch or when [pins] is empty.
  ///
  /// [host] is a bare host name or `host:port` (default port 443).
  ///
  /// Throws [ArgumentError] for a malformed host or pin and the underlying
  /// `dart:io` exception when the connection or TLS validation fails.
  Future<bool> validateCertificate({
    required String host,
    required List<String> pins,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final target = parseHost(host);
    if (pins.isEmpty) return false;

    final pinner = CertificatePinner(
      pins: {target.host: pins},
      mode: mode,
    );
    return pinner.validateHost(
      target.host,
      port: target.port,
      timeout: timeout,
      context: securityContext,
    );
  }

  /// Splits `host` / `host:port` / `[v6]:port`. Throws [ArgumentError] for
  /// URLs, paths, credentials or anything else that is not a plain host.
  static ({String host, int port}) parseHost(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      throw ArgumentError.value(input, 'host', 'Host must not be empty');
    }
    if (raw.contains(RegExp(r'[/@?#\s\\]')) || raw.contains('*')) {
      throw ArgumentError.value(
        input,
        'host',
        'Expected a host name or host:port, not a URL or pattern',
      );
    }
    final Uri uri;
    try {
      uri = Uri.parse('https://$raw');
    } on FormatException catch (e) {
      throw ArgumentError.value(input, 'host', 'Invalid host: ${e.message}');
    }
    if (uri.host.isEmpty) {
      throw ArgumentError.value(input, 'host', 'Invalid host');
    }
    final port = uri.hasPort ? uri.port : 443;
    if (port <= 0 || port > 65535) {
      throw ArgumentError.value(input, 'host', 'Invalid port');
    }
    return (host: uri.host, port: port);
  }
}
