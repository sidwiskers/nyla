# Architecture

## Product boundary

Nyla is a menstrual-health application. Its scope is deliberately narrow enough to be coherent and deep enough to be useful for years.

Included:

- period dates and flow
- spotting
- cramps and pain
- mood and emotional state
- energy and fatigue
- sleep
- headache
- bloating
- acne / skin
- appetite and cravings
- breast tenderness
- discharge
- digestion / bowel changes
- exercise
- medication / pain-relief log as user-entered notes, without dosage advice
- custom symptoms and private notes
- cycle predictions with uncertainty
- personal pattern detection
- local notifications
- menstrual-health education
- encrypted multi-device sync
- user-controlled readable data export with sync/device credentials excluded
- app lock and notification privacy

Excluded by product policy:

- pregnancy mode
- conception / trying-to-conceive mode
- pregnancy probability
- fertile-window or contraceptive claims
- baby development
- sexual-activity diary
- libido / sexual coaching
- masturbation / pleasure content

The engine may model cycle phases where needed for menstrual explanations, but Nyla does not present fertility estimates as contraception or conception guidance.

## Technology

### Mobile

Flutter 3.44+ / Dart 3.12+.

Why Flutter:

- a single Android/iOS product surface without surrendering pixel-level control
- high-quality custom drawing and animation
- native AOT builds
- mature accessibility and localization support
- direct platform interop where Keychain/Keystore or notification behavior requires it

State is managed with Riverpod. Navigation uses `go_router`. Persistence uses Drift over SQLite 3.x configured with SQLCipher. Keys are kept in platform secure storage and can be gated by local authentication.

### Prediction package

`packages/cycle_engine` is pure Dart with no Flutter dependency. It contains date-safe menstrual calculations, robust statistics, prediction confidence and later personal-pattern analysis. Keeping this isolated makes it straightforward to fuzz and property-test.

### Sync

Cloudflare Worker + one SQLite-backed Durable Object per opaque vault identifier.

The Worker authenticates devices, assigns monotonic server cursors, deduplicates operations and relays ciphertext. It cannot decrypt health records.

### Content

Educational content is data, not hard-coded widgets. Each card carries:

- stable content ID
- title and short flashcard copy
- expanded explanation
- practical guidance
- warning / seek-care criteria where applicable
- category and tags
- source list
- medical review status
- content version and review date

This lets the UI remain stable while the corpus is reviewed independently.

## Local-first data flow

```text
User action
   |
   v
Domain command
   |
   +--> encrypted local SQLite transaction --> UI stream
   |
   +--> append sync operation --> encrypted outbox
                                |
                                v
                         Cloudflare relay
                                |
                       encrypted operation log
                                |
                                v
                         another device inbox
                                |
                                v
                    deterministic local merge
```

The UI never waits for Cloudflare to accept a menstrual log. Offline mode is the normal architecture, not a degraded mode.

## Date semantics

Menstrual events are day-based, not timestamp-based. Calendar dates are stored as an integer `epoch_day`, preventing timezone changes and daylight-saving transitions from moving a period to a neighboring date.

Audit/sync metadata uses UTC timestamps and hybrid logical clocks separately.

## Prediction philosophy

Nyla never presents a statistical estimate as a biological certainty.

A prediction contains:

- most likely start day
- expected range
- predicted cycle length
- confidence
- amount of history used
- variability measure
- optional explanation of why confidence is low

The engine uses robust statistics and recency weighting. Extreme historical values remain visible in history but do not automatically dominate the next prediction. No value is silently deleted.

Predictions are recalculated locally whenever relevant history changes.

## Failure philosophy

- Cloud unavailable: local tracking continues normally.
- Notification permission denied: tracking remains complete; UI explains the disabled reminder state.
- Keychain/Keystore unavailable: fail closed for encrypted data rather than create an unencrypted database.
- Sync conflict: deterministic field-level merge; never overwrite a whole database.
- Corrupt or unauthenticated remote operation: fail closed and do not advance the sync cursor.
- Lost recovery key and all authorized devices: encrypted cloud data is intentionally unrecoverable.
- Prediction has too little history: show uncertainty plainly rather than manufacture precision.
