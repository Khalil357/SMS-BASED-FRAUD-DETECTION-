package com.example.smsfraud.otp;

import java.time.Instant;

/** A single-use verification code and its expiry instant. */
public record OtpCode(String code, Instant expiresAt) {
}
