package com.example.smsfraud.common.security;

import java.util.UUID;

/**
 * Issues and validates authentication tokens. Concrete implementations (e.g. JWT)
 * are swapped in by Spring, so consumers depend on this contract only.
 *
 * <p>Tokens come in two kinds: a short-lived {@code access} token used to authorize
 * requests, and a longer-lived {@code refresh} token used only to obtain a new access
 * token. Both carry the user's {@code tokenVersion} so they can be revoked together.
 */
public interface TokenProvider {

    String generateAccessToken(UUID userId, int tokenVersion);

    String generateRefreshToken(UUID userId, int tokenVersion);

    TokenClaims validateToken(String token);
}
