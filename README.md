# Nyla

Nyla is a private, local-first menstrual health companion built around four principles:

- **Intelligent, explainable tracking** — predictions learn from a person's history without pretending biology is exact.
- **Pleasant, effortless UX** — calm, soft and distinctive rather than clinical or generically "Material".
- **Curated menstrual-health education** — medically sourced flashcards and long-form explanations are part of the product, never a paywall.
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

The primary navigation is intentionally small:

1. **Today** — current cycle state, predicted range, one useful insight, quick logging.
2. **Calendar** — recorded and predicted periods, history, uncertainty ranges.
3. **Log** — fast flow/symptom/body logging with user-customizable favorites.
4. **Insights** — personal patterns, trends and explainable observations.
5. **Learn** — curated flashcards and detailed menstrual-health guidance.

Settings, notification controls, privacy, sync, device management and export live outside the primary navigation.

## Security model

Nyla targets OWASP MASVS storage, cryptography, authentication, network and privacy controls. The health database is encrypted at rest with a device-protected key. Sync records are independently end-to-end encrypted and authenticated before leaving the device. The sync service stores ciphertext and minimal routing metadata only.

See `docs/ARCHITECTURE.md`, `docs/SECURITY.md` and `docs/SYNC_PROTOCOL.md`.

## Signed Android releases

`.github/workflows/release-apk.yml` is **manual only**. Normal pushes and tags do not build or publish a release APK.

The workflow validates the release configuration, validates the Cloudflare relay, runs the Flutter/package/content gates, builds and verifies the signed APK, then deploys the relay and optionally publishes the APK plus SHA-256 checksum as a GitHub Release.

Add these values under **Repository Settings → Secrets and variables → Actions → Repository secrets**:

```text
CLOUDFLARE_API_TOKEN
CLOUDFLARE_ACCOUNT_ID
NYLA_SYNC_BASE_URL
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

### Credential examples

The examples below are deliberately fake.

```text
CLOUDFLARE_API_TOKEN
example: wP9_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
where: Cloudflare → My Profile → API Tokens
note: use a token allowed to deploy/edit Workers; never use the Global API Key.

CLOUDFLARE_ACCOUNT_ID
example: 023e105f4ecef8ad9ca31a8372d0c353
where: Cloudflare dashboard → Workers & Pages / account overview
note: this is an ID, not a password.

NYLA_SYNC_BASE_URL
example: https://nyla-sync.example-subdomain.workers.dev
where: the public URL shown for the nyla-sync Worker
note: HTTPS origin only; no /health, query string or trailing path.

ANDROID_KEYSTORE_BASE64
example: MIIK...very-long-single-line-base64...AB
where: base64 form of the permanent Android release .jks keystore
note: base64 is not encryption. Keep the original keystore permanently and privately.

ANDROID_KEYSTORE_PASSWORD
example: a-long-random-password
note: password protecting the keystore file.

ANDROID_KEY_ALIAS
example: nyla
note: the key name inside the keystore. Keep this the same forever.

ANDROID_KEY_PASSWORD
example: another-long-random-password
note: password for the signing key itself. It may equal the keystore password, but separate strong values are cleaner.
```

### Important signing rule

The Android release keystore is permanent. Once a Nyla APK signed by it is distributed, future updates must use the same signing key. Do not regenerate it casually and do not use an online keystore/base64 generator.

Because this project is managed without a PC, the keystore only needs to be created once; afterward GitHub Actions reconstructs it from `ANDROID_KEYSTORE_BASE64` inside the temporary runner and signs releases automatically. Signing passwords are passed directly to Gradle through environment variables and are never committed or written to `key.properties`.

### Releasing

Open **Actions → Release APK → Run workflow**, choose the branch, enter a version such as `1.0.0`, keep **Publish GitHub Release** enabled if desired, then press **Run workflow**.

That is the only way the production APK workflow starts.
