package com.example.smsfraud.admin.dto;

import jakarta.validation.constraints.NotBlank;

/** Request body for {@code PATCH /api/admin/users/{userId}/role}. Role must be ADMIN or USER. */
public record UpdateRoleRequest(
        @NotBlank String role) {
}
