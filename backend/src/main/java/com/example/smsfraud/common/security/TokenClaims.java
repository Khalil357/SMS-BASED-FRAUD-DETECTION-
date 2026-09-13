package com.example.smsfraud.common.security;

import java.util.UUID;

/**
 * Decoded contents of a validated token: who it belongs to, its kind, and the
 * {@code tokenVersion} it was minted against. The version lets a token be
 * invalidated server-side without any stored state — bump the user's version
 * and every previously issued token for that user stops matching.
 */
public record TokenClaims(UUID userId, String type, Integer tokenVersion) {
}
