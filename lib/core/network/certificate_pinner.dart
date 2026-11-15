import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../exceptions/security_exception.dart';

/// What part of the server certificate a pin refers to.
enum PinningMode {
  /// SHA-256 of the DER-encoded SubjectPublicKeyInfo (recommended).
  ///
  /// Survives certificate renewals as long as the key pair is kept.
  publicKey,

  /// SHA-256 of the whole DER-encoded certificate.
  ///
  /// Breaks on every certificate renewal.
  certificate,
}

/// Public-key / certificate pinning for `dart:io` connections.
///
/// Pins are SHA-256 digests in any of these spellings:
///
/// * `sha256/<base64>` (HPKP style) or bare base64 / base64url
/// * 64 hex characters, optionally separated by `:`
///
/// Hosts are matched case-insensitively. `*.example.com` matches exactly one
/// extra label (`api.example.com`), never the apex and never deeper names.
///
/// Normal TLS validation always stays on: a pin can only *add* a
/// restriction, it never makes an otherwise untrusted certificate
/// acceptable. To talk to a server with a private CA or a self-signed
/// certificate, pass a [SecurityContext] that trusts it.
///
/// `dart:io` only exposes the **leaf** certificate of a connection, so pins
/// must be leaf pins (intermediate / root pins cannot be checked).
class CertificatePinner {
  final Map<String, Set<String>> _pins;

  /// Whether pins are public-key or whole-certificate digests.
  final PinningMode mode;

  /// When `true`, connections to hosts without any pin are refused.
  final bool rejectUnpinnedHosts;

  /// Throws [ArgumentError] if a host is blank, has no pins, or a pin is not
  /// a valid SHA-256 digest.
  CertificatePinner({
    required Map<String, List<String>> pins,
    this.mode = PinningMode.publicKey,
    this.rejectUnpinnedHosts = false,
  }) : _pins = _normalizePins(pins);

  static Map<String, Set<String>> _normalizePins(
    Map<String, List<String>> pins,
  ) {
    final out = <String, Set<String>>{};
    pins.forEach((host, values) {
      final h = normalizeHost(host);
      if (h.isEmpty || h == '*.' || h == '*') {
        throw ArgumentError.value(host, 'pins', 'Host must not be blank');
      }
      if (h.contains('*') && !(h.startsWith('*.') && !h.substring(2).contains('*'))) {
        throw ArgumentError.value(
          host,
          'pins',
          'Wildcards are only supported as a leading "*." label',
        );
      }
      if (values.isEmpty) {
        throw ArgumentError.value(host, 'pins', 'No pins given for host');
      }
      out.putIfAbsent(h, () => <String>{}).addAll(values.map(normalizePin));
    });
    return out;
  }

  /// Lower-cases and trims [host] and drops a trailing root dot.
  static String normalizeHost(String host) {
    var h = host.trim().toLowerCase();
    while (h.endsWith('.')) {
      h = h.substring(0, h.length - 1);
    }
    return h;
  }

  static final RegExp _hex = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Converts any accepted pin spelling into canonical standard base64.
  ///
  /// Throws [ArgumentError] when [pin] is not a 32-byte SHA-256 digest.
  static String normalizePin(String pin) {
    var p = pin.trim();
    if (p.length >= 7 && p.substring(0, 7).toLowerCase() == 'sha256/') {
      p = p.substring(7).trim();
    }
    if (p.isEmpty) {
      throw ArgumentError.value(pin, 'pin', 'Pin must not be empty');
    }

    final hex = p.replaceAll(':', '');
    if (_hex.hasMatch(hex)) {
      final bytes = Uint8List(32);
      for (var i = 0; i < 32; i++) {
        bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
      }
      return base64.encode(bytes);
    }

    try {
      final bytes = base64.decode(base64.normalize(p));
      if (bytes.length == 32) return base64.encode(bytes);
    } on FormatException {
      // fall through
    }
    throw ArgumentError.value(
      pin,
      'pin',
      'Pin must be a base64 or hex encoded SHA-256 digest (32 bytes)',
    );
  }

  /// Hosts (and wildcard patterns) that have pins configured.
  Iterable<String> get pinnedHosts => _pins.keys;

  /// Pins configured for [host] (canonical base64). Empty when unpinned.
  ///
  /// An exact entry wins over a wildcard entry.
  Set<String> pinsForHost(String host) {
    final h = normalizeHost(host);
    if (h.isEmpty) return const <String>{};
    final exact = _pins[h];
    if (exact != null) return exact;
    final dot = h.indexOf('.');
    if (dot > 0 && dot < h.length - 1) {
      final wildcard = _pins['*.${h.substring(dot + 1)}'];
      if (wildcard != null) return wildcard;
    }
    return const <String>{};
  }

  /// Whether any pin is configured for [host].
  bool isPinned(String host) => pinsForHost(host).isNotEmpty;

  /// Base64 SHA-256 of the SubjectPublicKeyInfo of a DER certificate, or
  /// `null` when [der] is not a parsable X.509 certificate.
  static String? spkiFingerprint(List<int> der) {
    final spki = extractSpki(der);
    if (spki == null) return null;
    return base64.encode(sha256.convert(spki).bytes);
  }

  /// Base64 SHA-256 of the whole DER certificate.
  static String certificateFingerprint(List<int> der) =>
      base64.encode(sha256.convert(der).bytes);

  /// Fingerprint of [der] for this pinner's [mode]; `null` if unparsable.
  String? fingerprint(List<int> der) {
    if (der.isEmpty) return null;
    return mode == PinningMode.publicKey
        ? spkiFingerprint(der)
        : certificateFingerprint(der);
  }

  /// Whether the DER certificate satisfies the pins of [host].
  ///
  /// Unpinned hosts match unless [rejectUnpinnedHosts] is set.
  bool matches(String host, List<int> der) {
    final pins = pinsForHost(host);
    if (pins.isEmpty) return !rejectUnpinnedHosts;
    final fp = fingerprint(der);
    return fp != null && pins.contains(fp);
  }

  /// Throws [CertificatePinningException] unless [certificate] satisfies the
  /// pins of [host].
  void check(String host, X509Certificate? certificate) {
    final pins = pinsForHost(host);
    if (pins.isEmpty) {
      if (rejectUnpinnedHosts) {
        throw CertificatePinningException(
          host: host,
          message: 'No pins configured for host',
        );
      }
      return;
    }
    if (certificate == null) {
      throw CertificatePinningException(
        host: host,
        message: 'Server presented no certificate',
      );
    }
    final fp = fingerprint(certificate.der);
    if (fp == null) {
      throw CertificatePinningException(
        host: host,
        message: 'Server certificate could not be parsed',
      );
    }
    if (!pins.contains(fp)) {
      throw CertificatePinningException(
        host: host,
        message: 'Certificate pin mismatch (got sha256/$fp)',
      );
    }
  }

  /// Returns an [HttpClient] that refuses every connection whose leaf
  /// certificate does not match the pins of the target host.
  ///
  /// The check runs on the TLS socket itself, before any request bytes are
  /// written. Additional restrictions of the returned client:
  ///
  /// * Plain `http://` requests to a pinned host are refused (and to every
  ///   host when [rejectUnpinnedHosts] is set).
  /// * HTTP proxies are bypassed, because a pin cannot be verified through
  ///   a proxy tunnel.
  HttpClient createHttpClient({
    SecurityContext? context,
    Duration? connectionTimeout,
  }) {
    final client = HttpClient(context: context);
    if (connectionTimeout != null) {
      client.connectionTimeout = connectionTimeout;
    }
    client.findProxy = (_) => 'DIRECT';
    client.connectionFactory = (Uri uri, String? proxyHost, int? proxyPort) {
      final host = uri.host;
      if (!uri.isScheme('https')) {
        if (rejectUnpinnedHosts || isPinned(host)) {
          return Future<ConnectionTask<Socket>>.error(
            CertificatePinningException(
              host: host,
              message: 'Refusing cleartext connection to a pinned host',
            ),
          );
        }
        return Socket.startConnect(host, uri.port);
      }
      if (rejectUnpinnedHosts && !isPinned(host)) {
        return Future<ConnectionTask<Socket>>.error(
          CertificatePinningException(
            host: host,
            message: 'No pins configured for host',
          ),
        );
      }
      return SecureSocket.startConnect(host, uri.port, context: context).then((
        task,
      ) {
        final Future<Socket> checked = task.socket.then<Socket>((socket) {
          try {
            check(host, socket.peerCertificate);
          } catch (_) {
            socket.destroy();
            rethrow;
          }
          return socket;
        });
        return ConnectionTask.fromSocket(checked, task.cancel);
      });
    };
    return client;
  }

  /// Opens a TLS connection to [host] and reports whether its leaf
  /// certificate matches the configured pins.
  ///
  /// Returns `false` on a pin mismatch (or when the host has no pins).
  /// Throws (`HandshakeException`, `SocketException`, `TimeoutException`,
  /// …) when the connection or normal TLS validation fails.
  Future<bool> validateHost(
    String host, {
    int port = 443,
    Duration timeout = const Duration(seconds: 10),
    SecurityContext? context,
  }) async {
    final pins = pinsForHost(host);
    if (pins.isEmpty) return false;
    // `SecureSocket.connect(timeout:)` only bounds the TCP connect, so a
    // peer that accepts the connection and then stalls the TLS handshake
    // would hang forever. Bound the whole connect + handshake instead.
    final task = await SecureSocket.startConnect(
      host,
      port,
      context: context,
    ).timeout(timeout);
    final SecureSocket socket;
    try {
      socket = await task.socket.timeout(timeout);
    } on TimeoutException {
      task.cancel();
      // If the handshake completes after we gave up, do not leak the socket.
      unawaited(
        task.socket.then<void>((s) => s.destroy(), onError: (Object _) {}),
      );
      rethrow;
    }
    try {
      final cert = socket.peerCertificate;
      if (cert == null) return false;
      final fp = fingerprint(cert.der);
      return fp != null && pins.contains(fp);
    } finally {
      socket.destroy();
    }
  }

  // ---------------------------------------------------------------------
  // ASN.1
  // ---------------------------------------------------------------------

  /// Extracts the DER-encoded SubjectPublicKeyInfo from a DER-encoded X.509
  /// certificate. Returns `null` for anything that is not well formed.
  static Uint8List? extractSpki(List<int> der) {
    final bytes = der is Uint8List ? der : Uint8List.fromList(der);

    final cert = _readTlv(bytes, 0, bytes.length);
    if (cert == null || cert.tag != 0x30) return null;

    final tbs = _readTlv(bytes, cert.contentStart, cert.end);
    if (tbs == null || tbs.tag != 0x30) return null;

    var pos = tbs.contentStart;

    // Optional version: [0] EXPLICIT INTEGER
    var field = _readTlv(bytes, pos, tbs.end);
    if (field == null) return null;
    if (field.tag == 0xA0) {
      pos = field.end;
      field = _readTlv(bytes, pos, tbs.end);
      if (field == null) return null;
    }

    // serialNumber, signature, issuer, validity, subject
    const expected = [0x02, 0x30, 0x30, 0x30, 0x30];
    for (final tag in expected) {
      if (field == null || field.tag != tag) return null;
      pos = field.end;
      field = _readTlv(bytes, pos, tbs.end);
    }

    // subjectPublicKeyInfo
    if (field == null || field.tag != 0x30) return null;
    // Must itself contain AlgorithmIdentifier SEQUENCE + BIT STRING.
    final alg = _readTlv(bytes, field.contentStart, field.end);
    if (alg == null || alg.tag != 0x30) return null;
    final key = _readTlv(bytes, alg.end, field.end);
    if (key == null || key.tag != 0x03 || key.end != field.end) return null;

    return Uint8List.sublistView(bytes, field.start, field.end);
  }

  static _Tlv? _readTlv(Uint8List b, int at, int limit) {
    if (at < 0 || limit > b.length || at + 2 > limit) return null;
    final tag = b[at];
    if (tag & 0x1F == 0x1F) return null; // high-tag-number form
    final first = b[at + 1];
    int length;
    int contentStart;
    if (first < 0x80) {
      length = first;
      contentStart = at + 2;
    } else {
      final n = first & 0x7F;
      if (n == 0 || n > 4) return null; // indefinite or absurdly long
      if (at + 2 + n > limit) return null;
      length = 0;
      for (var i = 0; i < n; i++) {
        length = (length << 8) | b[at + 2 + i];
      }
      contentStart = at + 2 + n;
    }
    final end = contentStart + length;
    if (end > limit) return null;
    return _Tlv(tag, at, contentStart, end);
  }
}

class _Tlv {
  final int tag;
  final int start;
  final int contentStart;
  final int end;
  const _Tlv(this.tag, this.start, this.contentStart, this.end);
}
