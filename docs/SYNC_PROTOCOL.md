# Nyla Sync Protocol

## Purpose

Nyla is local-first. The readable menstrual database on each device is authoritative for that device; Cloudflare is an encrypted coordination and delivery layer, never the health-data execution environment.

The protocol is designed so that:

- a menstrual log never waits for the network
- the relay never receives a readable health value or vault key
- devices may edit independently while offline
- field-level conflicts resolve deterministically
- retries are idempotent
- a revoked device does not receive the next vault key
- a retained device can survive a key rotation while offline
- recovery and deletion have explicit, testable semantics

## Identifiers

Every sync vault has a random opaque `vault_id`. Every installation has a random `device_id` and permanent device signing/exchange key pairs. IDs are routing identifiers only; they contain no email address, name or menstrual information.

No user account is required by the sync protocol.

## Device keys and vault key

Each device stores, in platform secure storage:

- Ed25519 signing seed
- X25519 exchange seed
- current 256-bit vault key
- current vault-key epoch

The vault key encrypts sync operations with XChaCha20-Poly1305. Device signing keys authenticate the transport envelopes and authenticated HTTP requests.

The Cloudflare relay stores public keys only.

## Local operation model

A local edit becomes a field-scoped operation before upload. The encrypted plaintext contains:

```text
version
operation ID
entity ID
entity type
field
hybrid logical clock
kind: set | unset | delete
value
```

Examples:

- `day:21000 / cramps = { value: moderate, severity: 2 }`
- `period-id / start_day = 21000`
- `period-id / end_day = 21004`
- `custom-id / archived = true`

Changes to independent fields remain independent operations. Nyla does not upload or replace an entire local database to resolve a small edit.

## Envelope

Before an operation leaves a device:

1. canonical plaintext is encoded
2. plaintext is encrypted with the current vault key using XChaCha20-Poly1305
3. authenticated additional data binds the envelope to vault ID, device ID, epoch and operation ID
4. the envelope is signed with the sender's Ed25519 key

The relay stores:

```text
server cursor
vault ID (implicit Durable Object routing)
device ID
vault-key epoch
operation ID
nonce
ciphertext + authentication tag
Ed25519 signature
accepted timestamp
```

It cannot inspect the operation's entity, field, value, note or symptom.

## Authenticated HTTP

Except for bootstrap and the narrowly scoped pairing/recovery enrollment endpoints, vault requests require:

- device ID
- timestamp inside the accepted clock window
- one-time request nonce
- Ed25519 signature over method, canonical path, timestamp, nonce and body hash

Accepted request nonces are persisted long enough to reject replay. Revoked devices fail authentication.

## Bootstrap

`POST /bootstrap` creates an empty vault and activates its first device. The request includes the device public keys and proof of possession of the submitted signing private key.

Bootstrap is accepted only when the Durable Object has no initialized vault.

## Normal synchronization

A sync run is deliberately ordered:

1. read local identity and cursor
2. call `GET /state?known_epoch=…&cursor=…`
3. apply any required key rotation/checkpoint first
4. upload local pending operations in HLC causal order
5. fetch the current device signing-key directory
6. pull encrypted operations after the local cursor
7. verify signature, decrypt and merge each operation locally
8. advance the local cursor only after the page has been processed

### Upload

`POST /operations` accepts a bounded batch. Operation IDs are unique, so retries return accepted/duplicate IDs without duplicating logical changes.

The relay re-checks the vault epoch immediately before the synchronous insertion transaction. An upload racing a key rotation therefore cannot be silently accepted into the wrong epoch.

### Pull

`GET /operations?since={cursor}&limit={n}` returns monotonically ordered relay cursors, opaque envelopes, the current epoch and whether another page remains.

The client verifies the sender against the authenticated device directory before decrypting an operation.

## Hybrid logical clocks and merge

Every mutable field is an independent last-writer register ordered by a hybrid logical clock `(physical time, logical counter, node ID)`.

The node ID supplies deterministic tie-breaking when two devices produce operations at the same physical/logical point.

Entity deletion is represented by an HLC tombstone. A delete removes older field state, but an older delete is not allowed to erase a field already known to have a newer clock. A later field operation may deterministically restore an entity.

Remote operations are merged through the same rules used by rotation checkpoints. Malformed or unauthenticated input fails closed; the client does not advance past data it could not safely process.

## QR device pairing

Pairing is intentionally accountless.

1. an authorized device generates a high-entropy one-time `PairingCode`
2. it creates `/pairing-invites/{pairing_id}` with only a hash of the invite secret
3. the new device scans the QR, creates its permanent signing/exchange keys and proves possession of its signing key when joining
4. the trusted device observes the join and encrypts the current vault key + epoch with a key derived from the one-time pairing secret
5. the new device fetches and decrypts that opaque package
6. it authenticates with its newly activated device identity and consumes the invite

The pairing secret is never sent to the relay in plaintext. Pairing packages are short-lived and one-time.

X25519 is not required for the QR handoff itself; the permanent X25519 device key becomes important for later vault-key rotations.

## Recovery

A recovery code contains a random recovery secret plus the opaque vault ID.

From that secret, the client derives:

- a recovery signing identity used to prove possession during enrollment
- a wrapping key used to decrypt the current vault key

The relay stores only the recovery public key and wrapped vault key. It cannot reconstruct the recovery secret.

After successful recovery, Nyla immediately replaces the recovery code. A code that has been used should therefore be treated as retired.

A new or recovered device starts with cursor `0`; `/state` supplies the current encrypted checkpoint when history has crossed a key-rotation boundary.

## Device removal and vault-key rotation

Nyla deliberately has no unsafe "revoke now, rotate later" product path. Removing a device and advancing the vault key are one atomic protocol operation.

Before rotation the initiating device completes a normal sync and obtains an exact relay cursor. It then:

1. generates a fresh 256-bit vault key and next epoch
2. materializes a merge-safe local checkpoint for the exact current cursor
3. encrypts that checkpoint with the new vault key
4. creates a fresh recovery code and wraps the new vault key for it
5. for every retained active device, creates a target-specific rotation package
6. sends the revoked-device set, packages, checkpoint and new recovery envelope in one signed `/rotate` request

### Target-specific rotation packages

Each retained device package uses:

- a fresh ephemeral X25519 key pair
- the target device's permanent X25519 public key
- HKDF-SHA256 domain separation
- XChaCha20-Poly1305
- AAD binding vault ID, source device, target device, epoch and ephemeral public key

Knowing the old vault key does not allow a removed device to decrypt another device's rotation package.

### Atomic relay commit

The Durable Object verifies that:

- `new_epoch == current_epoch + 1`
- the checkpoint cursor exactly matches the highest accepted operation cursor
- every retained active device has exactly one package
- no revoked device receives a package
- the replacement recovery envelope is structurally valid

Then, inside one synchronous storage transaction, it revokes devices, stores packages, stores the encrypted checkpoint, replaces recovery state and advances the epoch.

## Rotation checkpoint

The checkpoint contains materialized synchronized state represented as ordinary merge operations, including:

- period fields
- day values and notes
- custom-log definitions
- field clocks
- entity tombstones

It excludes local device credentials, recovery secrets, preferences that are intentionally local, and pending outbox metadata.

The checkpoint is compressed, size-bounded, then encrypted with the new vault key. Applying it uses the normal HLC merge engine, so a newer offline edit on the receiving device survives an older checkpoint value.

After applying the checkpoint, the receiver sets its cursor to the checkpoint's `base_cursor` and pulls only later operations.

## Crash and retry semantics

Rotation has a random `rotation_id`. The relay persists that ID with the checkpoint, making an identical committed rotation recognizable if the HTTP response was lost.

Before sending rotation, the client securely records pending rotation/recovery state. On the next sync it reconciles that state against the relay's current `rotation_id` and epoch. This prevents a lost response from causing Nyla to discard a recovery code that actually became authoritative.

Checkpoint application is idempotent. The new device key is persisted before merge/cursor advancement, so a process death can safely replay the same checkpoint on the next launch.

## Vault deletion

`DELETE /vault` is an authenticated destructive request. The Durable Object calls `deleteAll()` and recreates only an empty schema so the same opaque Durable Object can later accept a genuinely fresh bootstrap.

Deleting the cloud vault cannot erase copies already stored on offline phones. The UI states this explicitly.

Local erasure is separate: the app first destroys secure-storage key material, then removes the SQLCipher database and SQLite WAL/SHM/journal sidecars.

## HTTP surface

All vault routes are beneath `/v1/vaults/{vault_id}`.

Primary routes:

- `POST /bootstrap`
- `GET /state`
- `POST /operations`
- `GET /operations`
- `POST /pairing-invites`
- `GET /pairing-invites/{id}`
- `POST /pairing-invites/{id}/join`
- `POST /pairing-invites/{id}/authorize`
- `POST /pairing-invites/{id}/consume`
- `PUT /recovery`
- `GET /recovery/{recovery_id}`
- `POST /recovery/{recovery_id}/enroll`
- `GET /devices`
- `POST /rotate`
- `GET /rotations/{epoch}`
- `DELETE /vault`

A minimal `GET /health` route exists outside vault routing and returns no vault information.

## Relay limits

The relay bounds request bodies, operation sizes, operation batches, pull page sizes, rotation body size and checkpoint size. It performs no health analytics, predictions, content personalization or advertising profiling.
