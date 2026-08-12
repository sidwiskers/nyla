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
