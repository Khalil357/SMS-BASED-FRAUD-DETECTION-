package com.example.smsfraud.auth.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/** Returned by {@code POST /api/auth/refresh}: a fresh access token and the echoed refresh token. */
public record RefreshResponse(
        String token,
        @JsonProperty("refreshToken") String refreshToken) {
}
