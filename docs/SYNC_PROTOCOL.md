# Nyla Sync Protocol

Protocol version: `1`

The protocol is designed so the cloud can coordinate devices without reading menstrual data.

## Identities

### Vault

`vault_id`: 128 random bits encoded base64url without padding.

`vault_key`: 256 random bits. Exists only on authorized devices / inside the recovery envelope.

### Device

`device_id`: 128 random bits.

Each device generates:

- Ed25519 signing key pair
- X25519 key-agreement key pair for enrollment/recovery flows

Only public keys are uploaded.

## Operations

Local state is synchronized as immutable field operations instead of database snapshots.

A plaintext operation contains:

```json
{
  "v": 1,
  "op": "random-id",
  "entity": "random-id",
  "entity_type": "day",
  "field": "flow",
  "hlc": "1786500000000:2:device-id",
  "kind": "set",
  "value": "medium"
}
```

Entity IDs, fields and values are encrypted; the relay does not index them.

Supported `kind` values:

- `set` — assign a field
- `unset` — remove a field
- `delete` — tombstone an entity

Every local edit writes the local materialized state and its immutable operation to the outbox in one database transaction.

## Merge

Each field is a last-writer-wins register ordered by a Hybrid Logical Clock (HLC). Ties are broken lexicographically by device ID.

Entity deletion is also timestamped. A field operation older than the entity deletion is ignored. A later explicit field operation may recreate the entity, which makes restore behavior deterministic across devices.

This gives us the important property that independent edits survive:

- Device A edits `flow`.
- Device B edits `cramps`.
- Both merge because they are distinct field registers.

If both edit `flow` offline, the HLC ordering picks one deterministic winner on every device.

## Envelope

Canonical UTF-8 JSON plaintext is encrypted with XChaCha20-Poly1305 using the vault key and a fresh 24-byte nonce. Map keys are emitted in the protocol order shown above. The `ciphertext` envelope field is `cipherText || 16-byte Poly1305 MAC`, base64url encoded without padding; the nonce is carried separately.

AAD binds:

```text
nyla-sync-v1|vault_id|device_id|op_id
```

Upload envelope:

```json
{
  "v": 1,
  "vault": "...",
  "device": "...",
  "epoch": 1,
  "op": "...",
  "nonce": "base64url",
  "ciphertext": "base64url",
  "signature": "base64url"
}
```

The Ed25519 signature covers the exact UTF-8 sequence `nyla-envelope-v1\\nvault_id\\ndevice_id\\nepoch\\nop_id\\nnonce\\nciphertext`. The relay verifies the signature using the registered public key before accepting the operation, and receiving clients verify it again before decryption.

## Server cursor

Each vault Durable Object serializes accepted uploads and assigns an increasing integer `cursor`. Clients pull `cursor > last_cursor` in bounded pages.

`op_id` is unique within a vault and has a uniqueness constraint, making upload retries idempotent.

Clients acknowledge only after decrypting, validating and applying all pulled operations transactionally.

## Pairing

Preferred pairing is existing-device authorization:

1. New device generates ephemeral X25519 key pair and displays a QR containing its ephemeral public key plus one-time pairing ID.
2. Existing device scans it and asks the vault to authorize the new permanent public keys.
3. Existing device derives an ephemeral shared secret with X25519 and encrypts the vault key into a one-time enrollment package addressed to the new device.
4. The request is signed by the existing authorized device.
5. New device fetches the package, decrypts it locally, verifies vault identity and deletes the one-time package.
6. Server marks the pairing ID consumed.

The vault key is never plaintext at the relay.

## Recovery

On vault creation, the app creates a separate high-entropy recovery secret and shows it once with an explicit save/verify step.

A recovery-derived wrapping key encrypts the vault key. The relay stores only the wrapped vault key, random salt/parameters and a verifier that does not reveal the recovery secret.

Recovery is rate-limited. After successful local unwrap, a recovered device creates new permanent device keys and rotates the recovery envelope.

## Compaction

Clients periodically upload a signed encrypted checkpoint containing their current materialized CRDT state and highest known cursor. Once all non-revoked devices have acknowledged beyond a safe cursor, the Durable Object may delete older operation ciphertext while retaining the latest checkpoint and recent tail.

Compaction is an optimization only. Correctness does not depend on it.

## Revocation

Any authorized device may revoke another device. Revocation prevents future uploads/download authentication from that device but cannot make already-held vault keys disappear from a compromised device.

For suspected compromise, Nyla performs **vault-key rotation**:

1. generate a new vault key
2. create an encrypted checkpoint under the new key
3. distribute the new key only to retained devices
4. advance vault key epoch
5. reject envelopes from old epochs

This is explicitly different from ordinary device removal.
