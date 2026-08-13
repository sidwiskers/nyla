# Nyla Sync Runtime

Nyla's sync trigger is device-local. Cloudflare remains only the encrypted relay described in `SYNC_PROTOCOL.md`; it never schedules a user, wakes a phone, owns the readable database or decides when a health record should be uploaded.

## Runtime contract

A health-data edit always completes locally first:

1. the encrypted SQLCipher database is updated
2. the same local transaction records a field-scoped outbox mutation
3. after that commit, the foreground runtime notices that the pending outbox grew
4. Android is asked to keep one durable network-constrained sync request
5. while Nyla is open, a short debounce coalesces nearby taps and the normal `SyncService.syncNow()` pipeline is attempted quietly

The edit never waits for Cloudflare and never fails because background scheduling or networking is unavailable.

## Foreground reconciliation

After Nyla is unlocked on app open or resume, it requests durable work and immediately attempts the ordinary sync pipeline. This gives a newly opened device fresh remote state without a periodic polling timer or persistent socket.

All automatic foreground triggers are single-flight. A second trigger joins the active run rather than starting another copy.

## Offline behavior

Android durable work uses WorkManager with a connected-network constraint.

If a local change is made while offline, the encrypted outbox remains authoritative on the phone. The queued task is not eligible to execute until Android has a working network again. When it does run, it opens the same encrypted local database and invokes the exact same sync protocol as foreground/manual synchronization.

Transient transport failures request WorkManager retry with exponential backoff. Protocol, authentication and malformed-data failures fail closed instead of producing an endless retry loop.

## No fixed polling interval

Nyla does not periodically contact Cloudflare merely because an hour passed. Normal triggers are:

- a committed local sync mutation
- app open/resume after privacy checks
- explicit manual Sync
- protocol flows that already require synchronization, such as pairing/recovery/device rotation

This matches the product's data shape: menstrual-health edits are infrequent, so change-driven reconciliation is more responsive and does less unnecessary work than hourly polling.

## Concurrency and erasure

A WorkManager callback runs in a separate Dart isolate and can overlap the foreground process. Nyla therefore treats multiple database connections as a normal runtime condition:

- SQLCipher stays in WAL mode
- SQLite has a bounded busy timeout
- Drift transactions use immediate writer acquisition
- automatic foreground sync and background sync share a cross-isolate advisory file lock

Local erasure uses that same lock. It cancels queued work, destroys secure key material first, then removes the SQLCipher database and WAL/SHM/journal sidecars. A stale worker re-checks existing credentials after acquiring the lock and exits if they no longer exist; it never calls key-generating accessors.

## Security boundary

Scheduling changes no cryptographic property of the protocol. Background work still:

- reads only this installation's device-protected keys
- encrypts/signs operations on the device
- authenticates every request
- verifies sender signatures before decryption
- applies remote data only through the HLC merge engine

Cloudflare still receives only the protocol's opaque routing metadata and signed ciphertext.

## Platform scope

Android gets durable offline-to-online execution through WorkManager. Other platforms still receive foreground change/open synchronization and manual Sync; platform-specific durable scheduling should be added only when it can preserve the same local-first, fail-closed guarantees rather than approximating Android behavior with server-side polling.
