package com.example.smsfraud.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record VerifyCodeRequest(
        @NotBlank String phoneNumber,
        @NotBlank String verificationCode) {
}
