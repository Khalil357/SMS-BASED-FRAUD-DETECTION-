package com.example.smsfraud.otp;

import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;

@Service
public class OtpServiceImpl implements OtpService {

    private static final Duration OTP_TTL = Duration.ofMinutes(5);
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();

    private final OtpStore otpStore;

    public OtpServiceImpl(OtpStore otpStore) {
        this.otpStore = otpStore;
    }

    @Override
    public String issueCode(String phone) {
        String code = String.format("%06d", SECURE_RANDOM.nextInt(1_000_000));
        otpStore.save(phone, new OtpCode(code, Instant.now().plus(OTP_TTL)));
        return code;
    }

    @Override
    public boolean verifyCode(String phone, String code) {
        return otpStore.find(phone)
                .map(entry -> entry.expiresAt().isAfter(Instant.now()) && entry.code().equals(code))
                .orElse(false);
    }

    @Override
    public void invalidate(String phone) {
        otpStore.delete(phone);
    }
}
