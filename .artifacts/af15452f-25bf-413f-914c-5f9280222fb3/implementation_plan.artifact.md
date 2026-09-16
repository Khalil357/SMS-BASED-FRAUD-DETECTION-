# Implementation Plan - Session Timeout for JWT-based Authentication

The project uses a stateless JWT-based security architecture. Standard servlet session properties like `server.servlet.session.timeout` do not apply here because there is no server-side `HttpSession`. Instead, session duration is controlled by the expiration time of the JWT access token.

## User Review Required

> [!IMPORTANT]
> Since the backend is stateless, "Session Timeout" is equivalent to "JWT Expiration". When the JWT expires, the server will return a `401 Unauthorized` response. The client (Android app) must handle this by either refreshing the token or prompting the user to log in again.

## Proposed Changes

### Configuration

#### [MODIFY] [application.properties](file:///home/norbs/StudioProjects/SMS-BASED-FRAUD-DETECTION-/backend/src/main/resources/application.properties)
Correct the JWT expiration values. The current values (30 and 60) are interpreted as milliseconds, which causes tokens to expire instantly. We will set them to reasonable durations (e.g., 15 minutes for access, 7 days for refresh).

#### [MODIFY] [application.yml](file:///home/norbs/StudioProjects/SMS-BASED-FRAUD-DETECTION-/backend/src/main/resources/application.yml)
Remove the `server.servlet.session.timeout` property as it is ineffective for this JWT-based setup and might cause confusion.

## Verification Plan

### Manual Verification
1. Log in via the API (e.g., Swagger or Postman).
2. Capture the JWT token.
3. Wait for the expiration time.
4. Attempt a protected request with the expired token.
5. Verify that the server returns a `401 Unauthorized` with the message defined in `RestAuthenticationEntryPoint`.
