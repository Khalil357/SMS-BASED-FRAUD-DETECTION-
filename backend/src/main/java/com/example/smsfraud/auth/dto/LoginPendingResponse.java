package com.example.smsfraud.auth.dto;

/**
 * Returned by {@code POST /api/auth/login} when credentials are valid but the
 * OTP has not yet been verified. It deliberately carries NO token — the real
 * JWT is issued only after {@code POST /api/auth/verify-login-otp} succeeds.
 */
public record LoginPendingResponse(String email, String message) {
}
