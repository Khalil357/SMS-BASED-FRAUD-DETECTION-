# Backend API Documentation

## 1. Purpose and scope

The backend is the server-side component of the AI-powered SMS Fraud Detection System. It exposes a REST API for the mobile and web clients, manages users and administrators, protects data with role-based access control, sends one-time passwords (OTPs), stores scan history, and connects to an external machine-learning (ML) service that classifies SMS messages as fraudulent or safe.

The backend does **not** perform ML inference locally. Its responsibility is to validate a request, securely call the ML service, save the returned result, and make that result available to the authenticated user or an administrator.

## 2. Technology stack

| Concern | Technology used | Purpose |
| --- | --- | --- |
| Application framework | Spring Boot 4, Java 21 | REST API, dependency injection, application configuration |
| Web layer | Spring Web MVC | Controllers, JSON request/response handling |
| Persistence | Spring Data JPA and PostgreSQL | User, scan, role, and blocked-sender storage |
| Authentication | Spring Security and JJWT | Stateless JWT authentication and authorization |
| Validation | Jakarta Bean Validation | Validates required fields, email formats, password lengths, and administrator payloads |
| OTP storage | Redis in production; in-memory store outside production | Holds short-lived OTPs |
| Schema management | Flyway in the `prod` profile | Applies database migrations on production startup |
| API documentation | springdoc OpenAPI / Swagger UI | Interactive API definition and testing interface |
| Notifications | SMTP or Resend email; Meseji SMS | Sends verification, login, reset, and administrative messages |
| Deployment | Docker Compose, Nginx, PostgreSQL, Redis | Containerised production runtime |

The Maven build configuration is defined in `pom.xml`; the application’s normal configuration is in `src/main/resources/application.properties` and production overrides are in `application-prod.properties`.

## 3. Layered backend design

The API follows a conventional layered Spring Boot design:

```text
Client (Flutter mobile app / web administration portal)
        |
        | HTTPS + JSON
        v
Nginx reverse proxy
        |
        v
Spring Boot REST controllers
        |
        +--> JWT security filter and role checks
        |
        v
Service layer (business rules and orchestration)
        |                    |                    |
        v                    v                    v
 PostgreSQL/JPA        Redis OTP store       External services
 (users and scans)     (production)          (ML, email, SMS)
```

### 3.1 Controller layer

Controllers define the public HTTP endpoints and translate HTTP requests into service calls. The main controllers are:

| Controller | Base path | Responsibility |
| --- | --- | --- |
| `AuthController` | `/api/auth` | Registration, OTP login, password reset, token refresh, and logout |
| `ScanController` | `/api/scans` | ML-powered SMS analysis, scan history, and user fraud reports |
| `FraudAlertController` | `/api/scans/fraud` | A user’s saved fraudulent-scan alerts |
| `FraudRecordController` | `/api/v1/fraud-records` | Deleting a user-owned incorrect scan record |
| `UserController` | `/api/users` | The signed-in user’s profile |
| `AdminController` | `/api/admin` | Dashboard data, scan administration, sender blocking, and user management |

### 3.2 Service layer

Services keep business rules out of controllers. For example, `AuthServiceImpl` coordinates user persistence, password hashing, OTP generation, email, SMS, and JWT issuance. `SmsScanService` calls the ML service and persists the ML verdict. `AdminServiceImpl` provides statistical queries and enforces protections such as preventing the last active administrator from being deleted or demoted.

### 3.3 Repository and entity layer

Spring Data JPA repositories provide the database access layer. The main entities are `User`, `UserRole`, `SmsScan`, and `BlockedSender`. UUIDs are used for user, scan, and blocked-sender identifiers.

## 4. Request and response conventions

### 4.1 URL and JSON conventions

All application endpoints are REST endpoints beneath `/api`. The configured Jackson naming strategy is `snake_case`; consequently, most JSON field names use snake case. A small number of DTOs deliberately use explicit camel-case names such as `refreshToken` and `verificationCode`; clients should follow the endpoint examples below.

All successful endpoints, except the delete fraud-record endpoint, use this envelope:

```json
{
  "message": "Human-readable result message",
  "data": {}
}
```

Validation and domain errors use this shape:

```json
{
  "message": "Validation failed",
  "status": 400,
  "timestamp": "2026-10-16T08:00:00Z",
  "errors": {
    "email": "must be a well-formed email address"
  }
}
```

`errors` is present for validation failures and is otherwise normally `null`. Authentication failures return the same error envelope with HTTP status `401` and message `Unauthorized`.

### 4.2 Pagination

Scan-list endpoints return Spring’s `Page` representation in `data`. It includes `content`, page number and size, `totalElements`, `totalPages`, and page navigation metadata. Requests default to `page=0` and `size=20`. The fraud-alert endpoint explicitly accepts sizes from 1 to 100.

### 4.3 Authentication header

Every endpoint other than `/api/auth/**`, Swagger/OpenAPI, and the health endpoint requires an access token:

```http
Authorization: Bearer <access-token>
```

The token subject is the user UUID. The server reloads the user and role from the database on each protected request, checks account status, and checks a token-version claim. Increasing the token version therefore immediately invalidates a user’s issued access and refresh tokens.

## 5. Authentication and account lifecycle

### 5.1 Registration and verification

1. A user sends their profile and password to `POST /api/auth/register`.
2. The server rejects duplicate email addresses or phone numbers, hashes the password with BCrypt, assigns the `USER` role, and saves an unverified active user.
3. It generates a six-digit OTP with a five-minute lifetime, sends it through email and SMS, and returns the account identifier. The current development response also returns the OTP; this is explicitly marked in code as development-only behaviour and should be removed in a public production API.
4. The user confirms the OTP through `POST /api/auth/password-resets/verify`, which also marks the account verified. Despite the route name, this endpoint is used by the current registration flow to verify a phone-based code.

### 5.2 Two-step login

1. `POST /api/auth/login` verifies the email-or-phone and password. No token is issued at this point.
2. The server creates a new email-keyed five-minute OTP and delivers it by email and, when available, SMS.
3. `POST /api/auth/verify-login-otp` verifies that code, marks the account verified, and returns access and refresh tokens.
4. The access token is valid for 15 minutes; the refresh token is valid for seven days under the default configuration.

### 5.3 Password reset and logout

Password reset codes are requested and verified using the phone-number endpoints. Resetting a password increments `tokenVersion`, revoking all prior sessions. Logout also increments the token version when it receives a valid refresh token.

## 6. API endpoint reference

### 6.1 Public authentication endpoints

| Method and path | Request body | Success result | Status |
| --- | --- | --- | --- |
| `POST /api/auth/register` | `full_name`, `email`, `phone_number`, optional `gender`, `password` | `user_id` and development OTP | 201 |
| `POST /api/auth/login` | `email` or `phone_number`, plus `password` | Email and message indicating OTP delivery; no token | 200 |
| `POST /api/auth/verify-login-otp` | `email`, `verificationCode` | Access token, refresh token, and user summary | 200 |
| `POST /api/auth/resend-login-otp` | `email` | Empty data value | 200 |
| `POST /api/auth/password-resets` | `phone_number` | Development OTP | 200 |
| `POST /api/auth/password-resets/resend` | `phone_number` | Development OTP | 200 |
| `POST /api/auth/password-resets/verify` | `phone_number`, `verification_code` | Empty data value | 200 |
| `POST /api/auth/password-resets/confirm` | `phone_number`, `verification_code`, `new_password` | Empty data value | 200 |
| `POST /api/auth/refresh` | `refreshToken` | Fresh access `token` and the refresh token | 200 |
| `POST /api/auth/logout` | `refreshToken` | Empty data value; invalid or expired refresh tokens are tolerated | 200 |

Example registration request:

```json
{
  "full_name": "Amina Hassan",
  "email": "amina@example.com",
  "phone_number": "+255712345678",
  "gender": "FEMALE",
  "password": "secure-password"
}
```

Example completed-login response:

```json
{
  "message": "Login OTP verified successfully",
  "data": {
    "token": "<JWT access token>",
    "refreshToken": "<JWT refresh token>",
    "user_id": "b02e9a7d-1eb8-4a6d-b887-b2e2d20572e9",
    "full_name": "Amina Hassan",
    "email": "amina@example.com",
    "phone_number": "+255712345678"
  }
}
```

### 6.2 Authenticated user endpoints

| Method and path | Purpose | Input | Success status |
| --- | --- | --- | --- |
| `GET /api/users/me` | Reads the profile belonging to the bearer token | None | 200 |
| `POST /api/scans` | Sends an SMS text to the ML classifier and saves its verdict | `sender` (optional), `message_body`, `source` (optional) | 201 |
| `GET /api/scans?page=0&size=20` | Lists the current user’s entire scan history, newest first | Pagination query parameters | 200 |
| `POST /api/scans/fraud` | Records a user’s explicit fraud report without calling ML | `sender` (optional), `message` | 201 |
| `GET /api/scans/fraud?page=0&size=20` | Lists only the current user’s scans with `FRAUD` verdict | Pagination query parameters | 200 |
| `DELETE /api/v1/fraud-records/{recordId}` | Deletes a scan only if it belongs to the current user | UUID path parameter | 204 |

Example ML scan request:

```json
{
  "sender": "+255700000000",
  "message_body": "You have won a prize. Send money to claim it.",
  "source": "MANUAL_QUERY"
}
```

The stored scan returned by `POST /api/scans` contains `scan_id`, `user_id`, `sender`, `message_body`, `verdict`, `confidence`, `source`, `scanned_at`, and `is_scam`. A model result with `is_scam=true` is stored with the verdict `FRAUD`; otherwise it is stored as `SAFE`. User-reported scans are saved as `FRAUD`, with confidence `1.0` and source `USER_REPORTED`.

### 6.3 Administrator endpoints

All `/api/admin/**` endpoints require an authenticated account with the `ADMIN` role.

| Method and path | Purpose | Input |
| --- | --- | --- |
| `GET /api/admin/stats` | Returns total, fraud, safe, and review scan counts | None |
| `GET /api/admin/fraud-trend?period=7` | Returns daily fraud counts for the requested number of days | `period` query parameter |
| `GET /api/admin/alerts?limit=10` | Returns most recent fraud alerts | `limit` query parameter |
| `GET /api/admin/scans?status=FRAUD&page=0&size=20` | Lists all scans; optionally filters by verdict | Optional `status`, pagination |
| `DELETE /api/admin/scans/{scanId}` | Removes a stored fraud scan after marking it safe in the administrative workflow | UUID path parameter |
| `GET /api/admin/users` | Lists all user and administrator profiles | None |
| `POST /api/admin/users` | Creates an `ADMIN` account and sends a welcome email | `full_name`, `email`, `phone_number`, `password`, optional `gender` |
| `PUT /api/admin/users/{userId}` | Updates a user profile and active status | `full_name`, `email`, `phone_number`, `active` |
| `PATCH /api/admin/users/{userId}/role` | Changes a user role between `ADMIN` and `USER` | `role` |
| `PATCH /api/admin/users/{userId}/password` | Replaces a user password and revokes their tokens | `password` |
| `DELETE /api/admin/users/{userId}` | Deletes a user, subject to administrative safeguards | UUID path parameter |
| `GET /api/admin/senders` | Returns distinct SMS senders in scan history | None |
| `GET /api/admin/senders/blocked` | Lists blocked senders | None |
| `POST /api/admin/senders/block` | Adds a sender to the blocked-sender list | `phone_number`, optional `reason` |

Administrative safety rules include the following:

- An administrator cannot delete themselves or change their own role.
- The last active administrator cannot be deleted, deactivated, or demoted to `USER`.
- New accounts created through the administration endpoint are assigned the `ADMIN` role; normal users register through the public registration endpoint.
- Role changes and password resets increase the affected user’s token version, invalidating their prior sessions.
- Only a scan whose verdict is `FRAUD` can be deleted by the administrative scan deletion endpoint.

## 7. ML integration flow

When an authenticated user calls `POST /api/scans`, the following sequence occurs:

```text
1. Validate that message_body is present.
2. Trim the message text.
3. POST { "message": "..." } to <ML_SERVICE_URL>/predict.
4. Receive the model response: message, label, is_scam, confidence.
5. Map is_scam=true to FRAUD; map false to SAFE.
6. Persist the scan together with user, sender, source, confidence, and timestamp.
7. Return the saved scan to the caller.
```

The ML service is the sole automated decision authority. If it cannot be reached, returns an error status, or produces an empty response, the backend returns a service-unavailable error rather than applying a local fallback rule. This prevents a different non-ML rule engine from silently producing contradictory classifications.

The ML base URL and API key are externally configured through `ML_SERVICE_URL` and `ML_SERVICE_API_KEY`; they are not hard-coded into application logic.

## 8. Security design

### 8.1 Authentication and authorization

- Passwords are hashed with BCrypt before storage; plaintext passwords are not persisted.
- The API is stateless: there is no server-side HTTP session, CSRF is disabled for the token-based API, and form login/basic authentication are disabled.
- Access and refresh tokens are signed with HS256 using the configured `JWT_SECRET`.
- Access tokens are accepted only when their type is `access`, their signature and expiry are valid, the user exists and is active/unlocked, and their `tokenVersion` matches the user record.
- Refresh tokens are accepted only on refresh/logout operations and must have the `refresh` type.
- Role access is supplied as `ROLE_ADMIN` or `ROLE_USER` and enforced by Spring method-security annotations. `/api/admin/**` additionally requires `ADMIN`.

### 8.2 OTP protection

OTPs are six-digit values produced using `SecureRandom` and expire after five minutes. Production uses Redis so OTPs survive application restarts; development uses an in-memory concurrent map. Codes are removed after a successful verification or password reset.

### 8.3 HTTP and deployment protection

The production Docker Compose configuration places Nginx in front of the application. PostgreSQL and Redis are not exposed as public host ports. Containers use a read-only filesystem where practical, drop Linux capabilities, set `no-new-privileges`, and use health checks. CORS origins are configurable through `CORS_ALLOWED_ORIGINS`; production should use explicit trusted frontend origins rather than `*`.

## 9. Database model

| Table | Key fields | Role in the system |
| --- | --- | --- |
| `user_roles` | `role_id`, `role_name` | Defines the `ADMIN` and `USER` roles |
| `users` | `user_id`, email, phone, password hash, role, verification and token-version fields | Stores identities and account state |
| `sms` | `sms_id`, `user_id`, sender, message body, received time | Legacy/raw SMS storage table defined by migration |
| `sms_scans` | `scan_id`, `user_id`, sender, message body, verdict, confidence, source, timestamp | Stores every model scan and user-reported fraud record |
| `blocked_senders` | `blocked_sender_id`, phone number, reason, blocked time | Stores administrator-maintained blocked senders |

`sms_scans` has an index on `(user_id, scanned_at DESC)` to support a user’s recent-history queries. User records maintain verification, active/locked status, failed-login metadata, and `token_version`, the latter enabling session revocation.

## 10. Configuration and operational requirements

The backend reads configuration from Spring properties and environment variables. Use `.env.example` as the deployment template; never commit a populated `.env` file.

| Environment variable | Purpose |
| --- | --- |
| `JWT_SECRET` | At least 32-byte HS256 signing secret |
| `SPRING_DATASOURCE_URL`, `SPRING_DATASOURCE_USERNAME`, `SPRING_DATASOURCE_PASSWORD` | PostgreSQL connection |
| `SPRING_DATA_REDIS_HOST`, `SPRING_DATA_REDIS_PORT`, `SPRING_DATA_REDIS_PASSWORD` | Production Redis connection |
| `ML_SERVICE_URL`, `ML_SERVICE_API_KEY` | External prediction service |
| `SMTP_*` or `RESEND_API_KEY` | Email delivery provider configuration |
| `MESEJI_API_KEY`, `MESEJI_SENDER_ID`, `MESEJI_BASE_URL` | SMS OTP delivery configuration |
| `CORS_ALLOWED_ORIGINS` | Trusted browser origins |
| `SWAGGER_ENABLED` | Enables public Swagger/OpenAPI pages in production when required |

For production, start with the `prod` Spring profile. It enables Flyway migrations, validates the schema rather than modifying it through Hibernate, selects Redis OTP storage, disables OpenAPI by default, and configures forwarded-header handling behind Nginx.

## 11. Health checks and interactive API documentation

| Resource | Path | Access |
| --- | --- | --- |
| Health check | `/actuator/health` | Public; used by Docker health checks |
| Swagger UI | `/swagger-ui.html` | Public in development; configurable in production |
| OpenAPI JSON | `/v3/api-docs` | Public in development; configurable in production |

Swagger UI registers the Bearer JWT scheme. After completing the login OTP flow, a tester can paste the access token into the **Authorize** dialog to call protected routes.

## 12. Error handling

The global exception handler centralises API error responses:

| Situation | Typical status | Example cause |
| --- | --- | --- |
| Request validation failure | 400 | Missing message, invalid email, short password |
| Domain validation failure | 400 | Invalid OTP, invalid role, attempt to demote last active admin |
| Authentication failure | 401 | Missing, expired, invalid, revoked, or refresh token used as an access token |
| Authorisation failure | 403 | Deactivated/locked account or non-admin access to an admin operation |
| Missing resource | 404 | User, scan, or owned fraud record does not exist |
| Duplicate resource | 409 | Email or phone number already exists |
| ML dependency failure | 503 | External prediction service cannot be reached or returns an error |
| Unexpected server error | 500 | Unhandled server-side failure |

The dedicated fraud-record advice additionally turns an invalid `{recordId}` UUID into a clear `400` response and a non-owned/non-existent record into `404`.

## 13. Testing and maintainability

The backend contains Spring Boot, controller, service, repository integration, email, and administrative tests under `src/test/java`. The test suite covers the application context, SMS scan persistence and ML interaction, fraud-alert retrieval, administrative scan/user workflows, fraud-record deletion ownership, and SMTP email behaviour.

The separation of controller, service, repository, DTO, security, ML-client, OTP, and notification packages keeps new features isolated. For example, replacing the ML provider requires changing the ML client rather than scan controllers or database logic; replacing the OTP store is handled through the `OtpStore` abstraction and Spring profiles.

## 14. Implementation notes for the report

- The system combines AI classification with user feedback: model results are stored as `SAFE` or `FRAUD`, while users can explicitly create `USER_REPORTED` fraud records.
- The backend treats the external ML service as authoritative and preserves its confidence score for audit, historical, and administrative use.
- The JWT token-version approach enables server-side revocation without abandoning stateless bearer authentication.
- The production profile uses explicit database migrations and Redis-backed OTP state, which improves repeatability and resilience relative to a purely in-memory deployment.
- Before a public production release, the OTP values currently included in registration and password-reset response payloads should be removed, as the source code identifies them as development convenience fields.
