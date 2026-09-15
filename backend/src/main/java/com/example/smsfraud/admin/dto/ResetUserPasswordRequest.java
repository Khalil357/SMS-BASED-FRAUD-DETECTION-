package com.example.smsfraud.admin.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * Admin "reset user password" payload. An admin sets a brand-new password on behalf
 * of a user without knowing the old one.
 */
public record ResetUserPasswordRequest(
        @NotBlank(message = "Password is required")
        @Size(min = 8, max = 64, message = "Password must be between 8 and 64 characters")
        String password) {
}
