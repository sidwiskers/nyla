import { exports } from 'cloudflare:workers';
import { beforeEach, describe, expect, it } from 'vitest';

import '../src/index';
import {
  bootstrapPayload,
  encodeBase64Url,
  httpAuthPayload,
  sha256Base64Url,
} from '../src/protocol';

const encoder = new TextEncoder();
const empty = new Uint8Array(new ArrayBuffer(0));

interface TestIdentity {
  vaultId: string;
  deviceId: string;
  privateKey: CryptoKey;
  signingPublicKey: string;
  exchangePublicKey: string;
}

let counter = 0;

function uniqueId(prefix: string): string {
  counter += 1;
  return `${prefix}_${Date.now()}_${counter}`.replace(/[^A-Za-z0-9_-]/g, '_');
}

async function identity(): Promise<TestIdentity> {
  const keys = await crypto.subtle.generateKey({ name: 'Ed25519' }, true, ['sign', 'verify']);
  const publicBytes = await crypto.subtle.exportKey('raw', keys.publicKey);
  const exchange = crypto.getRandomValues(new Uint8Array(32));
  return {
    vaultId: uniqueId('vault_runtime'),
    deviceId: uniqueId('device_runtime'),
    privateKey: keys.privateKey,
    signingPublicKey: encodeBase64Url(publicBytes),
    exchangePublicKey: encodeBase64Url(exchange),
  };
}

async function sign(privateKey: CryptoKey, payload: Uint8Array<ArrayBuffer>): Promise<string> {
  return encodeBase64Url(await crypto.subtle.sign({ name: 'Ed25519' }, privateKey, payload));
}

async function bootstrap(subject: TestIdentity): Promise<Response> {
  const timestamp = `${Date.now()}`;
  const nonce = uniqueId('bootstrap_nonce');
  const signature = await sign(
    subject.privateKey,
    bootstrapPayload({
      vault: subject.vaultId,
      device: subject.deviceId,
      signingPublicKey: subject.signingPublicKey,
      exchangePublicKey: subject.exchangePublicKey,
      timestamp,
      nonce,
    }),
  );
  return exports.default.fetch(`https://nyla.test/v1/vaults/${subject.vaultId}/bootstrap`, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      device_id: subject.deviceId,
      signing_public_key: subject.signingPublicKey,
      exchange_public_key: subject.exchangePublicKey,
      timestamp,
      nonce,
      signature,
    }),
  });
}

async function authenticated(
  subject: TestIdentity,
  method: string,
  suffix: string,
  options: { body?: Uint8Array<ArrayBuffer>; nonce?: string } = {},
): Promise<Response> {
  const path = `/v1/vaults/${subject.vaultId}${suffix}`;
  const body = options.body ?? empty;
  const timestamp = `${Date.now()}`;
  const nonce = options.nonce ?? uniqueId('request_nonce');
  const bodyHash = await sha256Base64Url(body);
  const signature = await sign(
    subject.privateKey,
    httpAuthPayload({ method, path, timestamp, nonce, bodyHash }),
  );
  return exports.default.fetch(`https://nyla.test${path}`, {
    method,
    headers: {
      'x-nyla-device': subject.deviceId,
      'x-nyla-timestamp': timestamp,
      'x-nyla-nonce': nonce,
      'x-nyla-signature': signature,
      ...(body.byteLength === 0 ? {} : { 'content-type': 'application/json' }),
    },
    ...(method === 'GET' || method === 'HEAD' ? {} : { body }),
  });
}

describe('Nyla relay in Workers runtime', () => {
  beforeEach(() => {
    counter = 0;
  });

  it('exposes only a minimal no-store health endpoint outside vault routes', async () => {
    const response = await exports.default.fetch('https://nyla.test/health');
    expect(response.status).toBe(200);
    expect(response.headers.get('cache-control')).toBe('no-store');
    expect(await response.text()).toBe('ok');

    const missing = await exports.default.fetch('https://nyla.test/not-a-vault');
    expect(missing.status).toBe(404);
    expect(await missing.json()).toEqual({ error: 'not_found' });
  });

  it('bootstraps a signed vault and persists its authorized device in SQLite', async () => {
    const subject = await identity();
    const created = await bootstrap(subject);
    expect(created.status).toBe(201);
    expect(await created.json()).toEqual({ created: true, epoch: 1 });

    const devices = await authenticated(subject, 'GET', '/devices');
    expect(devices.status).toBe(200);
    const payload = (await devices.json()) as {
      epoch: number;
      devices: Array<{
        device_id: string;
        signing_public_key: string;
        exchange_public_key: string;
        revoked_ms: number | null;
      }>;
    };
    expect(payload.epoch).toBe(1);
    expect(payload.devices).toHaveLength(1);
    expect(payload.devices[0]).toMatchObject({
      device_id: subject.deviceId,
      signing_public_key: subject.signingPublicKey,
      exchange_public_key: subject.exchangePublicKey,
      revoked_ms: null,
    });
  });

  it('rejects a second bootstrap for the same vault before accepting attacker material', async () => {
    const subject = await identity();
    const first = await bootstrap(subject);
    expect(first.status).toBe(201);
    await first.text();

    const second = await bootstrap(subject);
    expect(second.status).toBe(409);
    expect(await second.json()).toEqual({ error: 'vault_exists' });
  });

  it('rejects replayed authenticated requests using the durable nonce register', async () => {
    const subject = await identity();
    const created = await bootstrap(subject);
    expect(created.status).toBe(201);
    await created.text();

    const nonce = uniqueId('stable_nonce');
    const first = await authenticated(subject, 'GET', '/state?known_epoch=1&cursor=0', { nonce });
    expect(first.status).toBe(200);
    expect(await first.json()).toEqual({ epoch: 1, rotation_id: null, checkpoint: null });

    // The exact same nonce remains invalid even though the signature/timestamp
    // are otherwise fresh. This is stateful behavior inside the Durable Object.
    const replay = await authenticated(subject, 'GET', '/state?known_epoch=1&cursor=0', { nonce });
    expect(replay.status).toBe(409);
    expect(await replay.json()).toEqual({ error: 'replayed_request' });
  });

  it('authenticated deletion erases the entire vault and allows only a fresh bootstrap afterward', async () => {
    const subject = await identity();
    const created = await bootstrap(subject);
    expect(created.status).toBe(201);
    await created.text();

    const deleted = await authenticated(subject, 'DELETE', '/vault');
    expect(deleted.status).toBe(200);
    expect(await deleted.json()).toEqual({ deleted: true });

    const oldAccess = await authenticated(subject, 'GET', '/devices');
    expect(oldAccess.status).toBe(404);
    expect(await oldAccess.json()).toEqual({ error: 'vault_not_initialized' });

    const recreated = await bootstrap(subject);
    expect(recreated.status).toBe(201);
    expect(await recreated.json()).toEqual({ created: true, epoch: 1 });
  });

  it('fails closed on unsigned vault access', async () => {
    const subject = await identity();
    const created = await bootstrap(subject);
    expect(created.status).toBe(201);
    await created.text();

    const response = await exports.default.fetch(`https://nyla.test/v1/vaults/${subject.vaultId}/devices`);
    expect(response.status).toBe(401);
    expect(await response.json()).toEqual({ error: 'authentication_required' });
  });
});
