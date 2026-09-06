package com.example.smsfraud.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record VerifyLoginOtpRequest(
        @NotBlank String email,
        @NotBlank String verificationCode) {
}
