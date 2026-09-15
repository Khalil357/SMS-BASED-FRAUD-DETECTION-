# iOS Message Filter setup (Argus)

Argus can analyze **eligible incoming SMS/MMS from unknown senders** via Apple’s Message Filter Extension. It does **not** read the user’s full Messages history, iMessage database, or arbitrary conversations.

## Architecture

```text
Unknown-sender SMS
      ↓
MessageFilterExtension (native Swift / IdentityLookup)
      ↓ local heuristics (optional early FILTER)
      ↓ else deferQueryRequestToNetwork (Apple OS HTTPS POST)
      ↓
POST https://<host>/api/message-filter
      ↓
MessageFilterService → existing MlFraudDetectionClient → FastAPI /predict
      ↓
{ "action": "filter"|"allow", "is_scam": ..., "label": ..., "confidence": ... }
      ↓
ILMessageFilterAction (filter/junk or allow)
```

Android SMS ingestion (`telephony` / `SmsIngestionService`) is unchanged.

## What this coding environment cannot finish for you

These require an Apple Developer account, physical device, and Xcode UI:

1. **Signing** — select your Team on `Runner` and `MessageFilterExtension`.
2. **Associated Domains capability** — intentionally not enabled on the Runner target while using a Personal Team. Revisit it only for the production Message Filter server-backed flow with an Apple Developer account and real HTTPS host.
3. **HTTPS host with a real domain** — Message Filter forbids `http://` and cannot use ATS exceptions. `localhost` will not work on a physical iPhone unless you tunnel (e.g. ngrok) to HTTPS.
4. **AASA file** — served by the backend at `/.well-known/apple-app-site-association` once `APPLE_TEAM_ID` is set; the file must be reachable over HTTPS **without redirects**. This is not part of the Personal Team smoke test.
5. **Enable on device** — Settings → Messages → Unknown & Spam → SMS Filtering → enable **Argus SMS Filter**.
6. **App Store / provisioning** — Message Filter extensions need proper App ID + provisioning profiles that include the extension.

## Configure network URL

Edit:

- `frontend/ios/MessageFilterExtension/NetworkURL.Debug.xcconfig`
- `frontend/ios/MessageFilterExtension/NetworkURL.Release.xcconfig`
- `frontend/ios/Runner/Runner.entitlements`

Replace `YOUR_DEV_HTTPS_HOST` / `YOUR_PROD_HTTPS_HOST` with the same host used in `ILMessageFilterExtensionNetworkURL` (path `/api/message-filter`).

For the Flutter Runner app’s authentication and manual-scan API calls, provide the
backend URL at build/run time instead of using `localhost` on a physical iPhone:

```bash
flutter run --dart-define=ARGUS_API_BASE_URL=https://api.example.com
```

The URL must be reachable from the iPhone. Use HTTPS for production. For local
development, use a reachable LAN HTTPS endpoint or tunnel; do not replace
`localhost` with an unverified hard-coded IP in source control.

Example Debug (ngrok):

```xcconfig
MESSAGE_FILTER_NETWORK_URL = https:/$()/abc123.ngrok-free.app/api/message-filter
```

Entitlement:

```xml
<string>messagefilter:abc123.ngrok-free.app</string>
```

## Backend

- `POST /api/message-filter` — Apple JSON in, filter decision out (permitAll; no JWT).
- Reuses `MlFraudDetectionClient` only (no second model).
- Does not write per-user scan rows (no authenticated user on Apple’s request).
- Manual scans / Android auto-ingestion still use authenticated `POST /api/scans`.

### Security model (document for reviewers)

Apple’s OS posts to the associated domain URL; the extension cannot attach Flutter’s JWT from SharedPreferences. The adapter is therefore unauthenticated but:

- only returns a classification JSON body;
- does not mutate user accounts or fraud history;
- should be HTTPS-only behind the associated domain;
- fails open (`allow`) if ML is down.

Optional hardening later: edge rate limits, WAF, IP allowlists — not required for the extension contract.

## Xcode checklist

1. Open `frontend/ios/Runner.xcworkspace`.
2. Confirm target **MessageFilterExtension** exists and is embedded in Runner (Embed Foundation Extensions).
3. Set Team + unique bundle IDs if `com.example.secureSignal` is not available on your account.
4. For a production Message Filter build, enable/configure the required associated-domain capability and update the network URL xcconfigs with the same real HTTPS host.
5. Build & run on a **physical iPhone**.
6. Enable SMS Filtering for Argus in Settings.
7. Send a test SMS from an unknown number.

## Test plan

| Case | Example | Expected |
|------|---------|----------|
| Safe | `Hey, are we still meeting at 5?` | ALLOW |
| Obvious smishing | `Your account has been suspended. Verify immediately at https://...` | FILTER (local or server) |
| Transactional | `Your order #12345 has been shipped.` | ALLOW |
| Backend down | Stop Spring/ML | ALLOW (fail open) |
| Android regression | Incoming SMS on Android | Unchanged auto-ingestion |
| Flutter | Login, manual scan, dashboard, history | Unchanged |

## Privacy wording

Use: *“Argus can analyze eligible incoming SMS/MMS messages from unknown senders for potential scams.”*

Do **not** claim Argus can read all iPhone messages.
