# JWT Session Timeout Plan

## What this changes

This backend uses JWTs instead of server-side HTTP sessions. Because of that, the session timeout is controlled by the token's expiration time. Once a token expires, protected endpoints should reject it with `401 Unauthorized`.

The mobile client will need to recognize that response and ask the user to sign in again (or refresh the token, if refresh tokens are supported).

## Changes

### `backend/src/main/resources/application.properties`

Update the JWT expiration settings. The current values, `30` and `60`, are being read as milliseconds, so tokens expire almost immediately. Replace them with explicit, practical values such as:

- Access token lifetime: 15 minutes
- Refresh token lifetime: 7 days

The exact values can be adjusted to match the application's security requirements.

### `backend/src/main/resources/application.yml`

Remove `server.servlet.session.timeout`. It only applies to server-managed `HttpSession` objects and has no effect on this stateless JWT setup. Leaving it in the configuration could make the timeout behavior harder to understand.

## How to verify it

1. Start the backend and sign in through Swagger or Postman.
2. Copy the JWT from the login response.
3. Call a protected endpoint with that token to confirm it works.
4. Wait until the configured access-token lifetime has passed.
5. Call the protected endpoint again.
6. Confirm that the response is `401 Unauthorized` and that the response message comes from `RestAuthenticationEntryPoint`.
7. Verify that the Android client handles the expired-token response appropriately.
