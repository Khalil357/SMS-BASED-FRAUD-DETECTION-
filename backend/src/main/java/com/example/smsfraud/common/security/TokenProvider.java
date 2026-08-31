package com.example.smsfraud.common.security;

import java.util.UUID;

/**
 * Issues and validates authentication tokens. Concrete implementations (e.g. JWT)
 * are swapped in by Spring, so consumers depend on this contract only.
 */
public interface TokenProvider {

    String generateToken(UUID userId);

    UUID validateToken(String token);
}
