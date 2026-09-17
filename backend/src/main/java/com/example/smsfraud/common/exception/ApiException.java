package com.example.smsfraud.common.exception;

import org.springframework.http.HttpStatus;

import java.util.Map;

/**
 * Base for all domain exceptions that map to a specific HTTP status.
 * Extend (or use the provided subclasses) rather than throwing raw RuntimeExceptions.
 */
public abstract class ApiException extends RuntimeException {

    private final HttpStatus status;
    private final Map<String, Object> details;

    protected ApiException(HttpStatus status, String message) {
        this(status, message, null);
    }

    protected ApiException(HttpStatus status, String message, Map<String, Object> details) {
        super(message);
        this.status = status;
        this.details = details;
    }

    public HttpStatus getStatus() {
        return status;
    }

    /**
     * Optional machine-readable payload attached to the error body (e.g. the
     * phone number to verify after a failed login). Null when not provided.
     */
    public Map<String, Object> getDetails() {
        return details;
    }
}
