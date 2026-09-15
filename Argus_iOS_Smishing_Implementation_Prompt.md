# IMPLEMENTATION PROMPT: Add iOS SMS Smishing Detection to Argus

You are working on an existing Flutter application called **Argus**, located in the `frontend/` directory of a monorepo.

Your task is to add **native iOS SMS filtering and smishing detection** while preserving the existing Android implementation and reusing the existing backend fraud-detection pipeline.

## 1. Understand the existing project before modifying anything

Treat `frontend/` as the **canonical Flutter application**. Do not implement this against the legacy root Flutter project unless there is a concrete build dependency that requires it.

The existing architecture is:

```text
Flutter app
    ↓
Local SMS detection
    ↓
Spring Boot backend
    ↓
FastAPI ML service
    ↓
BERT scam classifier
```

The existing Android implementation uses `SmsIngestionService`, the `telephony` package, and `permission_handler`. It listens for incoming SMS, performs immediate local analysis, submits the message to `POST /api/scans`, stores the result locally, and displays a notification when appropriate.

The canonical scan endpoint is:

```text
POST /api/scans
```

and the backend ultimately sends the message to the FastAPI `/predict` endpoint. Fraud results are persisted server-side.

Do **not** create a second fraud-detection backend, second ML service, or duplicate Flutter scan pipeline.

---

# 2. Goal

Add an iOS implementation capable of inspecting **incoming SMS/MMS from unknown senders** using Apple's **Message Filter Extension / IdentityLookup** framework.

The desired iOS flow is:

```text
Incoming unknown-sender SMS
        ↓
Apple Message Filter Extension
        ↓
Sender + message body
        ↓
Local quick analysis OR defer to Argus backend
        ↓
Existing Argus fraud analysis
        ↓
Classification returned to iOS
        ↓
iOS filters/categorizes the message appropriately
```

Apple's `ILMessageFilterQueryRequest` provides the message `sender` and `messageBody` to the extension.

Apple also supports deferring the decision to an associated server. In that model, **the operating system handles the network communication**, passes the request to the server, and returns the server response to the extension. The extension itself must not attempt a normal `URLSession` request for this operation.

---

# 3. Do NOT break Android

The existing Android SMS ingestion must continue working exactly as it currently does.

Do not:

- remove `telephony`
- remove Android SMS permissions
- change Android background listeners
- alter the Android ingestion behavior unnecessarily
- replace the Android pipeline with the iOS implementation
- make the Flutter app dependent on iOS-specific code

The resulting architecture should be:

```text
                 ARGUS

       ┌───────────┴───────────┐
       │                       │
    Android                    iOS
       │                       │
SMS listener          Message Filter Extension
       │                       │
       └───────────┬───────────┘
                   ↓
             Existing backend
                   ↓
             Fraud detection
                   ↓
                Result
```

---

# 4. Add a native iOS Message Filter Extension

Inside:

```text
frontend/ios/
```

add a real **Message Filter Extension target** using Apple's IdentityLookup framework.

Use:

```swift
ILMessageFilterExtension
ILMessageFilterQueryHandling
ILMessageFilterQueryRequest
ILMessageFilterQueryResponse
ILMessageFilterExtensionContext
```

Apple's official Message Filter Extension template is the intended mechanism for this.

The extension must implement the required query handler.

At minimum, obtain:

```swift
queryRequest.sender
queryRequest.messageBody
```

and handle missing values safely.

---

# 5. Use the existing backend for the authoritative analysis

Do not rebuild the BERT model in Swift.

Do not port the Python model to Swift.

Do not create a second ML model just for iOS.

The existing backend is already responsible for ML classification:

```text
POST /api/scans
        ↓
Spring Boot
        ↓
FastAPI /predict
        ↓
BERT
```

Use the existing fraud-detection infrastructure wherever Apple's Message Filter architecture permits it. The existing `/api/scans` contract should remain the canonical application-level scan pipeline.

However, because Apple's Message Filter networking is system-mediated, inspect the actual request/response contract that the Message Filter server endpoint receives and implement a **small adapter endpoint if necessary** rather than pretending the extension can directly call `/api/scans` like Flutter does.

Prefer:

```text
Apple Message Filter request
        ↓
iOS filter-specific backend adapter
        ↓
Existing scan/fraud service
        ↓
Existing ML service
        ↓
Filter-compatible response
```

Do not duplicate the actual fraud logic.

If an adapter endpoint is required, make it a thin translation layer.

---

# 6. Message Filter networking must follow Apple's rules

The Message Filter Extension cannot directly make arbitrary network requests.

Use the Apple-supported system-mediated flow, including:

```swift
context.deferQueryRequestToNetwork(...)
```

when the decision needs the server.

Do **not** implement:

```swift
URLSession.shared.data(for: ...)
```

inside the Message Filter Extension as the primary network path.

The project must follow Apple's documented `ILMessageFilterExtensionNetworkURL` mechanism.

---

# 7. Configure the iOS project correctly

Modify the iOS project so the extension has the correct:

- target
- bundle identifier
- `Info.plist`
- extension point
- IdentityLookup configuration
- Associated Domains configuration where required for the server-backed filtering flow
- `ILMessageFilterExtensionNetworkURL`

The extension's Info.plist must contain the appropriate extension declaration using Apple's documented keys, including the message-filter extension point.

The network service must use **HTTPS**.

Do not hard-code:

```text
http://localhost:8080
```

inside the production iOS filter extension.

The existing Flutter project currently uses localhost/Android-emulator-specific URLs in some environments, so make sure the iOS filter endpoint is configurable for development and production.

---

# 8. Do not assume Flutter can run inside the extension

The Message Filter Extension is a native iOS extension.

Do **not** attempt to embed the Flutter runtime inside it.

The architecture should be:

```text
Flutter app
    └── normal Argus UI/auth/settings/history

Native Swift
    └── Message Filter Extension
```

Flutter remains responsible for:

- login UI
- dashboard
- scan history
- settings
- safety tips
- normal app behavior
- existing Android behavior

Swift/IdentityLookup is responsible for:

- receiving eligible incoming SMS filter queries
- extracting sender/message
- performing local filter checks
- deferring to the server when required
- translating the server response into an iOS filter decision

---

# 9. Preserve the existing local-first philosophy where practical

The current Argus app performs immediate local analysis before backend analysis.

Implement the iOS extension with the same philosophy where appropriate.

For example:

```text
Incoming message
        ↓
Cheap local checks
        ↓
Clearly malicious?
      /       \
    yes        no
    ↓           ↓
FILTER     defer to server
               ↓
          authoritative result
```

The local Swift checks should **not** attempt to reproduce the full BERT model.

They should be lightweight and deterministic, for example:

- obvious malicious URL patterns
- known suspicious terms
- urgent credential requests
- extremely obvious scam patterns

Do not exaggerate the accuracy of these heuristics.

The backend remains authoritative for the full fraud classification.

---

# 10. Map the backend result to iOS filtering decisions

The backend currently produces scam/trust information such as:

```json
{
  "label": "scam",
  "is_scam": true,
  "confidence": 0.9564
}
```

or equivalent normalized results.

Create a small iOS-side translation layer.

For example:

```text
is_scam = true
high confidence
        ↓
ILMessageFilterAction.filter
```

Safe/non-scam:

```text
is_scam = false
        ↓
ILMessageFilterAction.allow
```

Do not invent additional classifications unless the existing backend actually provides them.

Inspect the SDK available in the current development environment before choosing whether Argus should use only `allow/filter` or richer categories/subcategories supported by the current iOS SDK.

---

# 11. Important privacy boundary

Do not implement background collection of all iPhone messages.

Do not attempt to access:

- the Messages database
- old/historical messages
- iMessage contents
- arbitrary conversations
- contacts' message history

The feature being implemented is **incoming message filtering for messages presented to the Message Filter Extension by iOS**.

The product should be described accurately.

Do not claim:

> "Argus can read all your iPhone messages."

The accurate product claim is closer to:

> "Argus can analyze eligible incoming SMS/MMS messages from unknown senders for potential scams."

---

# 12. Do not introduce unnecessary permissions

Do not request broad iOS permissions just because they sound related.

Do not add:

- Contacts access
- Photos access
- microphone
- location
- Bluetooth
- notification listener access
- Messages database access
- unrelated background modes

unless an actual implementation requirement is discovered and documented.

The Message Filter Extension mechanism is the intended entry point.

---

# 13. Existing Flutter notification behavior

The current Android implementation uses the Flutter notification service to show high-importance fraud alerts.

Do **not** assume the iOS Message Filter Extension can simply reproduce this exact Android notification flow.

For iOS, the primary immediate user-facing result should be the **Messages filtering/classification behavior returned to iOS**.

Do not build a fake background notification system merely to imitate Android.

If a separate iOS app notification is desired later, keep that as a separate feature.

---

# 14. Authentication

The existing Flutter app uses JWT authentication and stores the authenticated session in `SharedPreferences`.

Do not assume the Message Filter Extension can simply read the Flutter app's `SharedPreferences`.

It cannot.

The extension and containing app are separate execution contexts.

If server-side filtering requires authenticated requests, investigate Apple's documented message-filter server authorization / associated-domain mechanism and implement authentication in the Apple-supported way.

Do not copy a JWT into the extension's source code.

Do not hard-code user credentials.

Do not invent an insecure shared-secret scheme.

If the current backend's JWT authentication makes the Apple-managed filter request incompatible with the existing endpoint, create a **minimal purpose-built server endpoint** for message filtering and document its security model.

Apple's server-backed Message Filter flow requires the appropriate associated-domain configuration.

---

# 15. Do not accidentally change existing application architecture

Avoid unrelated cleanup.

Do NOT:

- refactor the entire Flutter app
- rewrite authentication
- rewrite the dashboard
- replace the existing ML model
- migrate the database
- redesign the UI
- replace the Android SMS implementation
- fix unrelated admin-dashboard issues
- merge the legacy root Flutter package into `frontend/`
- change the backend's scan semantics unless required by the iOS integration

The repository already has known unrelated gaps. Keep this task focused on iOS SMS filtering.

---

# 16. Development/testing mode

Implement a development-friendly configuration so that the iOS filter backend endpoint can be pointed at the appropriate development server.

Do not rely on:

```text
localhost
```

for a physical iPhone unless the address genuinely resolves from the device/network.

Clearly separate:

```text
development backend
staging backend
production backend
```

where appropriate.

Do not commit secrets.

---

# 17. Required testing

Create a test plan covering:

### Safe SMS

Example:

```text
"Hey, are we still meeting at 5?"
```

Expected:

```text
ALLOW
```

### Obvious smishing

Example:

```text
"Your account has been suspended. Verify immediately at https://..."
```

Expected:

```text
FILTER / scam classification
```

### Legitimate transactional SMS

Example:

```text
"Your order #12345 has been shipped."
```

Expected:

```text
ALLOW or appropriate transactional classification
```

### Unknown sender

Verify that the Message Filter Extension actually receives:

```text
sender
messageBody
```

### Backend failure

Simulate the backend being unavailable and verify that the extension fails safely according to Apple's supported filtering behavior.

### Android regression

Verify that Android SMS interception continues to work exactly as before.

### Existing Flutter functionality

Verify:

- manual scan
- login
- dashboard
- scan history
- local storage
- existing notifications
- backend synchronization

still work.

---

# 18. Acceptance criteria

The task is complete only when all of the following are true:

1. `frontend/` remains the canonical Flutter application.
2. Android SMS detection still functions.
3. An iOS Message Filter Extension target exists.
4. The extension uses Apple's IdentityLookup APIs.
5. The extension receives sender and message body for eligible incoming messages.
6. The extension can make a local filtering decision.
7. The extension can defer the decision to the configured backend through Apple's system-managed networking mechanism.
8. The backend result is translated into an appropriate iOS filtering response.
9. No second fraud-detection model is introduced.
10. No hard-coded credentials or secrets are introduced.
11. No unnecessary iOS permissions are requested.
12. The implementation does not claim to read the user's entire Messages history.
13. Android behavior remains intact.
14. The implementation is documented sufficiently for another developer to configure the iOS extension in Xcode and on a physical iPhone.
15. Any Apple capability, entitlement, associated-domain, AASA, or signing requirement that cannot be completed automatically by the coding environment is explicitly identified rather than silently skipped.

---

# 19. Before writing code

First inspect the actual files under:

```text
frontend/ios/
frontend/lib/services/sms_ingestion_service.dart
frontend/lib/services/sms_detection_service.dart
frontend/lib/services/notification_service.dart
frontend/lib/services/auth_service.dart
backend/src/main/java/com/example/smsfraud/scan/
backend/src/main/java/com/example/smsfraud/ml/
backend/src/main/resources/
```

Determine the exact current implementations and contracts.

Then produce a concise implementation plan identifying:

```text
1. Files to create
2. Files to modify
3. Backend changes, if any
4. Xcode/project configuration changes
5. Apple capabilities/entitlements required
6. Testing procedure
```

**Do not begin with a speculative rewrite. Inspect first, then implement.**

The final implementation should feel like a natural iOS adapter for the existing Argus security platform, not a separate application bolted onto it.
