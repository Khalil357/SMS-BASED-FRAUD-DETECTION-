package com.example.smsfraud.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record ResendLoginOtpRequest(
        @NotBlank String email) {
}
