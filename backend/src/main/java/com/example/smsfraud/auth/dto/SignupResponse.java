package com.example.smsfraud.auth.dto;

import java.util.UUID;

public record SignupResponse(UUID userId, String otp) {
}
