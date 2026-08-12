# Nyla Sync Relay

A Cloudflare Worker backed by one SQLite Durable Object per opaque Nyla vault.

The relay coordinates devices and stores signed ciphertext. It is intentionally incapable of decrypting menstrual records, symptoms or notes.

## What the relay knows

It needs only enough metadata to route and authenticate encrypted changes:

- opaque vault and device identifiers
- device Ed25519/X25519 public keys
- vault-key epoch number
- monotonic server cursors
- operation IDs and encrypted envelopes
- one-time pairing/recovery metadata
- encrypted rotation checkpoints/packages

It does not receive the vault key or readable health values.

## Security properties

- signed proof-of-possession bootstrap for the first device
- timestamped, nonced Ed25519 authentication for vault HTTP requests
- persisted nonce replay rejection
- independently signed encrypted operation envelopes
- bounded request, batch, operation and checkpoint sizes
- idempotent operation IDs and idempotent rotation IDs
- accountless one-time QR pairing
- recovery-secret-derived enrollment identity; only its public key is server-side
- target-specific X25519/HKDF/XChaCha20 vault-key packages for retained devices
- atomic revoke + epoch advance + checkpoint + recovery replacement
- authenticated full-vault erasure
- no request-body/ciphertext/health-value application logging

## Main HTTP surface

All vault endpoints are under `/v1/vaults/{vault_id}`:

- `POST /bootstrap`
- `GET /state?known_epoch={epoch}&cursor={cursor}`
- `POST /operations`
- `GET /operations?since={cursor}&limit={n}`
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

Compatibility handlers for the earlier pairing shape remain internal to the relay, but the mobile product uses the `pairing-invites` flow.

`GET /health` is the only public route outside vault routing and returns only `ok`.

There is deliberately no standalone device-revoke endpoint in the product protocol. Device removal is performed through `/rotate` so a revoked device and the old vault key are retired atomically.

## Rotation checkpoint

Before removal, the client syncs to an exact server cursor, materializes state plus field clocks/tombstones, compresses it and encrypts it under a fresh vault key. The Durable Object accepts rotation only if that cursor still equals the head of the operation log.

Every retained device receives a separately wrapped new key. The checkpoint, replacement recovery envelope, revocations, packages and new epoch are committed in one synchronous SQLite transaction.

This allows an offline retained device or newly recovered/paired device to jump safely across an epoch boundary without the relay learning the health state.

## Runtime tests

`npm test` executes the Worker and real SQLite Durable Object behavior inside Cloudflare's Vitest/workerd test runtime. Tests cover bootstrap persistence, signed access, nonce replay protection, unsigned rejection and destructive vault erasure/re-bootstrap behavior.

`npm run typecheck` runs Wrangler type generation followed by strict TypeScript checking.

## Deployment

No Cloudflare credential belongs in the repository.

```sh
npm install --no-audit --no-fund
npm run typecheck
npm test
npm run deploy
```

Wrangler authentication is configured outside source control.
