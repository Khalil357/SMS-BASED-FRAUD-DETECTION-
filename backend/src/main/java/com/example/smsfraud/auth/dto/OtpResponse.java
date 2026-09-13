package com.example.smsfraud.auth.dto;

/**
 * Carries the issued one-time code back to the caller. Returned only for
 * development convenience (so the flow can be exercised without SMTP); remove
 * before production.
 */
public record OtpResponse(String otp) {
}
