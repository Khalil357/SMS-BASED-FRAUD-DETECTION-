package com.example.smsfraud.common.exception;

import org.springframework.http.HttpStatus;

/**
 * Base for all domain exceptions that map to a specific HTTP status.
 * Extend (or use the provided subclasses) rather than throwing raw RuntimeExceptions.
 */
public abstract class ApiException extends RuntimeException {

    private final HttpStatus status;

    protected ApiException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    public HttpStatus getStatus() {
        return status;
    }
}
