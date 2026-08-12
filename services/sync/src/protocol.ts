export const PROTOCOL_VERSION = 1;
export const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;
export const AUTH_NONCE_TTL_MS = 10 * 60 * 1000;
export const PAIRING_TTL_MS = 10 * 60 * 1000;
export const MAX_OPERATION_BYTES = 64 * 1024;
export const MAX_BATCH_OPERATIONS = 128;
export const MAX_PULL_OPERATIONS = 256;
export const DEFAULT_PULL_OPERATIONS = 100;

const encoder = new TextEncoder();
const idPattern = /^[A-Za-z0-9_-]{16,64}$/;
const base64UrlPattern = /^[A-Za-z0-9_-]+$/;

export function validId(value: unknown): value is string {
  return typeof value === 'string' && idPattern.test(value);
}

export function validBase64Url(value: unknown, maxLength = 131072): value is string {
  return (
    typeof value === 'string' &&
    value.length > 0 &&
    value.length <= maxLength &&
    base64UrlPattern.test(value)
  );
}

export function decodeBase64Url(value: string): Uint8Array<ArrayBuffer> {
  const padding = '='.repeat((4 - (value.length % 4)) % 4);
  const binary = atob(value.replace(/-/g, '+').replace(/_/g, '/') + padding);
  const bytes = new Uint8Array(new ArrayBuffer(binary.length));
  for (let i = 0; i < binary.length; i += 1) bytes[i] = binary.charCodeAt(i);
  return bytes;
}

export function encodeBase64Url(bytes: ArrayBuffer | Uint8Array): string {
  const view = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  let binary = '';
  for (const byte of view) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

export async function sha256Base64Url(body: Uint8Array<ArrayBuffer>): Promise<string> {
  return encodeBase64Url(await crypto.subtle.digest('SHA-256', body));
}

export function bootstrapPayload(input: {
  vault: string;
  device: string;
  signingPublicKey: string;
  exchangePublicKey: string;
  timestamp: string;
  nonce: string;
}): Uint8Array {
  return encoder.encode(
    [
      'nyla-bootstrap-v1',
      input.vault,
      input.device,
      input.signingPublicKey,
      input.exchangePublicKey,
      input.timestamp,
      input.nonce,
    ].join('\n'),
  );
}

export function httpAuthPayload(input: {
  method: string;
  path: string;
  timestamp: string;
  nonce: string;
  bodyHash: string;
}): Uint8Array {
  return encoder.encode(
    [
      'nyla-http-v1',
      input.method.toUpperCase(),
      input.path,
      input.timestamp,
      input.nonce,
      input.bodyHash,
    ].join('\n'),
  );
}

export function envelopePayload(input: {
  vault: string;
  device: string;
  epoch: number;
  op: string;
  nonce: string;
  ciphertext: string;
}): Uint8Array {
  return encoder.encode(
    [
      'nyla-envelope-v1',
      input.vault,
      input.device,
      String(input.epoch),
      input.op,
      input.nonce,
      input.ciphertext,
    ].join('\n'),
  );
}

export function recoveryEnrollmentPayload(input: {
  vault: string;
  recoveryId: string;
  device: string;
  signingPublicKey: string;
  exchangePublicKey: string;
  timestamp: string;
  nonce: string;
}): Uint8Array {
  return encoder.encode(
    [
      'nyla-recovery-enroll-v1',
      input.vault,
      input.recoveryId,
      input.device,
      input.signingPublicKey,
      input.exchangePublicKey,
      input.timestamp,
      input.nonce,
    ].join('\n'),
  );
}

export async function verifyEd25519(
  publicKeyBase64Url: string,
  signatureBase64Url: string,
  payload: Uint8Array<ArrayBuffer>,
): Promise<boolean> {
  try {
    const publicKey = decodeBase64Url(publicKeyBase64Url);
    const signature = decodeBase64Url(signatureBase64Url);
    if (publicKey.byteLength !== 32 || signature.byteLength !== 64) return false;
    const key = await crypto.subtle.importKey('raw', publicKey, { name: 'Ed25519' }, false, [
      'verify',
    ]);
    return await crypto.subtle.verify({ name: 'Ed25519' }, key, signature, payload);
  } catch {
    return false;
  }
}

export function clockIsFresh(timestamp: string, now = Date.now()): boolean {
  if (!/^\d{13}$/.test(timestamp)) return false;
  const parsed = Number(timestamp);
  return Number.isSafeInteger(parsed) && Math.abs(now - parsed) <= MAX_CLOCK_SKEW_MS;
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      'content-type': 'application/json; charset=utf-8',
      'cache-control': 'no-store',
      'x-content-type-options': 'nosniff',
    },
  });
}

export function error(code: string, status: number, detail?: string): Response {
  return json({ error: code, ...(detail === undefined ? {} : { detail }) }, status);
}

export async function readJson<T>(request: Request, maxBytes = 256 * 1024): Promise<{
  bytes: Uint8Array<ArrayBuffer>;
  value: T;
}> {
  const declared = Number(request.headers.get('content-length') ?? '0');
  if (Number.isFinite(declared) && declared > maxBytes) throw new PayloadTooLargeError();

  const buffer = await request.arrayBuffer();
  if (buffer.byteLength > maxBytes) throw new PayloadTooLargeError();
  const bytes = new Uint8Array(buffer);
  const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  return { bytes, value: JSON.parse(text) as T };
}

export class PayloadTooLargeError extends Error {}
