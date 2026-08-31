package com.example.smsfraud.otp;

/**
 * Issues and validates one-time codes, decoupled from their storage and delivery.
 */
public interface OtpService {

    String issueCode(String phone);

    boolean verifyCode(String phone, String code);

    void invalidate(String phone);
}
