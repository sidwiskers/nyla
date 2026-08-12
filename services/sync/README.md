# Nyla Sync Relay

A Cloudflare Worker backed by one SQLite Durable Object per opaque sync vault.

The service is intentionally unable to decrypt menstrual records. It stores signed ciphertext envelopes and the minimum metadata required to authenticate devices, order changes and recover from offline operation.

## Security properties

- first-device bootstrap requires proof of possession of the submitted Ed25519 key
- every authenticated HTTP request is timestamped, nonced and signed
- used request nonces are retained across the acceptance window to reject replay
- every stored sync envelope also carries an Ed25519 signature
- operation IDs are unique, so retries are idempotent
- upload size and batch sizes are bounded
- device pairing transfers only an opaque package encrypted device-to-device
- recovery uses a recovery-secret-derived signing identity; the service keeps only its public key and a wrapped vault key
- compromised-device handling supports vault-key epochs and per-retained-device rotation packages
- logs deliberately contain no request bodies, ciphertext or health values

The mobile client owns XChaCha20-Poly1305 encryption/decryption, X25519 pairing, recovery-key derivation, HLC generation and CRDT merging.

## HTTP surface

All endpoints are below `/v1/vaults/{vault_id}`.

- `POST /bootstrap` — initialize a new vault and first device
- `POST /operations` — upload a bounded signed ciphertext batch
- `GET /operations?since={cursor}&limit={n}` — pull ordered ciphertext changes
- `POST /pairings/authorize` — an existing device authorizes a QR pairing package
- `GET /pairings/{pairing_id}` — new device fetches its opaque one-time package
- `POST /pairings/consume` — paired device destroys the one-time package
- `PUT /recovery` — set/rotate recovery envelope
- `GET /recovery/{recovery_id}` — fetch wrapped vault key
- `POST /recovery/{recovery_id}/enroll` — prove recovery-secret possession and add a device
- `GET /devices` — list opaque authorized devices
- `POST /devices/{device_id}/revoke` — remove access; key rotation is recommended
- `POST /rotate` — atomically advance key epoch, revoke compromised devices and publish sealed key packages
- `GET /rotations/{epoch}` — target device fetches its sealed new-key package
- `DELETE /vault` — erase the Durable Object's stored sync state

`GET /health` is the only route outside a vault.

## Deployment

No secret is committed to this repository. Deployment uses Wrangler authentication configured outside the source tree.

```sh
npm ci
npm run typecheck
npm run deploy
```

The project uses the current declarative `exports` configuration for a SQLite-backed Durable Object.
