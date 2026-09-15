package com.example.smsfraud.auth.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.UUID;

public record LoginResponse(
        String token,
        @JsonProperty("refreshToken") String refreshToken,
        UUID userId,
        String fullName,
        String email,
        String phoneNumber,
        String gender) {
}
