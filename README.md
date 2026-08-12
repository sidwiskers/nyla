# Nyla

Nyla is a private, local-first menstrual health companion built around four principles:

- **Intelligent, explainable tracking** — predictions learn from a person's history without pretending biology is exact.
- **Pleasant, effortless UX** — calm, soft and distinctive rather than clinical or generically Material.
- **Curated menstrual-health education** — medically sourced guidance is part of the product, never a paywall.
- **Privacy by architecture** — readable health data stays on the device. Multi-device sync relays end-to-end encrypted changes only.

Pregnancy, trying-to-conceive, sexual activity, masturbation and sexual coaching are intentionally outside the product.

## Repository

```text
apps/mobile/          Flutter application
packages/cycle_engine Pure Dart prediction and insight engine
services/sync/        Cloudflare Worker + SQLite Durable Object encrypted relay
content/tips/         Versioned, source-backed educational corpus
docs/                 Architecture, security and protocol specifications
```

The local encrypted database is the source of truth. Cloudflare is a transport and coordination layer, not a health-data database.

## Product surfaces

1. **Today** — current cycle state, predicted range, one useful insight, quick logging.
2. **Calendar** — recorded and predicted periods, history, uncertainty ranges.
3. **Log** — fast flow, symptom and body logging with custom logs.
4. **Insights** — personal patterns, trends and explainable observations.
5. **Learn** — curated menstrual-health guidance.

Settings, reminders, privacy, sync, device management and export live outside the primary navigation.

## Security model

Nyla targets OWASP MASVS storage, cryptography, authentication, network and privacy controls. The health database is encrypted at rest with a device-protected key. Sync records are independently end-to-end encrypted and authenticated before leaving the device. The sync service stores ciphertext and minimal routing metadata only.

See `docs/ARCHITECTURE.md`, `docs/SECURITY.md` and `docs/SYNC_PROTOCOL.md`.

## No-PC Android release setup

Everything below can be done from GitHub and Cloudflare in a phone browser. The APK workflow is **manual only**; normal pushes and tags never build or publish a release APK.

### Do this once, in this order

**1. Add these five Repository Secrets first**

Go to **GitHub repository → Settings → Secrets and variables → Actions → New repository secret**.

```text
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ACCOUNT_ID
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

Examples and short notes:

```text
CLOUDFLARE_API_TOKEN
example: wP9_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
get it: Cloudflare → Account API tokens → Create Token
use: a scoped token allowed to edit/deploy Workers; do not use the Global API Key

CLOUDFLARE_ACCOUNT_ID
example: 023e105f4ecef8ad9ca31a8372d0c353
get it: Cloudflare → Workers & Pages → account details

ANDROID_KEYSTORE_PASSWORD
example: NylaStore-A7x9-very-long-random-value
use: a strong password you keep permanently

ANDROID_KEY_ALIAS
example: nyla
use: simply `nyla`; do not change it later

ANDROID_KEY_PASSWORD
example: NylaKey-P4m8-another-long-random-value
use: another strong password you keep permanently
```

**2. Generate the permanent Android signing key**

Go to **Actions → Generate Android Keystore → Run workflow**. This workflow is manual only.

When it finishes, download the `nyla-android-signing-bootstrap` artifact. It contains:

```text
nyla-release.jks                 ← permanent backup; keep this safe
nyla-release.jks.base64.txt      ← open this on your phone
nyla-release.jks.sha256          ← checksum for the backup
```

**3. Add the sixth and final Repository Secret**

Open `nyla-release.jks.base64.txt`, copy the entire single line, then create:

```text
ANDROID_KEYSTORE_BASE64
```

Paste that line as its value. You do **not** invent or obtain this value elsewhere; the keystore workflow creates it for you.

Keep `nyla-release.jks` somewhere private as an emergency backup, then delete the keystore-generation workflow run. Its artifact also expires automatically after one day.

> The signing key is permanent. After a Nyla APK signed with it is distributed, future updates must use the same key, alias and passwords.

### That is all the configuration

The final six Repository Secrets are:

```text
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ACCOUNT_ID
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

There is **no `NYLA_SYNC_BASE_URL` secret**. The release workflow reads the `nyla-sync` Worker name, gets or creates the account's `workers.dev` subdomain through Cloudflare, derives the public endpoint automatically, embeds that endpoint in the APK and verifies `/health` after deployment.

## Build a release APK

Go to **Actions → Release APK → Run workflow**.

1. Choose `main`.
2. Enter a version such as `1.0.0`.
3. Leave **Publish GitHub Release** enabled if you want a GitHub Release entry.
4. Press **Run workflow**.

The workflow validates the app and relay, generates the Nyla launcher icons, builds and verifies the signed APK, deploys the sync relay, checks the exact endpoint embedded in the APK, writes a SHA-256 checksum and then publishes the release when requested.

That manual button is the only way the production APK workflow starts.
