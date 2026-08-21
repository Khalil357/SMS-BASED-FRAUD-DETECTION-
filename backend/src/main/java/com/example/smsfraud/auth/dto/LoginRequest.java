package com.example.smsfraud.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record LoginRequest(
        @NotBlank String phoneNumber,
        @NotBlank String password) {
}
