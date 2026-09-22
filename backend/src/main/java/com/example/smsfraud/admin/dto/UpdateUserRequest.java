package com.example.smsfraud.admin.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;

/**
 * Admin "edit user" payload. Lets an admin change a user's profile details and
 * active status. Role is intentionally omitted — it is fixed at creation time
 * and cannot be changed afterwards.
 */
public record UpdateUserRequest(
        @JsonProperty("full_name")
        @NotBlank(message = "Full name is required")
        @Size(max = 120, message = "Full name must be at most 120 characters")
        String fullName,

        @NotBlank(message = "Email is required")
        @Email(message = "A valid email address is required")
        @Pattern(regexp = "^[A-Za-z0-9._%+\\-]+@[A-Za-z0-9.\\-]+\\.[A-Za-z]{2,}$",
                message = "A valid email address is required")
        String email,

        @JsonProperty("phone_number")
        @NotBlank(message = "Phone number is required")
        @Pattern(regexp = "^\\+?[0-9]{9,15}$", message = "A valid phone number is required")
        String phoneNumber,

        boolean active) {
}
