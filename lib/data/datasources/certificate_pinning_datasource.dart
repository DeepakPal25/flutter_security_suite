import 'dart:io';
import 'package:crypto/crypto.dart';

/// Pure-Dart datasource for TLS certificate pinning validation.
///
/// Connects to [host]:443, retrieves the server certificate,
/// and compares its SHA-256 fingerprint against the provided pins.
class CertificatePinningDatasource {
  Future<bool> validateCertificate({
    required String host,
    required List<String> pins,
  }) async {
    final client = HttpClient();
    client.badCertificateCallback = (cert, h, port) => true;
    try {
      final request = await client.headUrl(Uri.https(host, '/'));
      final response = await request.close();

      final certificate = response.certificate;
      if (certificate == null) return false;

      final fingerprint = sha256.convert(certificate.der).toString();
      final normalised = pins.map(
        (p) => p.replaceFirst('sha256/', '').toLowerCase(),
      );

      await response.drain<void>();
      return normalised.contains(fingerprint.toLowerCase());
    } finally {
      client.close();
    }
  }
}
