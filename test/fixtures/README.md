Self-signed `localhost` certificates used only by the certificate pinning
tests (`test/core/network`, `test/data/datasources`). The private keys are
throw-away test keys – never use them for anything else.

The certificates expire on 2029-02-12. They are short-lived on purpose: Apple's
trust evaluation (used by `dart:io` on macOS and iOS) rejects TLS server
certificates that are valid for more than 825 days. When they expire, run
`./regenerate.sh` – it keeps the keys (so the public-key pins stay the same)
and prints the new certificate pins to paste into `fixtures.dart`.
