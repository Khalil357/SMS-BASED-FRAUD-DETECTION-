package com.example.smsfraud.common.exception;

import java.time.Instant;
import java.util.Map;

/**
 * Error envelope returned by {@link GlobalExceptionHandler}. Keeps the frontend's
 * top-level {@code message} key; {@code errors} carries per-field messages for
 * validation failures, and {@code data} may carry machine-readable hints (e.g.
 * the phone number to verify when a login is blocked on an unverified account).
 */
public record ErrorResponse(
        String message,
        int status,
        Instant timestamp,
        Map<String, String> errors,
        Map<String, Object> data) {

    public ErrorResponse(String message, int status) {
        this(message, status, Instant.now(), null, null);
    }

    public ErrorResponse(String message, int status, Instant timestamp, Map<String, String> errors) {
        this(message, status, timestamp, errors, null);
    }
}
