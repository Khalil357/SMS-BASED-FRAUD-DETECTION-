package com.example.smsfraud.common.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.SecretKey;
import java.nio.charset.StandardCharsets;
import java.util.Date;
import java.util.UUID;

/**
 * HS256 JWT implementation of {@link TokenProvider} (jjwt). The token subject
 * carries the user id; the {@code type} claim distinguishes access vs refresh,
 * and the {@code tokenVersion} claim ties a token to a specific session generation
 * so it can be revoked by bumping the user's version.
 */
@Component
public class JwtTokenProvider implements TokenProvider {

    private static final String TYPE_ACCESS = "access";
    private static final String TYPE_REFRESH = "refresh";

    private final SecretKey key;
    private final long accessExpirationMs;
    private final long refreshExpirationMs;

    public JwtTokenProvider(@Value("${app.jwt.secret}") String secret,
                            @Value("${app.jwt.expiration:900000}") long accessExpirationMs,
                            @Value("${app.jwt.refresh-expiration:604800000}") long refreshExpirationMs) {
        this.key = Keys.hmacShaKeyFor(secret.getBytes(StandardCharsets.UTF_8));
        this.accessExpirationMs = accessExpirationMs;
        this.refreshExpirationMs = refreshExpirationMs;
    }

    @Override
    public String generateAccessToken(UUID userId, int tokenVersion) {
        return buildToken(userId, TYPE_ACCESS, tokenVersion, accessExpirationMs);
    }

    @Override
    public String generateRefreshToken(UUID userId, int tokenVersion) {
        return buildToken(userId, TYPE_REFRESH, tokenVersion, refreshExpirationMs);
    }

    private String buildToken(UUID userId, String type, int tokenVersion, long ttlMs) {
        return Jwts.builder()
                .subject(userId.toString())
                .claim("type", type)
                .claim("tokenVersion", tokenVersion)
                .issuedAt(new Date())
                .expiration(new Date(System.currentTimeMillis() + ttlMs))
                .signWith(key)
                .compact();
    }

    @Override
    public TokenClaims validateToken(String token) {
        Claims claims = Jwts.parser()
                .verifyWith(key)
                .build()
                .parseSignedClaims(token)
                .getPayload();
        return new TokenClaims(
                UUID.fromString(claims.getSubject()),
                claims.get("type", String.class),
                claims.get("tokenVersion", Integer.class));
    }
}
