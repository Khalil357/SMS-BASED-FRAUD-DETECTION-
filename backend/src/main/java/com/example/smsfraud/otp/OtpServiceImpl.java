package com.example.smsfraud.otp;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;

@Service
public class OtpServiceImpl implements OtpService {

    private static final Logger log = LoggerFactory.getLogger(OtpServiceImpl.class);

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
        // In-memory storage is only used in local development (dev profile), where the
        // OTP SMS/email may not be reachable. Log the code so flows can be verified
        // against the container logs instead of waiting for a delivered message.
        if (otpStore instanceof InMemoryOtpStore) {
            log.info("DEV OTP for {}: {}", phone, code);
        }
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
