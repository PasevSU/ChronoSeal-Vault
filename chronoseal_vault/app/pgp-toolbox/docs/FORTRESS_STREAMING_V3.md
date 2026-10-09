# PasevSU Fortress Streaming V3

Fortress Streaming V3 is the large-file custom PasevSU container. It preserves the four Universal MAX asymmetric layers and optional Argon2id password layer while using Web Streams and File System Access to avoid whole-file ciphertext construction in RAM.

## V3 metadata binding

The outer header is canonicalized with sorted JSON keys. An exact canonical copy is prefixed to the plaintext stream as `PASEVSU_FORTRESS_INNER_META_V1\0 + uint32 length + JSON` before any OpenPGP layer is applied. On decryption, the inner manifest is recovered only after all OpenPGP/AEAD layers succeed and is compared byte-for-byte in canonical form to the outer header. Plaintext is not committed when the metadata comparison fails.

The remaining plaintext is verified with `SHA-512-CHAIN-V1` over fixed 1 MiB logical blocks plus exact byte size before the writable file is closed.

New files use magic `PASEVSU_FORTRESS_STREAM_V3\0` and extension `.pasevsu-fortress-v3`.

Legacy V2 remains readable after an explicit warning. V2 plaintext digest/size verification remains useful, but its outer metadata was not cryptographically bound; v2.1.1 never creates new V2 containers.


## In-memory Fortress V2 (v2.1.1)

The non-streaming path now writes `PASEVSU_FORTRESS_V2\0`. Its complete outer header (profile, recipient fingerprint, exact layer IDs, password-layer declaration/KDF parameters, cipher/AEAD/digest metadata and creation time) is copied into the inner envelope **before** the asymmetric layers are encrypted. Decryption requires canonical equality between the decrypted inner copy and the visible outer header. A modified V2 outer header is therefore rejected.

Legacy `PASEVSU_FORTRESS_V1\0` remains decrypt-compatible for existing files, but its outer metadata is not treated as authenticated. New encryption never writes V1.
