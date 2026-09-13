package com.example.smsfraud.common.exception;

import java.time.Instant;
import java.util.Map;

/**
 * Error envelope returned by {@link GlobalExceptionHandler}. Keeps the frontend's
 * top-level {@code message} key; {@code errors} carries per-field messages for
 * validation failures.
 */
public record ErrorResponse(String message, int status, Instant timestamp, Map<String, String> errors) {

    public ErrorResponse(String message, int status) {
        this(message, status, Instant.now(), null);
    }
}
