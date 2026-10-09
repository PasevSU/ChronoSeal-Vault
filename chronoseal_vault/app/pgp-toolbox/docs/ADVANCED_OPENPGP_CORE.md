# PasevSU Advanced OpenPGP Core — current in v2.1.1

## Purpose

The Advanced OpenPGP Core extends the normal daily-use tools without replacing them. It keeps advanced lifecycle, validation and forensic functions in one top-level accordion so the normal interface remains usable.

## 1. Security Policy Engine

The policy builder returns a per-operation `config` object. It never assigns to global `openpgp.config`.

Default strict policy:

- minimum RSA size: 3072 bits (user may choose 2048/3072/4096);
- RFC 9580 message grammar enforcement;
- MD5 rejected; SHA-1 rejected when the strict checkbox is enabled;
- unauthenticated messages disabled;
- unauthenticated streaming disabled;
- decryption with signing-only RSA keys disabled;
- decompressed-message size limit (default 512 MiB);
- optional constant-time RSA/ElGamal session-key decryption.

The constant-time option is intentionally not enabled by default because OpenPGP.js documents a measurable performance cost and its main benefit is automated decryption services where remote timing can be observed.

## 2. Deep Key Health & Historical Validation

The validator performs real cryptographic checks rather than only displaying metadata:

1. `verifyPrimaryKey(date)` — checks revocation, expiration and a valid self-signature.
2. `verifyAllUsers(undefined, date)` — validates User ID self-certifications.
3. `Subkey.verify(date)` — validates every subkey binding, revocation and expiration state.
4. Role discovery — tries the exact subkey as a signing and encryption key.
5. Optional `PrivateKey.validate()` — verifies that private/public primary parameters correspond and validates private key integrity.

The validation date can be set explicitly. This is useful for forensic questions such as whether a key/subkey was structurally valid at the time a historical signature or message was created.

## 3. Identity Lifecycle Manager

The manager modifies an existing private identity while retaining its primary fingerprint.

### Add subkey

Supported UI profiles:

- Brainpool P-512 signing/encryption;
- NIST P-521 signing/encryption;
- RSA-8192 signing/encryption;
- RSA-4096 signing/encryption;
- Curve25519 encryption (explicit compatibility warning).

The key is unlocked only for the operation, `addSubkey()` is executed, `PrivateKey.validate()` is run, and the key is re-protected with its original passphrase state before it is written back to IndexedDB.

### Revoke one subkey

Only the selected subkey receives a revocation signature. The primary identity and other subkeys remain present. The modified key is serialized and parsed again before persistent storage.

### Revoke one User ID

The selected User ID/email receives a certification-revocation signature using `userIDInvalid`. Other User IDs and the primary fingerprint remain present.

### Revoke the complete identity

The primary key receives a key-revocation signature. This is intentionally guarded by an explicit confirmation because it is a permanent OpenPGP state transition.

Before every persistent lifecycle mutation, PasevSU creates a local IndexedDB snapshot for rollback and prunes the snapshot history to the normal retention limit. Every lifecycle write also appends a local PasevSU lifecycle event to `meta.lifecycle`.

## 4. Signed + Encrypted Communication

The normal Encrypt Message tool now optionally combines signing and encryption in one OpenPGP operation.

When enabled, PasevSU:

1. unlocks the selected signing private key;
2. resolves a valid signing key/subkey;
3. optionally creates signed Case-ID and Evidence-ID notation data;
4. encrypts to the already validated recipient key;
5. optionally uses wildcard recipient Key IDs;
6. optionally applies the strict per-operation policy.

For exact-email encryption, `encryptionUserIDs` and the exact validated `encryptionKeyID` remain in use.

## 5. Required signature on decryption

Decrypt Message can now receive an expected sender public key and set `expectSigned=true`. In this mode OpenPGP.js must both decrypt the message and find a valid signature made by the supplied verification key. A historical validation date may be supplied.

The signature audit is shown separately from the plaintext.

## 6. Session Key & Recipient Inspector

The inspector parses a complete encrypted message or encrypted session-key packet and reports:

- public-key recipient Key IDs;
- signing Key IDs visible in the parsed message;
- literal filename when available;
- decrypted session-key algorithm;
- session-key byte length.

Raw session-key material is hidden by default. It is emitted only when the expert reveal checkbox is explicitly enabled.

## 7. Runtime test

After `setup_vendor.ps1` installs the pinned OpenPGP.js browser bundle, open:

`tests/runtime_openpgp_v21.html`

The test uses temporary in-memory keys only and checks:

- addSubkey + private/public validation;
- primary/User ID/subkey validation;
- signed + encrypted message;
- signature notation;
- wildcard recipient;
- decryptSessionKeys;
- `expectSigned` decryption;
- subkey revocation serialization round-trip;
- User ID revocation serialization round-trip.

A PASS from this runtime test is required before lifecycle mutation functions should be treated as target-runtime validated.


## 8. ASCII Armor & Message Inspector

The inspector calls `openpgp.unarmor()` so malformed armor or a bad armor checksum is rejected by the library. The returned binary packet block is hashed with SHA-256 and SHA-512. If the armor type is an OpenPGP message, PasevSU also attempts `readMessage()` and reports visible recipient/signing Key IDs and the literal filename when available. Raw binary can be downloaded for packet-level external analysis.

## 9. Compression selection

Normal message encryption now exposes automatic, uncompressed, ZIP and ZLIB modes. The selected mode is passed as a local `preferredCompressionAlgorithm` setting and is combined with Strict Policy without mutating global OpenPGP.js configuration. Compression is a size/interoperability setting, not an additional cryptographic security layer.

## 10. Session-key algorithm selector correction

The pre-v1.8 UI offered AES-128/AES-192/AES-256 but generated a session key using recipient preferences, so the explicit GUI selection was not guaranteed to control the result. v1.8 generates the session key with the selected symmetric algorithm as the local preferred algorithm without passing recipient preferences to generation, verifies the returned algorithm name, and only then wraps the resulting key for the selected recipient with `encryptSessionKey()`.
