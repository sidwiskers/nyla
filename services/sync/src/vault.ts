import { DurableObject } from 'cloudflare:workers';

import {
  AUTH_NONCE_TTL_MS,
  DEFAULT_PULL_OPERATIONS,
  MAX_BATCH_OPERATIONS,
  MAX_OPERATION_BYTES,
  MAX_PULL_OPERATIONS,
  MAX_ROTATION_BODY_BYTES,
  MAX_ROTATION_CHECKPOINT_BYTES,
  PAIRING_TTL_MS,
  PayloadTooLargeError,
  bootstrapPayload,
  clockIsFresh,
  decodeBase64Url,
  envelopePayload,
  error,
  httpAuthPayload,
  json,
  pairingJoinPayload,
  readJson,
  recoveryEnrollmentPayload,
  sha256Base64Url,
  validBase64Url,
  validId,
  verifyEd25519,
} from './protocol';

interface Env {}

interface DeviceRow {
  device_id: string;
  signing_public_key: string;
  exchange_public_key: string;
  activated_ms: number | null;
  pending_pairing_id: string | null;
  revoked_ms: number | null;
}

interface MetaRow {
  value: string;
}

interface OperationInput {
  v: number;
  op: string;
  epoch: number;
  nonce: string;
  ciphertext: string;
  signature: string;
}

interface OperationRow {
  cursor: number;
  op_id: string;
  device_id: string;
  epoch: number;
  nonce: string;
  ciphertext: string;
  signature: string;
  received_ms: number;
}

interface AuthContext {
  device: DeviceRow;
  body: Uint8Array<ArrayBuffer>;
}

export class Vault extends DurableObject<Env> {
  private readonly sql: SqlStorage;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.ensureSchema();
  }

  private ensureSchema(): void {
    this.sql.exec(`
      CREATE TABLE IF NOT EXISTS meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      );
      CREATE TABLE IF NOT EXISTS devices (
        device_id TEXT PRIMARY KEY,
        signing_public_key TEXT NOT NULL,
        exchange_public_key TEXT NOT NULL,
        added_ms INTEGER NOT NULL,
        activated_ms INTEGER,
        pending_pairing_id TEXT,
        revoked_ms INTEGER
      );
      CREATE TABLE IF NOT EXISTS operations (
        cursor INTEGER PRIMARY KEY AUTOINCREMENT,
        op_id TEXT NOT NULL UNIQUE,
        device_id TEXT NOT NULL,
        epoch INTEGER NOT NULL,
        nonce TEXT NOT NULL,
        ciphertext TEXT NOT NULL,
        signature TEXT NOT NULL,
        received_ms INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS auth_nonces (
        device_id TEXT NOT NULL,
        nonce TEXT NOT NULL,
        expires_ms INTEGER NOT NULL,
        PRIMARY KEY (device_id, nonce)
      );
      CREATE TABLE IF NOT EXISTS pairings (
        pairing_id TEXT PRIMARY KEY,
        target_device_id TEXT NOT NULL,
        target_signing_public_key TEXT NOT NULL,
        target_exchange_public_key TEXT NOT NULL,
        ephemeral_public_key TEXT NOT NULL,
        package_nonce TEXT NOT NULL,
        package_ciphertext TEXT NOT NULL,
        inviter_device_id TEXT NOT NULL,
        created_ms INTEGER NOT NULL,
        expires_ms INTEGER NOT NULL,
        consumed_ms INTEGER
      );
      CREATE TABLE IF NOT EXISTS pairing_invites (
        pairing_id TEXT PRIMARY KEY,
        inviter_device_id TEXT NOT NULL,
        token_hash TEXT NOT NULL,
        target_device_id TEXT,
        target_signing_public_key TEXT,
        target_exchange_public_key TEXT,
        package_nonce TEXT,
        package_ciphertext TEXT,
        created_ms INTEGER NOT NULL,
        expires_ms INTEGER NOT NULL,
        authorized_ms INTEGER,
        consumed_ms INTEGER
      );
      CREATE TABLE IF NOT EXISTS recovery (
        slot INTEGER PRIMARY KEY CHECK (slot = 1),
        recovery_id TEXT NOT NULL UNIQUE,
        recovery_signing_public_key TEXT NOT NULL,
        wrap_nonce TEXT NOT NULL,
        wrapped_vault_key TEXT NOT NULL,
        created_ms INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS recovery_attempts (
        attempted_ms INTEGER NOT NULL
      );
      CREATE TABLE IF NOT EXISTS rotations (
        epoch INTEGER NOT NULL,
        target_device_id TEXT NOT NULL,
        source_device_id TEXT,
        ephemeral_public_key TEXT,
        package_nonce TEXT NOT NULL,
        package_ciphertext TEXT NOT NULL,
        created_ms INTEGER NOT NULL,
        PRIMARY KEY (epoch, target_device_id)
      );
      CREATE TABLE IF NOT EXISTS checkpoints (
        epoch INTEGER PRIMARY KEY,
        rotation_id TEXT UNIQUE,
        base_cursor INTEGER NOT NULL,
        nonce TEXT NOT NULL,
        ciphertext TEXT NOT NULL,
        created_ms INTEGER NOT NULL
      );
    `);
    this.ensureColumn('rotations', 'source_device_id', 'TEXT');
    this.ensureColumn('rotations', 'ephemeral_public_key', 'TEXT');
    this.ensureColumn('checkpoints', 'rotation_id', 'TEXT');
    this.sql.exec('CREATE UNIQUE INDEX IF NOT EXISTS idx_checkpoints_rotation_id ON checkpoints(rotation_id)');
  }

  private ensureColumn(table: string, column: string, type: string): void {
    const columns = this.sql.exec(`PRAGMA table_info(${table})`).toArray() as Array<{ name: string }>;
    if (!columns.some((entry) => entry.name === column)) {
      this.sql.exec(`ALTER TABLE ${table} ADD COLUMN ${column} ${type}`);
    }
  }

  override async fetch(request: Request): Promise<Response> {
    try {
      return await this.route(request);
    } catch (cause) {
      if (cause instanceof PayloadTooLargeError) return error('payload_too_large', 413);
      if (cause instanceof RecoveryRateLimitError) return error('recovery_rate_limited', 429);
      if (cause instanceof SyntaxError || cause instanceof TypeError) return error('invalid_request', 400);
      console.error('nyla_sync_internal_error');
      return error('internal_error', 500);
    }
  }

  private async route(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;
    const vault = request.headers.get('x-nyla-vault');
    const canonicalPath = request.headers.get('x-nyla-canonical-path');
    if (!vault || !validId(vault) || !canonicalPath) return error('invalid_vault_route', 400);

    if (request.method === 'POST' && path === '/bootstrap') {
      return this.bootstrap(request, vault);
    }

    const recoveryGet = path.match(/^\/recovery\/([A-Za-z0-9_-]{16,64})$/);
    if (request.method === 'GET' && recoveryGet) {
      return this.getRecovery(recoveryGet[1]!);
    }
    const recoveryEnroll = path.match(/^\/recovery\/([A-Za-z0-9_-]{16,64})\/enroll$/);
    if (request.method === 'POST' && recoveryEnroll) {
      return this.recoverDevice(request, vault, recoveryEnroll[1]!);
    }

    const pairingGet = path.match(/^\/pairings\/([A-Za-z0-9_-]{16,64})$/);
    if (request.method === 'GET' && pairingGet) {
      return this.getPairing(pairingGet[1]!);
    }
    const inviteGet = path.match(/^\/pairing-invites\/([A-Za-z0-9_-]{16,64})$/);
    if (request.method === 'GET' && inviteGet) {
      return this.getPairingInvite(inviteGet[1]!);
    }
    const inviteJoin = path.match(/^\/pairing-invites\/([A-Za-z0-9_-]{16,64})\/join$/);
    if (request.method === 'POST' && inviteJoin) {
      return this.joinPairingInvite(request, vault, inviteJoin[1]!);
    }

    const auth = await this.authenticate(request, canonicalPath);
    if (auth instanceof Response) return auth;

    if (request.method === 'POST' && path === '/operations') {
      return this.pushOperations(auth, vault);
    }
    if (request.method === 'GET' && path === '/operations') {
      return this.pullOperations(url);
    }
    if (request.method === 'GET' && path === '/state') {
      return this.syncState(url);
    }
    if (request.method === 'POST' && path === '/pairings/authorize') {
      return this.authorizePairing(auth);
    }
    if (request.method === 'POST' && path === '/pairing-invites') {
      return this.createPairingInvite(auth);
    }
    const inviteAuthorize = path.match(/^\/pairing-invites\/([A-Za-z0-9_-]{16,64})\/authorize$/);
    if (request.method === 'POST' && inviteAuthorize) {
      return this.authorizePairingInvite(auth, inviteAuthorize[1]!);
    }
    const inviteConsume = path.match(/^\/pairing-invites\/([A-Za-z0-9_-]{16,64})\/consume$/);
    if (request.method === 'POST' && inviteConsume) {
      return this.consumePairingInvite(auth, inviteConsume[1]!);
    }
    if (request.method === 'POST' && path === '/pairings/consume') {
      return this.consumePairing(auth);
    }
    if (request.method === 'PUT' && path === '/recovery') {
      return this.setRecovery(auth);
    }
    if (request.method === 'POST' && path === '/rotate') {
      return this.rotateVault(auth);
    }
    const rotationGet = path.match(/^\/rotations\/(\d+)$/);
    if (request.method === 'GET' && rotationGet) {
      return this.getRotation(auth.device.device_id, Number(rotationGet[1]));
    }
    if (request.method === 'GET' && path === '/devices') {
      return this.listDevices();
    }
    if (request.method === 'DELETE' && path === '/vault') {
      await this.ctx.storage.deleteAll();
      // deleteAll clears the SQLite schema too. Recreate empty tables while
      // this Durable Object instance is still alive so a fresh vault can
      // bootstrap safely on the same opaque object ID.
      this.ensureSchema();
      return json({ deleted: true });
    }

    return error('not_found', 404);
  }

  private async bootstrap(request: Request, vault: string): Promise<Response> {
    if (this.hasVault()) return error('vault_exists', 409);

    const { value } = await readJson<{
      device_id?: unknown;
      signing_public_key?: unknown;
      exchange_public_key?: unknown;
      timestamp?: unknown;
      nonce?: unknown;
      signature?: unknown;
    }>(request, 16 * 1024);

    const { device_id, signing_public_key, exchange_public_key, timestamp, nonce, signature } = value;
    if (
      !validId(device_id) ||
      !validBase64Url(signing_public_key, 128) ||
      !validBase64Url(exchange_public_key, 128) ||
      !validId(nonce) ||
      typeof timestamp !== 'string' ||
      !clockIsFresh(timestamp) ||
      !validBase64Url(signature, 256)
    ) {
      return error('invalid_bootstrap', 400);
    }
    if (decodeBase64Url(signing_public_key).byteLength !== 32) return error('invalid_signing_key', 400);
    if (decodeBase64Url(exchange_public_key).byteLength !== 32) return error('invalid_exchange_key', 400);

    const validSignature = await verifyEd25519(
      signing_public_key,
      signature,
      bootstrapPayload({
        vault,
        device: device_id,
        signingPublicKey: signing_public_key,
        exchangePublicKey: exchange_public_key,
        timestamp,
        nonce,
      }),
    );
    if (!validSignature) return error('invalid_signature', 401);

    const now = Date.now();
    this.ctx.storage.transactionSync(() => {
      if (this.hasVault()) throw new Error('vault_race');
      this.sql.exec("INSERT INTO meta(key, value) VALUES ('epoch', '1'), ('created_ms', ?)", String(now));
      this.sql.exec(
        `INSERT INTO devices(device_id, signing_public_key, exchange_public_key, added_ms, activated_ms)
         VALUES (?, ?, ?, ?, ?)`,
        device_id,
        signing_public_key,
        exchange_public_key,
        now,
        now,
      );
    });
    return json({ created: true, epoch: 1 }, 201);
  }

  private async authenticate(request: Request, canonicalPath: string): Promise<AuthContext | Response> {
    if (!this.hasVault()) return error('vault_not_found', 404);

    const deviceId = request.headers.get('x-nyla-device');
    const timestamp = request.headers.get('x-nyla-timestamp');
    const nonce = request.headers.get('x-nyla-nonce');
    const signature = request.headers.get('x-nyla-signature');
    if (
      !validId(deviceId) ||
      !timestamp ||
      !clockIsFresh(timestamp) ||
      !validId(nonce) ||
      !signature ||
      !validBase64Url(signature, 256)
    ) {
      return error('authentication_required', 401);
    }

    const device = this.device(deviceId);
    if (!device || device.revoked_ms !== null) return error('device_not_authorized', 401);
    const isPairingActivation =
      canonicalPath.endsWith('/pairings/consume') || /\/pairing-invites\/[A-Za-z0-9_-]{16,64}\/consume$/.test(canonicalPath);
    if (device.activated_ms === null && !isPairingActivation) {
      return error('device_pending_activation', 401);
    }

    const maxBodyBytes = canonicalPath.endsWith('/rotate') ? MAX_ROTATION_BODY_BYTES : 512 * 1024;
    const declared = Number(request.headers.get('content-length') ?? '0');
    if (Number.isFinite(declared) && declared > maxBodyBytes) return error('payload_too_large', 413);
    const body = new Uint8Array(await request.arrayBuffer());
    if (body.byteLength > maxBodyBytes) return error('payload_too_large', 413);
    const bodyHash = await sha256Base64Url(body);
    const validSignature = await verifyEd25519(
      device.signing_public_key,
      signature,
      httpAuthPayload({
        method: request.method,
        path: canonicalPath,
        timestamp,
        nonce,
        bodyHash,
      }),
    );
    if (!validSignature) return error('invalid_signature', 401);

    const now = Date.now();
    this.cleanup(now);
    try {
      this.sql.exec(
        'INSERT INTO auth_nonces(device_id, nonce, expires_ms) VALUES (?, ?, ?)',
        deviceId,
        nonce,
        now + AUTH_NONCE_TTL_MS,
      );
    } catch {
      return error('replayed_request', 409);
    }

    return { device, body };
  }

  private async pushOperations(auth: AuthContext, vault: string): Promise<Response> {
    const parsed = JSON.parse(new TextDecoder().decode(auth.body)) as { operations?: unknown };
    if (!Array.isArray(parsed.operations) || parsed.operations.length === 0) {
      return error('operations_required', 400);
    }
    if (parsed.operations.length > MAX_BATCH_OPERATIONS) return error('too_many_operations', 413);

    const epoch = this.currentEpoch();
    const accepted: string[] = [];
    const duplicate: string[] = [];
    const validated: OperationInput[] = [];

    for (const raw of parsed.operations) {
      if (!this.isOperation(raw, epoch)) return error('invalid_operation', 400);
      const bytes = decodeBase64Url(raw.ciphertext).byteLength;
      if (bytes > MAX_OPERATION_BYTES) return error('operation_too_large', 413);
      const validSignature = await verifyEd25519(
        auth.device.signing_public_key,
        raw.signature,
        envelopePayload({
          vault,
          device: auth.device.device_id,
          epoch: raw.epoch,
          op: raw.op,
          nonce: raw.nonce,
          ciphertext: raw.ciphertext,
        }),
      );
      if (!validSignature) return error('invalid_operation_signature', 401);
      validated.push(raw);
    }

    // Signature verification yields to the event loop. A rotation may have
    // committed while this batch was being verified, so re-check the epoch
    // immediately before the synchronous insertion transaction.
    if (this.currentEpoch() !== epoch) return error('vault_key_epoch_changed', 409);

    const now = Date.now();
    this.ctx.storage.transactionSync(() => {
      for (const op of validated) {
        const existing = this.sql.exec('SELECT cursor FROM operations WHERE op_id = ?', op.op).toArray();
        if (existing.length !== 0) {
          duplicate.push(op.op);
          continue;
        }
        this.sql.exec(
          `INSERT INTO operations(op_id, device_id, epoch, nonce, ciphertext, signature, received_ms)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          op.op,
          auth.device.device_id,
          op.epoch,
          op.nonce,
          op.ciphertext,
          op.signature,
          now,
        );
        accepted.push(op.op);
      }
    });

    const cursorRow = this.sql.exec('SELECT COALESCE(MAX(cursor), 0) AS cursor FROM operations').toArray()[0] as
      | { cursor: number }
      | undefined;
    return json({ accepted, duplicate, cursor: cursorRow?.cursor ?? 0 });
  }

  private pullOperations(url: URL): Response {
    const sinceRaw = url.searchParams.get('since') ?? '0';
    const limitRaw = url.searchParams.get('limit') ?? String(DEFAULT_PULL_OPERATIONS);
    if (!/^\d+$/.test(sinceRaw) || !/^\d+$/.test(limitRaw)) return error('invalid_cursor', 400);
    const since = Number(sinceRaw);
    const limit = Math.min(Number(limitRaw), MAX_PULL_OPERATIONS);
    if (!Number.isSafeInteger(since) || since < 0 || !Number.isSafeInteger(limit) || limit < 1) {
      return error('invalid_cursor', 400);
    }

    const rows = this.sql
      .exec(
        `SELECT cursor, op_id, device_id, epoch, nonce, ciphertext, signature, received_ms
         FROM operations WHERE cursor > ? ORDER BY cursor ASC LIMIT ?`,
        since,
        limit,
      )
      .toArray() as unknown as OperationRow[];
    const latest = rows.length === 0 ? since : rows[rows.length - 1]!.cursor;
    const hasMore = this.sql.exec('SELECT 1 AS present FROM operations WHERE cursor > ? LIMIT 1', latest).toArray().length > 0;

    return json({ operations: rows, next_cursor: latest, has_more: hasMore, epoch: this.currentEpoch() });
  }

  private createPairingInvite(auth: AuthContext): Response {
    const body = JSON.parse(new TextDecoder().decode(auth.body)) as Record<string, unknown>;
    const pairingId = body['pairing_id'];
    const tokenHash = body['token_hash'];
    if (!validId(pairingId) || !validBase64Url(tokenHash, 128) || decodeBase64Url(tokenHash).byteLength !== 32) {
      return error('invalid_pairing_invite', 400);
    }
    const now = Date.now();
    try {
      this.sql.exec(
        `INSERT INTO pairing_invites(pairing_id, inviter_device_id, token_hash, created_ms, expires_ms)
         VALUES (?, ?, ?, ?, ?)`,
        pairingId,
        auth.device.device_id,
        tokenHash,
        now,
        now + PAIRING_TTL_MS,
      );
    } catch {
      return error('pairing_conflict', 409);
    }
    return json({ created: true, pairing_id: pairingId, expires_ms: now + PAIRING_TTL_MS }, 201);
  }

  private async joinPairingInvite(request: Request, vault: string, pairingId: string): Promise<Response> {
    this.cleanup(Date.now());
    const invite = this.sql
      .exec(
        `SELECT pairing_id, token_hash, target_device_id, expires_ms, consumed_ms
         FROM pairing_invites WHERE pairing_id = ?`,
        pairingId,
      )
      .toArray()[0] as
      | { pairing_id: string; token_hash: string; target_device_id: string | null; expires_ms: number; consumed_ms: number | null }
      | undefined;
    if (!invite || invite.expires_ms < Date.now() || invite.consumed_ms !== null) return error('pairing_not_found', 404);
    if (invite.target_device_id !== null) return error('pairing_already_joined', 409);

    const { value } = await readJson<{
      token_hash?: unknown;
      target_device_id?: unknown;
      signing_public_key?: unknown;
      exchange_public_key?: unknown;
      timestamp?: unknown;
      nonce?: unknown;
      signature?: unknown;
    }>(request, 16 * 1024);
    const { token_hash, target_device_id, signing_public_key, exchange_public_key, timestamp, nonce, signature } = value;
    if (
      token_hash !== invite.token_hash ||
      !validId(target_device_id) ||
      !validBase64Url(signing_public_key, 128) ||
      !validBase64Url(exchange_public_key, 128) ||
      decodeBase64Url(signing_public_key).byteLength !== 32 ||
      decodeBase64Url(exchange_public_key).byteLength !== 32 ||
      typeof timestamp !== 'string' ||
      !clockIsFresh(timestamp) ||
      !validId(nonce) ||
      !validBase64Url(signature, 256)
    ) {
      return error('invalid_pairing_join', 400);
    }
    if (this.device(target_device_id)) return error('device_exists', 409);
    const verified = await verifyEd25519(
      signing_public_key,
      signature,
      pairingJoinPayload({
        vault,
        pairingId,
        tokenHash: token_hash,
        device: target_device_id,
        signingPublicKey: signing_public_key,
        exchangePublicKey: exchange_public_key,
        timestamp,
        nonce,
      }),
    );
    if (!verified) return error('invalid_pairing_join_signature', 401);

    const now = Date.now();
    this.ctx.storage.transactionSync(() => {
      this.sql.exec(
        `UPDATE pairing_invites SET target_device_id = ?, target_signing_public_key = ?,
         target_exchange_public_key = ? WHERE pairing_id = ? AND target_device_id IS NULL`,
        target_device_id,
        signing_public_key,
        exchange_public_key,
        pairingId,
      );
      this.sql.exec(
        `INSERT INTO devices(device_id, signing_public_key, exchange_public_key, added_ms, activated_ms, pending_pairing_id)
         VALUES (?, ?, ?, ?, NULL, ?)`,
        target_device_id,
        signing_public_key,
        exchange_public_key,
        now,
        pairingId,
      );
    });
    return json({ joined: true, expires_ms: invite.expires_ms }, 201);
  }

  private getPairingInvite(pairingId: string): Response {
    this.cleanup(Date.now());
    const row = this.sql
      .exec(
        `SELECT pairing_id, inviter_device_id, target_device_id, target_signing_public_key,
                target_exchange_public_key, package_nonce, package_ciphertext, expires_ms,
                authorized_ms, consumed_ms
         FROM pairing_invites WHERE pairing_id = ?`,
        pairingId,
      )
      .toArray()[0] as Record<string, unknown> | undefined;
    if (!row) return error('pairing_not_found', 404);
    return json(row);
  }

  private authorizePairingInvite(auth: AuthContext, pairingId: string): Response {
    const body = JSON.parse(new TextDecoder().decode(auth.body)) as Record<string, unknown>;
    const packageNonce = body['package_nonce'];
    const packageCiphertext = body['package_ciphertext'];
    if (!validBase64Url(packageNonce, 128) || !validBase64Url(packageCiphertext, 4096)) {
      return error('invalid_pairing_package', 400);
    }
    const row = this.sql
      .exec(
        `SELECT inviter_device_id, target_device_id, expires_ms, authorized_ms, consumed_ms
         FROM pairing_invites WHERE pairing_id = ?`,
        pairingId,
      )
      .toArray()[0] as
      | { inviter_device_id: string; target_device_id: string | null; expires_ms: number; authorized_ms: number | null; consumed_ms: number | null }
      | undefined;
    if (!row || row.inviter_device_id !== auth.device.device_id || row.expires_ms < Date.now() || row.consumed_ms !== null) {
      return error('pairing_not_found', 404);
    }
    if (row.target_device_id === null) return error('pairing_not_joined', 409);
    if (row.authorized_ms !== null) return error('pairing_already_authorized', 409);
    const now = Date.now();
    this.sql.exec(
      `UPDATE pairing_invites SET package_nonce = ?, package_ciphertext = ?, authorized_ms = ? WHERE pairing_id = ?`,
      packageNonce,
      packageCiphertext,
      now,
      pairingId,
    );
    return json({ authorized: true, target_device_id: row.target_device_id });
  }

  private consumePairingInvite(auth: AuthContext, pairingId: string): Response {
    const row = this.sql
      .exec(
        `SELECT target_device_id, expires_ms, authorized_ms, consumed_ms
         FROM pairing_invites WHERE pairing_id = ?`,
        pairingId,
      )
      .toArray()[0] as
      | { target_device_id: string | null; expires_ms: number; authorized_ms: number | null; consumed_ms: number | null }
      | undefined;
    if (
      !row ||
      row.target_device_id !== auth.device.device_id ||
      row.expires_ms < Date.now() ||
      row.authorized_ms === null ||
      row.consumed_ms !== null
    ) {
      return error('pairing_not_found', 404);
    }
    const now = Date.now();
    this.ctx.storage.transactionSync(() => {
      this.sql.exec('UPDATE pairing_invites SET consumed_ms = ? WHERE pairing_id = ?', now, pairingId);
      this.sql.exec(
        'UPDATE devices SET activated_ms = ?, pending_pairing_id = NULL WHERE device_id = ? AND pending_pairing_id = ?',
        now,
        auth.device.device_id,
        pairingId,
      );
    });
    return json({ consumed: true, activated: true });
  }

  private async authorizePairing(auth: AuthContext): Promise<Response> {
    const body = JSON.parse(new TextDecoder().decode(auth.body)) as Record<string, unknown>;
    const pairingId = body['pairing_id'];
    const targetDeviceId = body['target_device_id'];
    const signingPublicKey = body['signing_public_key'];
    const exchangePublicKey = body['exchange_public_key'];
    const ephemeralPublicKey = body['ephemeral_public_key'];
    const packageNonce = body['package_nonce'];
    const packageCiphertext = body['package_ciphertext'];
    if (
      !validId(pairingId) ||
      !validId(targetDeviceId) ||
      !validBase64Url(signingPublicKey, 128) ||
      !validBase64Url(exchangePublicKey, 128) ||
      !validBase64Url(ephemeralPublicKey, 128) ||
      !validBase64Url(packageNonce, 128) ||
      !validBase64Url(packageCiphertext, 16384)
    ) {
      return error('invalid_pairing', 400);
    }
    if (
      decodeBase64Url(signingPublicKey).byteLength !== 32 ||
      decodeBase64Url(exchangePublicKey).byteLength !== 32 ||
      decodeBase64Url(ephemeralPublicKey).byteLength !== 32
    ) {
      return error('invalid_pairing_keys', 400);
    }
    if (this.device(targetDeviceId)) return error('device_exists', 409);

    const now = Date.now();
    try {
      this.ctx.storage.transactionSync(() => {
        this.sql.exec(
          `INSERT INTO pairings(
             pairing_id, target_device_id, target_signing_public_key, target_exchange_public_key,
             ephemeral_public_key, package_nonce, package_ciphertext, inviter_device_id, created_ms, expires_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          pairingId,
          targetDeviceId,
          signingPublicKey,
          exchangePublicKey,
          ephemeralPublicKey,
          packageNonce,
          packageCiphertext,
          auth.device.device_id,
          now,
          now + PAIRING_TTL_MS,
        );
        this.sql.exec(
          `INSERT INTO devices(
             device_id, signing_public_key, exchange_public_key, added_ms, activated_ms, pending_pairing_id
           ) VALUES (?, ?, ?, ?, NULL, ?)`,
          targetDeviceId,
          signingPublicKey,
          exchangePublicKey,
          now,
          pairingId,
        );
      });
    } catch {
      return error('pairing_conflict', 409);
    }
    return json({ authorized: true, expires_ms: now + PAIRING_TTL_MS }, 201);
  }

  private getPairing(pairingId: string): Response {
    this.cleanup(Date.now());
    const row = this.sql
      .exec(
        `SELECT pairing_id, target_device_id, ephemeral_public_key, package_nonce, package_ciphertext,
                inviter_device_id, expires_ms, consumed_ms
         FROM pairings WHERE pairing_id = ?`,
        pairingId,
      )
      .toArray()[0] as Record<string, unknown> | undefined;
    if (!row || row['consumed_ms'] !== null) return error('pairing_not_found', 404);
    return json(row);
  }

  private consumePairing(auth: AuthContext): Response {
    const body = JSON.parse(new TextDecoder().decode(auth.body)) as { pairing_id?: unknown };
    if (!validId(body.pairing_id)) return error('invalid_pairing', 400);
    const row = this.sql
      .exec('SELECT target_device_id, consumed_ms, expires_ms FROM pairings WHERE pairing_id = ?', body.pairing_id)
      .toArray()[0] as { target_device_id: string; consumed_ms: number | null; expires_ms: number } | undefined;
    if (
      !row ||
      row.target_device_id !== auth.device.device_id ||
      row.consumed_ms !== null ||
      row.expires_ms < Date.now()
    ) {
      return error('pairing_not_found', 404);
    }
    const now = Date.now();
    this.ctx.storage.transactionSync(() => {
      this.sql.exec('UPDATE pairings SET consumed_ms = ? WHERE pairing_id = ?', now, body.pairing_id);
      this.sql.exec(
        'UPDATE devices SET activated_ms = ?, pending_pairing_id = NULL WHERE device_id = ? AND pending_pairing_id = ?',
        now,
        auth.device.device_id,
        body.pairing_id,
      );
    });
    return json({ consumed: true, activated: true });
  }

  private setRecovery(auth: AuthContext): Response {
    const body = JSON.parse(new TextDecoder().decode(auth.body)) as Record<string, unknown>;
    const recoveryId = body['recovery_id'];
    const recoverySigningPublicKey = body['recovery_signing_public_key'];
    const wrapNonce = body['wrap_nonce'];
    const wrappedVaultKey = body['wrapped_vault_key'];
    if (
      !validId(recoveryId) ||
      !validBase64Url(recoverySigningPublicKey, 128) ||
      !validBase64Url(wrapNonce, 128) ||
      !validBase64Url(wrappedVaultKey, 2048)
    ) {
      return error('invalid_recovery_envelope', 400);
    }
    if (decodeBase64Url(recoverySigningPublicKey).byteLength !== 32) {
      return error('invalid_recovery_key', 400);
    }
    this.sql.exec(
      `INSERT INTO recovery(slot, recovery_id, recovery_signing_public_key, wrap_nonce, wrapped_vault_key, created_ms)
       VALUES (1, ?, ?, ?, ?, ?)
       ON CONFLICT(slot) DO UPDATE SET recovery_id = excluded.recovery_id,
         recovery_signing_public_key = excluded.recovery_signing_public_key,
         wrap_nonce = excluded.wrap_nonce,
         wrapped_vault_key = excluded.wrapped_vault_key,
         created_ms = excluded.created_ms`,
      recoveryId,
      recoverySigningPublicKey,
      wrapNonce,
      wrappedVaultKey,
      Date.now(),
    );
    return json({ recovery_configured: true, by_device: auth.device.device_id });
  }

  private getRecovery(recoveryId: string): Response {
    const row = this.sql
      .exec(
        'SELECT recovery_id, wrap_nonce, wrapped_vault_key, created_ms FROM recovery WHERE recovery_id = ?',
        recoveryId,
      )
      .toArray()[0] as Record<string, unknown> | undefined;
    if (!row) return error('recovery_not_found', 404);
    return json(row);
  }

  private async recoverDevice(request: Request, vault: string, recoveryId: string): Promise<Response> {
    this.limitRecoveryAttempts();
    const { value } = await readJson<{
      device_id?: unknown;
      signing_public_key?: unknown;
      exchange_public_key?: unknown;
      timestamp?: unknown;
      nonce?: unknown;
      signature?: unknown;
    }>(request, 16 * 1024);
    const { device_id, signing_public_key, exchange_public_key, timestamp, nonce, signature } = value;
    if (
      !validId(device_id) ||
      !validBase64Url(signing_public_key, 128) ||
      !validBase64Url(exchange_public_key, 128) ||
      typeof timestamp !== 'string' ||
      !clockIsFresh(timestamp) ||
      !validId(nonce) ||
      !validBase64Url(signature, 256)
    ) {
      return error('invalid_recovery_enrollment', 400);
    }
    const recovery = this.sql
      .exec('SELECT recovery_signing_public_key FROM recovery WHERE recovery_id = ?', recoveryId)
      .toArray()[0] as { recovery_signing_public_key: string } | undefined;
    if (!recovery) return error('recovery_not_found', 404);

    const verified = await verifyEd25519(
      recovery.recovery_signing_public_key,
      signature,
      recoveryEnrollmentPayload({
        vault,
        recoveryId,
        device: device_id,
        signingPublicKey: signing_public_key,
        exchangePublicKey: exchange_public_key,
        timestamp,
        nonce,
      }),
    );
    if (!verified) return error('invalid_recovery_signature', 401);

    if (
      decodeBase64Url(signing_public_key).byteLength !== 32 ||
      decodeBase64Url(exchange_public_key).byteLength !== 32
    ) {
      return error('invalid_recovery_device_keys', 400);
    }

    const now = Date.now();
    this.sql.exec(
      `INSERT INTO devices(
         device_id, signing_public_key, exchange_public_key, added_ms, activated_ms, pending_pairing_id, revoked_ms
       ) VALUES (?, ?, ?, ?, ?, NULL, NULL)
       ON CONFLICT(device_id) DO UPDATE SET signing_public_key = excluded.signing_public_key,
         exchange_public_key = excluded.exchange_public_key, added_ms = excluded.added_ms,
         activated_ms = excluded.activated_ms, pending_pairing_id = NULL, revoked_ms = NULL`,
      device_id,
      signing_public_key,
      exchange_public_key,
      now,
      now,
    );
    return json({ enrolled: true, epoch: this.currentEpoch() }, 201);
  }

  private rotateVault(auth: AuthContext): Response {
    const body = JSON.parse(new TextDecoder().decode(auth.body)) as {
      rotation_id?: unknown;
      new_epoch?: unknown;
      base_cursor?: unknown;
      revoke_device_ids?: unknown;
      packages?: unknown;
      checkpoint?: unknown;
      recovery?: unknown;
    };
    if (!validId(body.rotation_id)) return error('invalid_rotation', 400);
    const prior = this.sql
      .exec('SELECT epoch, base_cursor FROM checkpoints WHERE rotation_id = ?', body.rotation_id)
      .toArray()[0] as { epoch: number; base_cursor: number } | undefined;
    if (prior) {
      return json({
        rotated: true,
        rotation_id: body.rotation_id,
        epoch: prior.epoch,
        base_cursor: prior.base_cursor,
        idempotent: true,
      });
    }

    const current = this.currentEpoch();
    if (typeof body.new_epoch !== 'number' || body.new_epoch !== current + 1) {
      return error('invalid_epoch', 409);
    }
    if (
      typeof body.base_cursor !== 'number' ||
      !Number.isSafeInteger(body.base_cursor) ||
      body.base_cursor < 0 ||
      !Array.isArray(body.revoke_device_ids) ||
      !Array.isArray(body.packages) ||
      typeof body.checkpoint !== 'object' ||
      body.checkpoint === null ||
      typeof body.recovery !== 'object' ||
      body.recovery === null
    ) {
      return error('invalid_rotation', 400);
    }

    const revoked = new Set<string>();
    for (const value of body.revoke_device_ids) {
      if (!validId(value)) return error('invalid_rotation', 400);
      if (value === auth.device.device_id) return error('cannot_revoke_rotating_device', 400);
      const target = this.device(value);
      if (!target || target.revoked_ms !== null || target.activated_ms === null) return error('device_not_found', 404);
      revoked.add(value);
    }

    const packages: Array<{
      target_device_id: string;
      ephemeral_public_key: string;
      package_nonce: string;
      package_ciphertext: string;
    }> = [];
    const seenTargets = new Set<string>();
    for (const raw of body.packages) {
      if (typeof raw !== 'object' || raw === null) return error('invalid_rotation', 400);
      const record = raw as Record<string, unknown>;
      const target = record['target_device_id'];
      const ephemeralPublicKey = record['ephemeral_public_key'];
      const nonce = record['package_nonce'];
      const ciphertext = record['package_ciphertext'];
      if (
        !validId(target) ||
        !validBase64Url(ephemeralPublicKey, 128) ||
        decodeBase64Url(ephemeralPublicKey).byteLength !== 32 ||
        !validBase64Url(nonce, 128) ||
        decodeBase64Url(nonce).byteLength !== 24 ||
        !validBase64Url(ciphertext, 4096)
      ) {
        return error('invalid_rotation', 400);
      }
      if (seenTargets.has(target)) return error('duplicate_rotation_target', 400);
      seenTargets.add(target);
      if (revoked.has(target)) return error('rotation_targets_revoked_device', 400);
      const device = this.device(target);
      if (!device || device.revoked_ms !== null || device.activated_ms === null) {
        return error('rotation_targets_unknown_device', 400);
      }
      packages.push({
        target_device_id: target,
        ephemeral_public_key: ephemeralPublicKey,
        package_nonce: nonce,
        package_ciphertext: ciphertext,
      });
    }

    const active = this.activeDeviceIds().filter((id) => !revoked.has(id)).sort();
    const targets = [...seenTargets].sort();
    if (active.length !== targets.length || active.some((value, index) => value !== targets[index])) {
      return error('rotation_missing_device_package', 400);
    }

    const checkpoint = body.checkpoint as Record<string, unknown>;
    const checkpointNonce = checkpoint['nonce'];
    const checkpointCiphertext = checkpoint['ciphertext'];
    if (
      !validBase64Url(checkpointNonce, 128) ||
      decodeBase64Url(checkpointNonce).byteLength !== 24 ||
      !validBase64Url(checkpointCiphertext, Math.ceil((MAX_ROTATION_CHECKPOINT_BYTES * 4) / 3) + 8) ||
      decodeBase64Url(checkpointCiphertext).byteLength > MAX_ROTATION_CHECKPOINT_BYTES
    ) {
      return error('invalid_rotation_checkpoint', 400);
    }

    const recovery = body.recovery as Record<string, unknown>;
    const recoveryId = recovery['recovery_id'];
    const recoverySigningPublicKey = recovery['recovery_signing_public_key'];
    const recoveryWrapNonce = recovery['wrap_nonce'];
    const wrappedVaultKey = recovery['wrapped_vault_key'];
    if (
      !validId(recoveryId) ||
      !validBase64Url(recoverySigningPublicKey, 128) ||
      decodeBase64Url(recoverySigningPublicKey).byteLength !== 32 ||
      !validBase64Url(recoveryWrapNonce, 128) ||
      decodeBase64Url(recoveryWrapNonce).byteLength !== 24 ||
      !validBase64Url(wrappedVaultKey, 2048)
    ) {
      return error('invalid_rotation_recovery', 400);
    }

    // Rotation is only valid for an exact materialized prefix. There are no
    // awaits after this check, so another request cannot insert an operation
    // between this cursor check and the synchronous transaction below.
    if (this.currentEpoch() !== current) return error('invalid_epoch', 409);
    const cursorRow = this.sql.exec('SELECT COALESCE(MAX(cursor), 0) AS cursor FROM operations').toArray()[0] as
      | { cursor: number }
      | undefined;
    if ((cursorRow?.cursor ?? 0) !== body.base_cursor) return error('rotation_stale_cursor', 409);

    const now = Date.now();
    this.ctx.storage.transactionSync(() => {
      for (const deviceId of revoked) {
        this.sql.exec('UPDATE devices SET revoked_ms = ? WHERE device_id = ? AND revoked_ms IS NULL', now, deviceId);
      }
      for (const item of packages) {
        this.sql.exec(
          `INSERT INTO rotations(
             epoch, target_device_id, source_device_id, ephemeral_public_key,
             package_nonce, package_ciphertext, created_ms
           ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
          body.new_epoch as number,
          item.target_device_id,
          auth.device.device_id,
          item.ephemeral_public_key,
          item.package_nonce,
          item.package_ciphertext,
          now,
        );
      }
      this.sql.exec(
        'INSERT INTO checkpoints(epoch, rotation_id, base_cursor, nonce, ciphertext, created_ms) VALUES (?, ?, ?, ?, ?, ?)',
        body.new_epoch as number,
        body.rotation_id,
        body.base_cursor as number,
        checkpointNonce,
        checkpointCiphertext,
        now,
      );
      this.sql.exec(
        `INSERT INTO recovery(slot, recovery_id, recovery_signing_public_key, wrap_nonce, wrapped_vault_key, created_ms)
         VALUES (1, ?, ?, ?, ?, ?)
         ON CONFLICT(slot) DO UPDATE SET recovery_id = excluded.recovery_id,
           recovery_signing_public_key = excluded.recovery_signing_public_key,
           wrap_nonce = excluded.wrap_nonce,
           wrapped_vault_key = excluded.wrapped_vault_key,
           created_ms = excluded.created_ms`,
        recoveryId,
        recoverySigningPublicKey,
        recoveryWrapNonce,
        wrappedVaultKey,
        now,
      );
      this.sql.exec("UPDATE meta SET value = ? WHERE key = 'epoch'", String(body.new_epoch));
    });

    return json({
      rotated: true,
      rotation_id: body.rotation_id,
      epoch: body.new_epoch,
      base_cursor: body.base_cursor,
      revoked: [...revoked],
    });
  }

  private getRotation(deviceId: string, epoch: number): Response {
    if (!Number.isSafeInteger(epoch) || epoch < 2) return error('invalid_epoch', 400);
    const row = this.sql
      .exec(
        `SELECT epoch, target_device_id, source_device_id, ephemeral_public_key,
                package_nonce, package_ciphertext, created_ms
         FROM rotations WHERE epoch = ? AND target_device_id = ?`,
        epoch,
        deviceId,
      )
      .toArray()[0] as Record<string, unknown> | undefined;
    if (!row || typeof row['source_device_id'] !== 'string' || typeof row['ephemeral_public_key'] !== 'string') {
      return error('rotation_not_found', 404);
    }
    return json(row);
  }

  private syncState(url: URL): Response {
    const knownEpochRaw = url.searchParams.get('known_epoch') ?? '0';
    const cursorRaw = url.searchParams.get('cursor') ?? '0';
    if (!/^\d+$/.test(knownEpochRaw) || !/^\d+$/.test(cursorRaw)) return error('invalid_sync_state', 400);
    const knownEpoch = Number(knownEpochRaw);
    const cursor = Number(cursorRaw);
    if (!Number.isSafeInteger(knownEpoch) || !Number.isSafeInteger(cursor) || knownEpoch < 0 || cursor < 0) {
      return error('invalid_sync_state', 400);
    }

    const epoch = this.currentEpoch();
    if (epoch < 2) return json({ epoch, rotation_id: null, checkpoint: null });
    const checkpoint = this.sql
      .exec('SELECT epoch, rotation_id, base_cursor, nonce, ciphertext, created_ms FROM checkpoints WHERE epoch = ?', epoch)
      .toArray()[0] as Record<string, unknown> | undefined;
    if (!checkpoint) return error('rotation_checkpoint_missing', 500);
    const baseCursor = checkpoint['base_cursor'];
    if (typeof baseCursor !== 'number') return error('rotation_checkpoint_invalid', 500);
    const rotationId = checkpoint['rotation_id'];
    if (typeof rotationId !== 'string') return error('rotation_checkpoint_invalid', 500);
    if (knownEpoch === epoch && cursor >= baseCursor) return json({ epoch, rotation_id: rotationId, checkpoint: null });
    return json({ epoch, rotation_id: rotationId, checkpoint });
  }

  private listDevices(): Response {
    const rows = this.sql
      .exec(
        `SELECT device_id, signing_public_key, exchange_public_key, added_ms, activated_ms, revoked_ms
         FROM devices WHERE activated_ms IS NOT NULL ORDER BY added_ms ASC`,
      )
      .toArray();
    return json({ devices: rows, epoch: this.currentEpoch() });
  }

  private hasVault(): boolean {
    return this.sql.exec("SELECT 1 AS present FROM meta WHERE key = 'epoch' LIMIT 1").toArray().length !== 0;
  }

  private currentEpoch(): number {
    const row = this.sql.exec("SELECT value FROM meta WHERE key = 'epoch'").toArray()[0] as MetaRow | undefined;
    return row ? Number(row.value) : 0;
  }

  private device(deviceId: string): DeviceRow | undefined {
    return this.sql
      .exec(
        `SELECT device_id, signing_public_key, exchange_public_key, activated_ms, pending_pairing_id, revoked_ms
         FROM devices WHERE device_id = ?`,
        deviceId,
      )
      .toArray()[0] as DeviceRow | undefined;
  }

  private activeDeviceIds(): string[] {
    return (
      this.sql
        .exec('SELECT device_id FROM devices WHERE revoked_ms IS NULL AND activated_ms IS NOT NULL')
        .toArray() as Array<{ device_id: string }>
    ).map((row) => row.device_id);
  }

  private cleanup(now: number): void {
    this.ctx.storage.transactionSync(() => {
      this.sql.exec('DELETE FROM auth_nonces WHERE expires_ms < ?', now);
      this.sql.exec(
        `DELETE FROM devices
         WHERE activated_ms IS NULL AND pending_pairing_id IN (
           SELECT pairing_id FROM pairings WHERE expires_ms < ? AND consumed_ms IS NULL
         )`,
        now,
      );
      this.sql.exec(
        `DELETE FROM devices
         WHERE activated_ms IS NULL AND pending_pairing_id IN (
           SELECT pairing_id FROM pairing_invites WHERE expires_ms < ? AND consumed_ms IS NULL
         )`,
        now,
      );
      this.sql.exec('DELETE FROM pairings WHERE expires_ms < ?', now);
      this.sql.exec('DELETE FROM pairing_invites WHERE expires_ms < ?', now);
      this.sql.exec('DELETE FROM recovery_attempts WHERE attempted_ms < ?', now - 60 * 60 * 1000);
    });
  }

  private limitRecoveryAttempts(): void {
    const now = Date.now();
    this.cleanup(now);
    const row = this.sql.exec('SELECT COUNT(*) AS count FROM recovery_attempts').toArray()[0] as
      | { count: number }
      | undefined;
    if ((row?.count ?? 0) >= 5) throw new RecoveryRateLimitError();
    this.sql.exec('INSERT INTO recovery_attempts(attempted_ms) VALUES (?)', now);
  }

  private isOperation(value: unknown, epoch: number): value is OperationInput {
    if (typeof value !== 'object' || value === null) return false;
    const op = value as Partial<OperationInput>;
    return (
      op.v === 1 &&
      validId(op.op) &&
      op.epoch === epoch &&
      validBase64Url(op.nonce, 128) &&
      validBase64Url(op.ciphertext, 131072) &&
      validBase64Url(op.signature, 256)
    );
  }
}

class RecoveryRateLimitError extends Error {}
