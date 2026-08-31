package com.example.smsfraud.email;

/**
 * Best-effort email delivery, decoupled from the auth flow. Failures are logged,
 * never thrown — callers must not depend on delivery succeeding (e.g. when no
 * SMTP server is configured during development).
 */
public interface EmailService {

    void sendVerificationCode(String toEmail, String code);
}
