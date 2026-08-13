# Security and Privacy Model

Nyla handles menstrual-health data as sensitive private data. Privacy is therefore an architectural property, not a toggle layered on top of an analytics product.

## Security goals

Nyla is designed so that:

- readable health history stays on trusted devices
- local storage is encrypted at rest
- cloud sync is end-to-end encrypted
- Cloudflare cannot decrypt menstrual records or notes
- devices authenticate cryptographically rather than through reusable account passwords
- loss/removal of a device can rotate the shared vault key without stranding retained offline devices
- notifications can avoid revealing menstrual context on a lock screen
- users can export and permanently erase their data
- health data is not routed through advertising or behavioral analytics SDKs

## Threat model

The design specifically considers:

- loss or theft of a phone
- an attacker obtaining a copy of the local database file
- a passive or malicious network intermediary
- compromise or misconfiguration of the sync relay
- replayed requests
- forged remote operations
- concurrent/offline edits on multiple devices
- a device that was trusted and later must be removed
- a crash or lost HTTP response during key rotation
- accidental OS backup or device-transfer leakage
- lock-screen notification disclosure
- accidental destructive actions
- a stale background worker racing local erasure

No mobile application can protect readable data from a fully compromised operating system while the user has unlocked the application. Nyla does not claim otherwise.

## Local database

The Drift database runs on SQLCipher. Its random 256-bit database key lives in platform secure storage rather than in SQLite, preferences or source code.

The app fails closed if it cannot safely open the encrypted database.

### Platform backup policy

Android native configuration disables application backup and explicitly excludes files, databases, shared preferences, root storage and external storage from cloud backup/device transfer. Nyla uses its own E2E sync instead.

iOS secure material is stored through Keychain-backed secure storage with the required Keychain entitlement. The health database itself remains application-local.

## App lock and background privacy

The optional app lock uses device authentication through the platform local-authentication API. When the application becomes inactive, hidden or paused, Nyla conceals its content. If app lock is enabled, returning to the app requires successful device authentication before health UI is shown again.

This also prevents the application-switcher snapshot from casually displaying the previous menstrual screen while Nyla is backgrounded.

App lock is a foreground presentation/access-control boundary, not a requirement to display biometric UI for every operating-system background wake-up. On Android, a WorkManager sync may use this installation's already device-protected SQLCipher key and sync identity while the health UI remains locked. It executes the same E2E-encrypted protocol as foreground sync: readable health values are decrypted only on the device and never sent to Cloudflare in plaintext.

## Notification privacy

Reminders are local notifications. Users can choose private wording that does not put menstrual details on the lock screen.

Notification payload navigation is allowlisted to Nyla-owned routes; arbitrary payload strings cannot become navigation/deep links.

## Local erasure

"Erase this device" is intentionally destructive and requires a second confirmation with the literal word `ERASE`.

The reset sequence:

1. removes the active provider scope so repository streams stop
2. acquires the cross-isolate sync/erasure lock
3. best-effort cancels the unique pending Android sync worker
4. closes the SQLCipher database
5. deletes secure-storage material first, cryptographically destroying the database key, sync identity and pending recovery/rotation secrets
6. deletes the database plus WAL, SHM and journal sidecars
7. releases the lock and starts a fresh installation identity

Destroying key material before filesystem cleanup means a crash during physical deletion does not leave a usable encrypted database key behind. Cancellation is not trusted as the sole safety mechanism: if a stale worker wakes after cancellation, it must acquire the same lock and re-read existing secure material. With the identity/key gone it exits instead of generating replacements or reopening erased data.

## Sync encryption

Each vault has a random 256-bit vault key known only to authorized devices/recovery material. Health operations are encrypted with XChaCha20-Poly1305 before upload.

AAD binds ciphertext to its vault, sender, epoch and operation ID. The sender also signs the envelope with Ed25519.

The relay sees ciphertext plus minimal routing/authentication metadata; entity types, fields, values and private notes remain encrypted.

## HTTP authentication and replay defense

Authenticated requests are signed by the device's Ed25519 key and include a bounded timestamp, random nonce and body hash. Accepted request nonces are persisted across the replay window.

The relay stores only device public keys. A device marked revoked is rejected by authentication.

## QR pairing

The QR contains a high-entropy one-time pairing secret and opaque identifiers. The relay receives only a hash of that secret.

The joining device creates its permanent signing/exchange keys and proves signing-key possession. The trusted device then wraps the vault key + epoch using key material derived from the one-time pairing secret. The package is opaque to Cloudflare and is consumed after activation.

QR pairing itself does not depend on a server-readable account password or email address.

## Recovery

Recovery is intentionally user-held. The recovery secret derives both a recovery signing identity and a vault-key wrapping key. Cloudflare stores the corresponding public key and a wrapped vault key, not the recovery secret.

A successful recovery immediately rotates the recovery code. If all authorized devices and the current recovery code are lost, the ciphertext is intentionally unrecoverable.

## Removing a device

Revocation is inseparable from vault-key rotation in the client UX.

The next vault key is generated locally and wrapped separately for every retained device using ephemeral X25519, the target device's permanent X25519 public key, HKDF-SHA256 and XChaCha20-Poly1305. A removed device receives no package.

An encrypted, merge-safe checkpoint lets retained devices that were offline during the rotation establish the new epoch without decrypting old history using the new key. Recovery state is replaced in the same Durable Object transaction as revocation and epoch advancement.

Rotation IDs and pending secure client state make the operation recoverable when a server commit succeeds but its HTTP response is lost.

## Sync correctness is a security property

Nyla uses field-level HLC merge rather than whole-record or whole-database replacement.

Important invariants include:

- pending operations upload in HLC causal order
- a stale remote field cannot overwrite a newer local field
- a stale entity delete cannot erase a newer offline edit
- tombstones prevent accidental resurrection by older state
- a newer legitimate field can deterministically restore an entity
- checkpoints are applied through the same merge engine
- cursors advance only after safe processing

These rules protect availability/integrity of private health history, not only confidentiality.

## Cloud vault erasure

An authenticated `DELETE /vault` destroys all Durable Object storage for the vault. The runtime recreates only empty tables so the opaque object can accept a future fresh bootstrap.

The Settings UI distinguishes:

- **this device only** — cryptographically erase the current installation; shared cloud vault/other phones remain untouched
- **cloud vault + this device** — authenticated cloud deletion must succeed before local erasure begins

Cloud deletion cannot remotely wipe menstrual data already present on another offline device; Nyla states that limitation instead of implying otherwise.

## Product privacy boundaries

Nyla does not need readable cloud health data for predictions, insights or educational recommendations. Those functions run locally.

The product deliberately excludes pregnancy/TTC/fertility-probability and masturbation/sexual-coaching modules. Medical education is source-backed and versioned, and a corpus test prevents excluded modules from silently entering published tip copy.

## Logging and telemetry

The sync relay does not log request bodies, ciphertext or health values. It performs no health analytics, ad targeting or cross-service user profiling.

Any future observability must preserve that rule: operational metrics should describe service behavior, not menstrual behavior.

## Standards posture

Nyla's implementation is informed by OWASP MASVS storage, cryptography, authentication, network and privacy principles. That is an engineering target, not a certification claim.
