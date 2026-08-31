package com.example.smsfraud.otp;

import java.util.Optional;

/**
 * Persistence contract for one-time codes. The in-memory implementation is a dev
 * default; a Redis-backed implementation can be swapped in without touching
 * {@link OtpService}.
 */
public interface OtpStore {

    void save(String phone, OtpCode code);

    Optional<OtpCode> find(String phone);

    void delete(String phone);
}
