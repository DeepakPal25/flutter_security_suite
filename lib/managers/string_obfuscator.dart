import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/exceptions/security_exception.dart';

/// Reversible obfuscation for sensitive string literals (API keys, base
/// URLs, feature flags) so they are **not** stored in plaintext inside the
/// compiled binary, where tools such as `strings` or `grep` would reveal
/// them.
///
/// ### Obfuscation, not encryption
///
/// This hides values from casual static inspection. It is **not** a
/// substitute for encryption or a secrets vault: because the [secret] used to
/// de-obfuscate ships inside the same binary, a determined reverse-engineer
/// can still recover the plaintext. For user secrets or tokens at rest, use
/// the platform-backed secure storage instead. Use this only to raise the
/// bar on constants that have to be embedded in the app.
///
/// The scheme is a SHA-256 keystream (counter mode) XORed over the UTF-8
/// bytes, with a fresh random salt per call so the same input never produces
/// the same output, then Base64Url-encoded.
///
/// ```dart
/// // Done once, offline, to produce the literal you paste into source:
/// final o = StringObfuscator('a-build-time-seed');
/// print(o.obfuscate('https://api.bank.com')); // -> copy this token
///
/// // At runtime, in the app:
/// final url = StringObfuscator('a-build-time-seed').reveal(kObfuscatedUrl);
/// ```
class StringObfuscator {
  static const int _saltLength = 12;

  final Uint8List _key;
  final Random _random;

  /// Creates an obfuscator whose [secret] seeds the keystream. The same
  /// [secret] must be used to [obfuscate] and later [reveal] a value.
  ///
  /// Throws [InvalidArgumentSecurityException] when [secret] is empty.
  /// [random] defaults to [Random.secure] and is injectable for tests.
  StringObfuscator(String secret, {Random? random})
    : _key = _deriveKey(secret),
      _random = random ?? Random.secure();

  static Uint8List _deriveKey(String secret) {
    if (secret.isEmpty) {
      throw const InvalidArgumentSecurityException(
        message: 'The obfuscation secret must not be empty',
      );
    }
    // Normalise the seed to a fixed-size key.
    return Uint8List.fromList(sha256.convert(utf8.encode(secret)).bytes);
  }

  /// Obfuscates [plain] and returns a Base64Url token safe to paste into
  /// source or store in a config file.
  String obfuscate(String plain) {
    final salt = Uint8List(_saltLength);
    for (var i = 0; i < _saltLength; i++) {
      salt[i] = _random.nextInt(256);
    }
    final data = utf8.encode(plain);
    final cipher = _xorKeystream(data, salt);
    final out = Uint8List(_saltLength + cipher.length)
      ..setRange(0, _saltLength, salt)
      ..setRange(_saltLength, _saltLength + cipher.length, cipher);
    return base64Url.encode(out);
  }

  /// Reverses [obfuscate]. Returns the original string.
  ///
  /// Throws [InvalidArgumentSecurityException] when [token] is not a token
  /// produced by this class (bad Base64, too short, or not valid UTF-8 once
  /// decoded — typically a wrong [secret]).
  String reveal(String token) {
    final Uint8List raw;
    try {
      raw = base64Url.decode(token);
    } catch (e) {
      throw InvalidArgumentSecurityException(
        message: 'The obfuscated token is not valid Base64Url',
        originalError: e,
      );
    }
    if (raw.length < _saltLength) {
      throw const InvalidArgumentSecurityException(
        message: 'The obfuscated token is too short to be valid',
      );
    }
    final salt = Uint8List.sublistView(raw, 0, _saltLength);
    final cipher = Uint8List.sublistView(raw, _saltLength);
    final plain = _xorKeystream(cipher, salt);
    try {
      return utf8.decode(plain);
    } catch (e) {
      throw InvalidArgumentSecurityException(
        message:
            'Could not reveal the token (wrong secret or corrupted data)',
        originalError: e,
      );
    }
  }

  /// XORs [data] with a SHA-256 keystream derived from the key and [salt].
  /// Block `n` is `sha256(key || salt || n)`; symmetric, so the same call
  /// both obfuscates and reveals.
  Uint8List _xorKeystream(List<int> data, List<int> salt) {
    final out = Uint8List(data.length);
    var counter = 0;
    var offset = 0;
    while (offset < data.length) {
      final block = _keystreamBlock(salt, counter);
      final take = min(block.length, data.length - offset);
      for (var i = 0; i < take; i++) {
        out[offset + i] = data[offset + i] ^ block[i];
      }
      offset += take;
      counter++;
    }
    return out;
  }

  List<int> _keystreamBlock(List<int> salt, int counter) {
    final input = Uint8List(_key.length + salt.length + 4);
    var p = 0;
    input.setRange(p, p += _key.length, _key);
    input.setRange(p, p += salt.length, salt);
    input[p++] = (counter >> 24) & 0xff;
    input[p++] = (counter >> 16) & 0xff;
    input[p++] = (counter >> 8) & 0xff;
    input[p] = counter & 0xff;
    return sha256.convert(input).bytes;
  }
}
