# Text Evidence Engine

Text is encoded exactly as UTF-8 with normalization `NONE`. No trim, CRLF/LF conversion, NFC or NFKC normalization is performed by the engine.

Hash set: MD5, SHA-1, SHA-224, SHA-256, SHA-384, SHA-512, SHA3-224, SHA3-256, SHA3-384, SHA3-512 and RIPEMD-160. Legacy hashes are retained for correlation/interoperability and are not treated as the primary security digest. SHA-256/SHA-512 are the primary manifest binding digests.

Encrypt Text creates separate plaintext and ciphertext hash sets and a `text_encryption_binding.json` artifact. The evidence case stores the canonical manifest and attempts RFC3161 START timestamping. Timestamp failure is recorded and does not falsify a PASS.
