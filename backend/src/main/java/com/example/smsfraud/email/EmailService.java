package com.example.smsfraud.email;

/**
 * Best-effort email delivery, decoupled from the auth flow. Failures are logged,
 * never thrown — callers must not depend on delivery succeeding (e.g. when no
 * SMTP server is configured during development).
 */
public interface EmailService {

    void sendVerificationCode(String toEmail, String code);

    /**
     * Notify a newly-created user that an admin has added them to the platform,
     * and tell them their assigned role.
     */
    void sendWelcomeEmail(String toEmail, String fullName, String role);

    /**
     * Notify a user that an admin has changed their account (profile, role, or status).
     */
    void sendAccountUpdatedEmail(String toEmail, String fullName);
}
