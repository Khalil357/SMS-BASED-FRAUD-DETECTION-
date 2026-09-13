package com.example.smsfraud.auth.dto;

import java.util.UUID;

public record LoginResponse(
        String token,
        UUID userId,
        String fullName,
        String email,
        String phoneNumber) {
}
