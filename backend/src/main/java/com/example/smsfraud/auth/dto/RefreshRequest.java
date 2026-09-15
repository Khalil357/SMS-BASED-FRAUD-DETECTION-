package com.example.smsfraud.auth.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;

/** Request body for {@code POST /api/auth/refresh} and {@code POST /api/auth/logout}. */
public record RefreshRequest(
        @NotBlank @JsonProperty("refreshToken") String refreshToken) {
}
