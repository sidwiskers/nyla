import { error } from './protocol';
export { Vault } from './vault';

interface Env {
  VAULTS: DurableObjectNamespace;
}

const vaultRoute = /^\/v1\/vaults\/([A-Za-z0-9_-]{16,64})(\/.*)?$/;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const incoming = new URL(request.url);
    if (request.method === 'GET' && incoming.pathname === '/health') {
      return new Response('ok', {
        headers: {
          'content-type': 'text/plain; charset=utf-8',
          'cache-control': 'no-store',
        },
      });
    }

    const match = incoming.pathname.match(vaultRoute);
    if (!match) return error('not_found', 404);
    const vaultId = match[1]!;
    const subpath = match[2] || '/';

    const id = env.VAULTS.idFromName(vaultId);
    const stub = env.VAULTS.get(id);
    const forwardedUrl = new URL(request.url);
    forwardedUrl.pathname = subpath;

    const headers = new Headers(request.headers);
    headers.set('x-nyla-vault', vaultId);
    headers.set('x-nyla-canonical-path', incoming.pathname + incoming.search);
    headers.delete('cf-connecting-ip');
    headers.delete('x-forwarded-for');

    return stub.fetch(
      new Request(forwardedUrl, {
        method: request.method,
        headers,
        body: request.method === 'GET' || request.method === 'HEAD' ? undefined : request.body,
      }),
    );
  },
} satisfies ExportedHandler<Env>;
