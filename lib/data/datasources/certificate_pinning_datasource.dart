import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Pure-Dart datasource for TLS certificate pinning validation.
///
/// Connects to [host]:443, retrieves the server certificate, and compares the
/// SHA-256 fingerprint of its **Subject Public Key Info (SPKI)** against the
/// provided pins. Pinning the SPKI instead of the full certificate means that
/// certificate renewals (which keep the same key pair) do not break pinning.
///
/// Pin format: `sha256/<base64-encoded-sha256-of-spki>` (HPKP format).
class CertificatePinningDatasource {
  Future<bool> validateCertificate({
    required String host,
    required List<String> pins,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final client = HttpClient();
    client.connectionTimeout = timeout;
    // Allow self-signed / mismatched certs so we can inspect the certificate
    // ourselves; the actual security decision is made by the SPKI pin check.
    client.badCertificateCallback = (cert, h, port) => true;
    try {
      final request = await client.headUrl(Uri.https(host, '/'));
      final response = await request.close();

      final certificate = response.certificate;
      if (certificate == null) {
        await response.drain<void>();
        return false;
      }

      final spki = _extractSpki(Uint8List.fromList(certificate.der));
      if (spki == null) {
        await response.drain<void>();
        return false;
      }

      final fingerprint = base64.encode(sha256.convert(spki).bytes);
      final normalised = pins
          .map((p) => p.startsWith('sha256/') ? p.substring(7) : p)
          .toSet();

      await response.drain<void>();
      return normalised.contains(fingerprint);
    } finally {
      client.close();
    }
  }

  /// Extracts the DER-encoded SubjectPublicKeyInfo (SPKI) bytes from a
  /// DER-encoded X.509 certificate by walking the ASN.1 structure.
  ///
  /// Returns `null` if the certificate cannot be parsed.
  Uint8List? _extractSpki(Uint8List der) {
    // Parses a DER length field at [at].
    // Returns (length_value, number_of_bytes_consumed_by_length_field).
    (int, int) parseLen(int at) {
      if (at >= der.length) return (0, 0);
      final first = der[at];
      if (first < 0x80) return (first, 1);
      final n = first & 0x7F;
      if (at + n >= der.length) return (0, 0);
      int len = 0;
      for (int i = 1; i <= n; i++) {
        len = (len << 8) | der[at + i];
      }
      return (len, 1 + n);
    }

    int pos = 0;

    // Outer Certificate SEQUENCE (tag 0x30)
    if (pos >= der.length || der[pos] != 0x30) return null;
    pos++;
    final (_, outerLs) = parseLen(pos);
    pos += outerLs;

    // TBSCertificate SEQUENCE (tag 0x30)
    if (pos >= der.length || der[pos] != 0x30) return null;
    pos++;
    final (_, tbsLs) = parseLen(pos);
    pos += tbsLs;

    // Optional version [0] EXPLICIT INTEGER
    if (pos < der.length && der[pos] == 0xA0) {
      pos++;
      final (vLen, vLs) = parseLen(pos);
      pos += vLs + vLen;
    }

    // Skip 5 fields in order: serialNumber, signature(algId),
    //                          issuer, validity, subject
    for (int i = 0; i < 5; i++) {
      if (pos >= der.length) return null;
      pos++; // skip tag
      final (fLen, fLs) = parseLen(pos);
      pos += fLs + fLen;
    }

    // SubjectPublicKeyInfo SEQUENCE (tag 0x30)
    if (pos >= der.length || der[pos] != 0x30) return null;
    final spkiStart = pos;
    pos++;
    final (spkiContentLen, spkiLs) = parseLen(pos);
    final spkiEnd = pos + spkiLs + spkiContentLen;

    if (spkiEnd > der.length) return null;
    return Uint8List.fromList(der.sublist(spkiStart, spkiEnd));
  }
}
