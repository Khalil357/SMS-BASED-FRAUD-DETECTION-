# Argus SMS Fraud Detection System

## 1. Executive summary

This repository contains a multi-client SMS fraud detection platform called
**Argus** (also branded in older files as **Secure Signal**). Its purpose is to
identify scam, phishing, impersonation, mobile-money, fake prize, and
credential-harvesting SMS messages; warn the user; retain a scan history; and
give administrators a wider operational view of detected fraud.

The project is a monorepo with four important runtime parts:

1. **Flutter mobile application** in `frontend/`: the primary end-user
   experience. It can listen for incoming Android SMS messages, analyze them
   locally, call the backend/ML service, persist a local history, and show
   notifications.
2. **React/TypeScript web client** in `web-client/`: an administrator-oriented
   dashboard and authentication/OTP interface. Much of its dashboard currently
   uses in-memory demonstration data rather than live API calls.
3. **Spring Boot backend** in `backend/`: authentication, JWT security, user
   management, scan orchestration, persistence, admin APIs, email/OTP support,
   and the REST boundary used by the Flutter application.
4. **Python FastAPI ML service** in `main.py`: loads the fine-tuned BERT model
   stored in `final_model/` and classifies SMS text as `scam` or `trust`.

The intended production flow is:

```text
Incoming SMS or manual text
        |
        v
Flutter client performs immediate local analysis
        |
        +--> local log + optional notification
        |
        +--> Spring Boot /api/scans
                    |
                    v
              FastAPI /predict
                    |
                    v
             BERT scam classifier
                    |
                    v
       Spring persists fraudulent scans in PostgreSQL
```

The repository is functional in several areas but is still in active
development. In particular, the Flutter app, web client, and backend currently
contain different authentication contracts and different levels of API
integration. Those differences are documented below because they are important
for anyone taking over the project.

## 2. Repository structure

The repository also contains generated build output (`build/`,
`frontend/build/`, `.dart_tool/`, Gradle artifacts, APKs, native generated
files, and IDE metadata). Those files are products of the toolchains and are
not part of the application architecture. The meaningful source structure is:

```text
.
├── README.md                         General project overview
├── PROJECT_REPORT.md                 This architecture and frontend report
├── pubspec.yaml                      Root/legacy Flutter package definition
├── lib/                              Root Flutter source tree
├── test/                             Root Flutter widget test
│
├── frontend/                         Main Flutter client
│   ├── lib/
│   │   ├── main.dart                 App bootstrap, theme, permissions
│   │   ├── auth_flow.dart            In-memory auth-page coordinator
│   │   ├── app_theme.dart            Light/dark design system
│   │   ├── screens/
│   │   │   ├── splash_screen.dart
│   │   │   ├── onboarding_screen.dart
│   │   │   ├── login_page.dart
│   │   │   ├── create_account_page.dart
│   │   │   ├── forgot_password_page.dart
│   │   │   ├── verification_page.dart
│   │   │   ├── reset_password_page.dart
│   │   │   ├── dashboard_page.dart
│   │   │   ├── safety_tips_page.dart
│   │   │   └── terms_and_conditions_page.dart
│   │   ├── services/
│   │   │   ├── auth_service.dart
│   │   │   ├── sms_detection_service.dart
│   │   │   ├── sms_ingestion_service.dart
│   │   │   ├── sms_storage_service.dart
│   │   │   ├── notification_service.dart
│   │   │   └── safety_tips_service.dart
│   │   └── widgets/
│   │       ├── custom_button.dart
│   │       ├── custom_text_field.dart
│   │       ├── otp_input_field.dart
│   │       ├── interactive_threat_chart.dart
│   │       ├── security_illustrations.dart
│   │       ├── auth_widgets.dart
│   │       └── fade_slide_transition.dart
│   ├── assets/images/                 Logos and app illustrations
│   ├── android/, ios/, macos/,
│   │   linux/, windows/, web/         Flutter platform runners
│   ├── pubspec.yaml                   Flutter dependencies and assets
│   ├── AUTH_SERVICE_GUIDE.md          Earlier auth integration notes
│   └── README.md                      Default Flutter starter README
│
├── web-client/                        React administrator web client
│   ├── src/
│   │   ├── App.tsx                   Client-side page coordinator
│   │   ├── main.tsx                  React entry point
│   │   ├── pages/
│   │   │   ├── LoginPage.tsx
│   │   │   ├── VerificationPage.tsx
│   │   │   ├── ForgotPasswordPage.tsx
│   │   │   ├── ResetPasswordPage.tsx
│   │   │   └── DashboardPage.tsx
│   │   ├── components/auth/           Reusable auth layout and controls
│   │   ├── services/authService.ts    Fetch-based auth API wrapper
│   │   ├── types/                     Auth and dashboard models
│   │   ├── theme/                     Dark/light theme context and CSS
│   │   └── *.css                      Page and component styling
│   ├── public/                        Static icons
│   ├── package.json                   Vite, React, TypeScript, Oxlint
│   └── README.md                      Vite starter documentation
│
├── backend/                           Spring Boot REST API
│   ├── src/main/java/com/example/smsfraud/
│   │   ├── auth/                      Registration, login, OTP, reset
│   │   ├── user/                      User entity, roles, repositories
│   │   ├── scan/                      Scan API, entity, service, repository
│   │   ├── admin/                     Admin statistics and management APIs
│   │   ├── ml/                        Client for FastAPI /predict
│   │   ├── otp/                       In-memory OTP storage/service
│   │   ├── email/                     SMTP/Resend email delivery
│   │   ├── sender/                    Blocked sender persistence
│   │   ├── feedback/                  Fraud record compatibility endpoints
│   │   ├── common/                    API envelope, security, exceptions
│   │   └── config/                    Flyway, dotenv, seed, REST client
│   ├── src/main/resources/
│   │   ├── application.yml
│   │   ├── application.properties
│   │   ├── db/migration/              Flyway schema migrations
│   │   └── templates/email/            OTP/password reset templates
│   ├── pom.xml                        Java 21/Maven dependencies
│   ├── Dockerfile
│   └── LOCAL_SETUP.md
│
├── main.py                            FastAPI ML inference service
├── final_model/                       Saved tokenizer, config, and weights
├── requirements.txt                   Python ML service dependencies
├── docker-compose.yml                  PostgreSQL + ML + backend stack
├── docker/                            Additional Docker composition files
├── .github/workflows/                 CI, CodeQL, deployment workflows
└── android/, ios/, macos/, ...         Root/older Flutter platform files
```

### Important duplication

There are two Flutter-looking source trees: the root `lib/` tree and the
`frontend/lib/` tree. The root package has the older/default package name
`sms_based_fraud_detection`; the `frontend` package is named `secure_signal`
and contains the more complete Argus implementation, including the current
`AuthFlow`, dashboard, Android SMS ingestion, and ML integration. The root
tree should be treated as legacy or parallel work unless the build process
explicitly targets it.

## 3. Flutter frontend: intended user experience

### 3.1 Application bootstrap

`frontend/lib/main.dart` initializes the app before rendering:

- initializes Flutter bindings;
- creates sample SMS logs in local storage when no logs exist;
- initializes local notifications;
- checks Android SMS permission;
- starts SMS listening when permission is already granted;
- launches `SecureSignalApp`.

`SecureSignalApp` supplies the light/dark `MaterialApp` themes from
`app_theme.dart`. The title shown to the platform is `Argus`. Theme switching
is controlled by `SecureSignalAppState.toggleTheme()` and is exposed from the
dashboard.

The app starts at `SplashScreen`. The splash/onboarding screens lead into
`AuthFlow`, which is a stateful page coordinator rather than a router package.
`AuthFlow` stores the current page in an enum and keeps the phone number and OTP
in memory while a reset or account-verification flow is active.

### 3.2 Authentication flow

The mobile frontend supports:

- account creation;
- login by phone number or email;
- account verification using a six-digit code;
- forgotten-password code request;
- code resend;
- password reset;
- persistent login session;
- logout.

`auth_service.dart` is the central HTTP and session layer. It:

- chooses `http://10.0.2.2:8080` for Android emulators;
- uses `http://localhost:8080` on desktop/iOS-like environments;
- supports `customBaseUrl` for a physical phone or deployed backend;
- stores the JWT and user map in `SharedPreferences`;
- adds an Authorization header when a token is available;
- normalizes API responses into `{success, message, data, ...}` maps;
- exposes scan, fraud-list, fraud-delete, and fraud-add methods in addition to
  authentication.

The login page validates a phone/email identifier and a six-character minimum
password, calls `AuthService.login`, and navigates to the dashboard on success.
The sign-up page collects full name, email, phone, gender, password, password
confirmation, and terms acceptance. The forgot-password page requests a reset
code and passes the phone number into `AuthFlow`. `VerificationPage` renders
six OTP inputs using `OtpInputField`; `ResetPasswordPage` validates the new
password and submits the original phone/code combination.

`frontend/AUTH_SERVICE_GUIDE.md` describes an earlier endpoint naming scheme
(`signup`, `forgot-password`, `verify-code`, and so on). The current Dart
service and Spring controller use the newer resource-based paths:

```text
POST /api/auth/register
POST /api/auth/login
POST /api/auth/password-resets
POST /api/auth/password-resets/resend
POST /api/auth/password-resets/verify
POST /api/auth/password-resets/confirm
POST /api/auth/verify-login-otp
POST /api/auth/resend-login-otp
```

The backend login endpoint returns an OTP-pending response, while the Flutter
login implementation currently treats a successful HTTP login as sufficient to
save a session and open the dashboard. This is an integration point that should
be reconciled: either the mobile client must complete login OTP verification
before creating a session, or the backend must issue a usable access token at
the expected step.

### 3.3 Dashboard structure

`dashboard_page.dart` is the main mobile product surface. It is a large
stateful screen that provides:

- **Dashboard/Home**: greeting, safety metrics, recent activity, manual scan
  input, threat summaries, and the daily safety tip.
- **Scan Logs**: locally cached and backend-synchronized messages with search,
  Safe/Fraud filtering, Today/7 Days filtering, threat index display, and
  detail dialogs.
- **Blocklist**: add/remove sender numbers. The current list is held in widget
  state and seeded with sample numbers, so it is not yet connected to the
  backend blocked-sender API.
- **Safety Tips**: educational catalog and quiz supplied by
  `SafetyTipsPage`.
- **Profile & Settings**: user details, theme, ingestion permission, alert
  settings, and logout.

The bottom navigation uses a compact animated navigation bar. The app bar
changes its title based on the selected tab and provides theme and profile
controls.

The home metrics are derived from `_smsLogs`:

- scanned count = number of local log entries;
- threat count = entries classified as `Fraud`;
- safety index = percentage of entries classified as `Safe`.

`InteractiveThreatChart` provides visual threat analysis from the local logs.
It is therefore an app-level analytics view, not the same as the backend admin
trend API.

### 3.4 Manual SMS scanning

When the user enters text into the manual scan field,
`_handleManualScan()`:

1. submits the text to `POST /api/scans` with source `MANUAL_QUERY`;
2. if a backend result is returned, converts it with
   `SmsDetectionService.parseBackendResult`;
3. otherwise falls back to the local rule engine;
4. creates a local log entry;
5. displays a Safe/Fraud result, confidence, threat index, and explanation.

The UI labels the result as either **AI Trained Model** or **Local Rule Engine**
so the user can see whether the backend was used.

One important backend behavior is that the Spring scan service only persists a
record when the ML service says the message is fraudulent. A safe scan can
still appear in the Flutter local history, but it is not necessarily present in
the server-side scan list.

### 3.5 Automatic SMS ingestion

`SmsIngestionService` uses the `telephony` package and
`permission_handler`. It is intentionally Android-specific:

- requests SMS read/receive permission;
- registers foreground and background listeners;
- checks the user’s ingestion setting;
- analyzes every non-empty incoming message;
- writes a local log;
- submits the message to the backend with source `AUTO_LISTENER`;
- publishes a foreground event through a broadcast stream;
- shows a notification when the configured threshold is reached.

`handleBackgroundSms()` is a top-level entry point marked with
`@pragma('vm:entry-point')`, as required for background isolates. It reloads
the saved auth session, performs local analysis, attempts a backend scan, saves
the result, and alerts for fraud/high threat.

The product promise shown in the onboarding bottom sheet is “real-time SMS
protection”: automatic background ingestion, local privacy-first analysis, and
live threat alerts. The implementation reflects that promise on Android, but
SMS interception is not portable to iOS, desktop, or web.

### 3.6 Local storage and feedback

`SmsStorageService` uses `SharedPreferences` with JSON strings:

- `sms_logs_v1`: local scan history;
- `feedback_logs_v1`: user corrections for future model improvement;
- ingestion, notifications, and threshold settings;
- safety-tip bookmarks and quiz high score through
  `SafetyTipsService`.

On first run, four representative mock messages are inserted: two fraud
messages and two safe messages. This makes the dashboard visually useful before
the device has received real SMS traffic, but it also means a fresh install is
not an empty production state.

When a user marks a message Safe or Fraud, the app records the correction,
updates the local classification, and stores the original classification,
threat, and user feedback for future ML training. For backend-originated fraud
records, “Mark as Safe” first attempts to delete the server record using
`DELETE /api/scans/fraud/{id}`. The Dart service itself labels this endpoint as
provisional, and the current Spring controller does not expose that delete
route. “Mark as Fraud” calls `POST /api/scans/fraud`, which also needs to be
verified against the backend implementation.

### 3.7 Notifications and reporting

`NotificationService` creates a high-importance Android notification channel and
shows a large-text alert containing sender, threat percentage, and message
content. Notification permission and battery-optimization permission are
requested on Android.

The log detail UI can report a suspicious sender by opening the device SMS
application addressed to `15040` with a body such as `Fraud +278...`. This is a
device-level handoff, not a backend report API.

### 3.8 Safety education

`SafetyTipsService` contains a static catalog covering banking OTPs, delivery
fees, family impersonation, prize scams, and suspicious domains. Each tip has
red flags, recommended actions, and a realistic example.

`SafetyTipsPage` adds:

- category filtering;
- text search;
- bookmarked tips;
- a “Spot-the-Scam” quiz;
- locally stored high score.

This is deliberately an educational feature and does not depend on the ML
service.

## 4. Local detection engine

`SmsDetectionService.analyze()` is a deterministic rule-based detector used
for immediate local feedback and offline fallback. It checks:

- suspicious sender identifiers such as `alert`, `verify`, `secure`, `bank`,
  and `support`;
- rewards and lottery terms such as `win`, `prize`, `voucher`, and `gift
  card`;
- links and call-to-action terms;
- mobile-money references such as AirtelMoney, M-Pesa, TigoPesa, and HaloPesa;
- transfer instructions including Swahili phrases such as `utatuma`,
  `hakikisha jina`, and `lipia namba`;
- urgency, account verification, bank, login, and unauthorized-access terms.

The engine returns:

- a threat level from 0 to 1;
- `Safe` or `Fraud`;
- user-facing feedback;
- matched reasons.

Its threat score is heuristic: fraud messages are placed around 0.92–0.99 and
safe messages around 0.01–0.05, with a sender-name boost. It is useful for
responsive UX and offline protection, but it should not be described as the
same model used by the backend.

`parseBackendResult()` converts the ML service’s `is_scam`/`isScam`, `label`,
and `confidence` fields into the same mobile result shape. For a safe label it
uses `1 - confidence` as the threat index; for a scam label it uses confidence
directly.

## 5. React web client

The `web-client/` application is a separate React 19 + TypeScript + Vite
application. Its visible branding and terminology make it an **Admin Portal**,
not a second copy of the consumer mobile UI.

`App.tsx` uses local React state to switch between login, OTP verification,
forgot-password, reset-password, and dashboard screens. There is no router or
global auth store.

### Authentication

`LoginPage.tsx`:

- presents an admin email/password form;
- pre-fills a demonstration admin email and password;
- validates email and six-character minimum password;
- supports password visibility and dark/light theme switching;
- displays an “Admin Portal” badge.

`web-client/src/services/authService.ts` calls the backend for login and OTP
operations, but also contains a hardcoded admin credential fallback and an
offline success fallback for that same account. This is suitable only for a
prototype/demo and must not remain in a production deployment.

The web client uses endpoint names from the older integration contract for
password reset (`/api/auth/forgot-password`, `/verify-code`, and
`/reset-password`) while the current Spring controller uses
`/password-resets/...`. These paths need to be unified.

### Dashboard

`DashboardPage.tsx` is a substantial interactive admin console. It models:

- overview statistics;
- fraud alerts;
- SMS records;
- fraud detection rules;
- blocked senders;
- users and roles;
- profile editing;
- notifications;
- charts and telemetry;
- command-copy actions;
- filters, search, modals, and table interactions.

The initial values are declared in arrays such as `mockStats`,
`mockAlerts`, `initialSmsRecords`, `initialRules`, `initialBlacklist`, and
`initialUsers`. Actions update React state only. Consequently, the current web
dashboard demonstrates the intended administrator workflow, but it is not yet
a complete live admin client.

The backend already provides corresponding admin endpoints:

```text
GET   /api/admin/stats
GET   /api/admin/fraud-trend
GET   /api/admin/alerts
GET   /api/admin/scans
GET   /api/admin/users
GET   /api/admin/senders
GET   /api/admin/senders/blocked
POST  /api/admin/senders/block
PATCH /api/admin/users/{userId}/role
```

The next integration step for the web client is to replace mock arrays with
typed API calls, store/access the JWT, and map backend DTOs to the dashboard
types in `src/types/dashboard.ts`.

## 6. Backend and data flow supporting the frontend

### Authentication and security

The Spring backend uses:

- Spring Security with stateless sessions;
- BCrypt password hashing;
- JWT access tokens and token-version invalidation;
- database-backed roles (`ADMIN`, `USER`);
- method security with `@PreAuthorize`;
- public `/api/auth/**` and Swagger endpoints;
- JWT-protected application endpoints;
- a common `ApiResponse` envelope and global exception handler.

OTP codes are managed by `otp/` and delivered by the email services/templates.
The exact persistence is currently in-memory (`InMemoryOtpStore`), so OTP state
is lost if the backend restarts unless the implementation is extended.

### Scan pipeline

`ScanController` exposes:

```text
GET  /api/scans
POST /api/scans
```

`SmsScanService` sends the message body to `MlFraudDetectionClient`, which
uses a configured `RestClient` to call `/predict` on the Python service. If the
result is not a scam, the service returns an empty result and does not save a
row. If it is a scam, it saves sender, body, verdict, confidence, source, user
ID, and timestamp to `sms_scans`.

The current migrations show the schema’s evolution:

- users and roles are created in `V1__init.sql`;
- scans are introduced in `V2__create_sms.sql`/`V3__sms_scans.sql`;
- `V4__make_user_id_and_verdict_nullable.sql` adds compatibility flexibility
  and `is_scam`.

### Admin functionality

`AdminServiceImpl` calculates total, fraud, safe, and review counts; groups
fraud by day for trend charts; returns recent fraud alerts; pages through
scans; lists senders; persists blocked senders; and updates roles while
preventing self-demotion and demotion of the last active administrator.

This server-side capability is substantially ahead of the current web client
integration and is the natural source for the admin dashboard.

## 7. ML service and model

`main.py` is a FastAPI service titled “Bongo Scam Detector.” It loads the
tokenizer and `BertForSequenceClassification` model once during application
startup from `MODEL_DIR`, defaulting to `./final_model`.

Endpoints:

```text
GET  /health
POST /predict
```

`/predict` accepts a non-empty `message`, tokenizes it to a maximum length of
128, runs inference on CPU or CUDA, and returns:

```json
{
  "message": "original SMS text",
  "label": "scam",
  "is_scam": true,
  "confidence": 0.9564
}
```

The model metadata and weights are in `final_model/`. The Docker Compose stack
builds this service on port `8000`, exposes the Spring backend on `8080`, and
runs PostgreSQL on `5432`. In the default Compose network the backend calls the
ML service as `http://ml-service:8000`; `application.yml` also supports an
external `ML_SERVICE_URL`.

## 8. Deployment and development

`docker-compose.yml` defines the local multi-service environment:

- PostgreSQL 15 with database `sms_fraud`;
- ML service;
- Spring backend;
- persistent database volume.

The backend uses Maven, Java 21, PostgreSQL, Flyway, and Spring Boot. The
frontend uses Flutter/Dart and Android-specific plugins. The web client uses
Node/Vite.

CI in `.github/workflows/ci.yml`:

- scans git history with Gitleaks;
- runs backend verification against PostgreSQL;
- type-checks/builds the web client;
- builds and pushes backend/web Docker images on push;
- runs an OWASP ZAP API scan against a running backend.

Deployment in `deploy.yml` is manual and connects to an EC2 host over SSH,
pulls Docker images, starts the production Compose file, and prunes unused
images.

## 9. Current gaps and takeover priorities

The following items are the most important for a new developer:

1. **Choose the canonical Flutter package.** The complete implementation is
   under `frontend/`, while root `lib/` and root `pubspec.yaml` are a second
   Flutter package with overlapping services and screens.
2. **Unify authentication contracts.** Flutter, React, and the historical auth
   guide use different endpoint names and different assumptions about whether
   login returns a token or first requires OTP verification.
3. **Complete JWT handling in the web client.** The React client currently does
   not persist or attach an access token and includes hardcoded demo credentials.
4. **Connect the admin dashboard to `/api/admin/**`.** The backend has live
   admin services, but the React dashboard remains primarily mock/in-memory.
5. **Resolve scan classification semantics.** The backend persists fraud-only
   scans, while the mobile UI presents both Safe and Fraud local logs.
6. **Implement or remove provisional fraud feedback routes.** The Flutter
   client calls `/api/scans/fraud` and `DELETE /api/scans/fraud/{id}`, but the
   visible Spring scan controller does not currently define those operations.
7. **Persist OTP state in a shared store for production.** In-memory OTP
   storage is acceptable for local development but is not resilient across
   restarts or multiple backend instances.
8. **Move blocklist state to the backend.** Mobile blocklist entries and web
   admin blacklist entries are currently separate client-side models even
   though backend sender-blocking endpoints exist.
9. **Review sensitive defaults and generated artifacts.** Demo credentials,
   default database passwords, permissive CORS, local URLs, and checked-in
   model/build outputs should be clearly separated between development and
   production.
10. **Add integration tests for the end-to-end contract.** The most valuable
    test would submit a message from the Flutter-shaped payload through Spring
    to FastAPI and verify the returned envelope, persistence behavior, and
    client rendering.

## 10. Recommended mental model for future development

Treat Argus as two user experiences over one security platform:

- **Consumer mobile protection:** local-first, permission-driven, real-time
  SMS interception, alerts, scan history, feedback, and safety education.
- **Administrator operations:** authenticated web console for system-level
  statistics, fraud trends, scan review, rule/blacklist management, and user
  administration.

The backend should become the shared source of truth for identities, roles,
fraud records, blocked senders, and operational analytics. The Flutter client
can continue using local storage for responsiveness and offline behavior, but
should synchronize with the backend through a documented contract. The React
client should consume the existing admin endpoints rather than maintain a
parallel mock data model. Once those boundaries are aligned, the repository’s
existing components form a coherent end-to-end fraud detection product.
