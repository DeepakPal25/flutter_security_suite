#!/bin/sh
# Re-issues the throw-away localhost test certificates, re-using the existing
# keys so the public-key (SPKI) pins in fixtures.dart stay valid.
#
# Apple's trust evaluation (used by dart:io on macOS/iOS) rejects TLS server
# certificates valid for more than 825 days or without the serverAuth EKU, so
# these certificates are short-lived on purpose. When they expire, run this
# script and paste the printed certificate pins into fixtures.dart.
set -e
cd "$(dirname "$0")"
for kind in rsa ec; do
  openssl req -x509 -new -key "localhost_${kind}_key.pem" -sha256 -days 820 \
    -subj "/CN=localhost" \
    -addext "basicConstraints=critical,CA:TRUE" \
    -addext "keyUsage=critical,digitalSignature,keyEncipherment,keyCertSign" \
    -addext "extendedKeyUsage=serverAuth" \
    -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" \
    -out "localhost_${kind}_cert.pem"
  echo "$kind SPKI pin: $(openssl x509 -in localhost_${kind}_cert.pem -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl base64)"
  echo "$kind cert pin: $(openssl x509 -in localhost_${kind}_cert.pem -outform der | openssl dgst -sha256 -binary | openssl base64)"
  echo "$kind cert hex: $(openssl x509 -in localhost_${kind}_cert.pem -outform der | openssl dgst -sha256 -hex | sed 's/.*= //')"
  echo "$kind expires:  $(openssl x509 -in localhost_${kind}_cert.pem -noout -enddate)"
done
