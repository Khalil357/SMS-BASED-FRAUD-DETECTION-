package com.example.smsfraud.auth.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ResetPasswordRequest(
        @NotBlank String phoneNumber,
        @NotBlank String verificationCode,
        @NotBlank @Size(min = 8) String newPassword) {
}
