# Apple root certificates

`AppleIncRootCertificate.cer`, `AppleRootCA-G2.cer`, `AppleRootCA-G3.cer` are Apple's public root certificates used by the official App Store Server Library to verify signed transactions and notifications. They were downloaded from [Apple PKI](https://www.apple.com/certificateauthority/) on 2026-10-04. Refresh these files from Apple if its root set changes; never substitute a private signing key here.
