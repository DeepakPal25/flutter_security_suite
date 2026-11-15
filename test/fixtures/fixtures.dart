import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Paths and known fingerprints of the test certificates.
///
/// Fingerprints were computed independently with OpenSSL:
/// `openssl x509 -pubkey -noout | openssl pkey -pubin -outform der |
///  openssl dgst -sha256 -binary | base64`
class Fixtures {
  static const rsaCert = 'test/fixtures/localhost_rsa_cert.pem';
  static const rsaKey = 'test/fixtures/localhost_rsa_key.pem';
  static const ecCert = 'test/fixtures/localhost_ec_cert.pem';
  static const ecKey = 'test/fixtures/localhost_ec_key.pem';

  static const rsaSpkiPin = 'z5poNDQ3W64XzstAhhlmI1BRKHKd6rf43EqQeHw+eYU=';
  static const rsaCertPin = 'nZfPB33Spv8OZKCmSbRltbdRqCrV8xQTbEwfAkEIuYM=';
  static const rsaCertHex =
      '9d97cf077dd2a6ff0e64a0a649b465b5b751a82ad5f314136c4c1f024108b983';

  static const ecSpkiPin = 'hsTxsl5d3UmEjOn0Aus0d+gMJApByOkr+vqmfgNVGmw=';
  static const ecCertPin = 'V1DLrtjUdA03WbCWSFF5EExtOhPhhUHs3fGAYQjGmco=';
  static const ecCertHex =
      '5750cbaed8d4740d3759b096485179104c6d3a13e18541ecddf1806108c699ca';

  /// A syntactically valid pin that matches nothing.
  static const otherPin = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

  /// Decodes the first PEM block of [path] to DER bytes.
  static Uint8List der(String path) {
    final body = File(path)
        .readAsLinesSync()
        .where((l) => l.isNotEmpty && !l.startsWith('-----'))
        .join();
    return base64.decode(body);
  }

  static SecurityContext serverContext({bool ec = false}) =>
      SecurityContext(withTrustedRoots: false)
        ..useCertificateChain(ec ? ecCert : rsaCert)
        ..usePrivateKey(ec ? ecKey : rsaKey);

  /// Client context that trusts only the test certificates.
  static SecurityContext clientContext() =>
      SecurityContext(withTrustedRoots: false)
        ..setTrustedCertificates(rsaCert)
        ..setTrustedCertificates(ecCert);
}
