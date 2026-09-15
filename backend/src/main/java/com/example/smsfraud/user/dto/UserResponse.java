package com.example.smsfraud.user.dto;

import com.example.smsfraud.user.User;

import java.util.UUID;

/**
 * Public user view returned by admin/self endpoints. Excludes sensitive fields
 * (password hash, token version, lock counters, Google id).
 */
public record UserResponse(
        UUID userId,
        String fullName,
        String email,
        String phone,
        String role,
        boolean verified,
        boolean active) {

    public static UserResponse from(User user) {
        return new UserResponse(
                user.getUserId(),
                user.getFullName(),
                user.getEmail(),
                user.getPhone(),
                user.getRole().getRoleName(),
                user.isVerified(),
                user.isActive());
    }
}
