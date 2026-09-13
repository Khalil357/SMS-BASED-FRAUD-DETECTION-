package com.example.smsfraud.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import com.fasterxml.jackson.annotation.JsonProperty;

public record ResetPasswordRequest(
        @JsonProperty("phone_number") @NotBlank String phoneNumber,
        @JsonProperty("verification_code") @NotBlank String verificationCode,
        @JsonProperty("new_password") @NotBlank @Size(min = 8) String newPassword) {
}
