# Security and Privacy Model

Nyla handles intimate health information and treats privacy as a system property.

## Threat model

We design against:

- accidental cloud disclosure
- compromised sync storage
- network interception
- unauthorized device enrollment
- replayed or modified sync operations
- another person casually opening an unlocked phone
- lock-screen notification disclosure
- backups copying readable health data
- logs/crash reports containing menstrual records or encryption material

No mobile application can promise secrecy against a fully compromised/rooted device while the user is actively using decrypted data. Nyla minimizes exposure and uses platform key protection rather than pretending that risk does not exist.

## Local data at rest

The SQLite database is encrypted using SQLCipher supplied through `package:sqlite3` native hooks.

A random database key is generated on first launch. It is never hard-coded and never written to ordinary preferences. The key is wrapped/stored through the platform secure-storage implementation backed by Android Keystore / Apple Keychain. App-lock policy can require device authentication before key access.

Sensitive exports are created only after explicit user action. Temporary plaintext export files must be deleted after share/export completion where the platform permits it.

## Sync encryption

Each sync vault has an independent random 256-bit vault key generated on-device.

Health operations are serialized canonically and encrypted with XChaCha20-Poly1305 using a fresh 192-bit random nonce per operation. Additional authenticated data binds the ciphertext to protocol version, vault ID, operation ID and device ID.

Each device has an Ed25519 signing key pair. The service stores only the public key. Every upload is signed, allowing the relay to reject forged or modified envelopes without learning their plaintext.

Cloudflare never receives the vault encryption key.

## Device enrollment

Enrollment is explicit. Existing-device pairing uses ephemeral X25519 key agreement so the vault key can be transferred encrypted to the new device. The existing authorized device signs the enrollment.

A separate high-entropy recovery code can restore access when no existing device is available. Losing every device and the recovery code means the cloud copy cannot be decrypted. This is a privacy property, not a support defect.

## Metadata minimization

The server may know:

- random vault ID
- random device IDs
- device public signing keys
- operation IDs
- ciphertext byte lengths
- monotonic sync cursors
- coarse server receive timestamps needed for abuse control / expiry

It does not need:

- period dates
- symptoms
- notes
- prediction results
- content viewed
- user name
- email address
- phone number

The initial design therefore has no conventional email/password account.

## Network

Only HTTPS/WSS endpoints are accepted in production. Requests are bounded in size and rate. The service validates content type, protocol version, signatures and IDs before storage.

## Logs and telemetry

Production logs must not include request bodies, ciphertext, recovery material, local database contents, user-entered notes, exact menstrual dates or device secrets.

Nyla does not embed advertising SDKs. Product analytics are disabled by default; if privacy-preserving diagnostics are introduced, they must be opt-in and structurally unable to contain health values.

## Notifications

Users control notification wording:

- **Private**: "Nyla has a reminder for you."
- **Normal**: context such as "Your period may start soon."
- **Off**: no reminder category.

Notification previews never include symptom notes or detailed health history.

## Secure deletion

Deleting a local profile removes the encrypted database and local key material. Deleting a sync vault instructs its Durable Object to erase stored operations, devices, recovery envelope and pairing state. Tombstones are used for normal cross-device entity deletion before vault deletion.

## Verification baseline

Security reviews use OWASP MASVS controls covering storage, cryptography, authentication, network, platform interaction, code quality and privacy. Dependency updates and platform-security changes are treated as maintenance requirements, not optional enhancements.
