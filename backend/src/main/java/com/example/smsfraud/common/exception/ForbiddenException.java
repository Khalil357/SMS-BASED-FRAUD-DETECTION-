package com.example.smsfraud.common.exception;

import org.springframework.http.HttpStatus;

import java.util.Map;

/** 403 Forbidden — authenticated, but not permitted (e.g. unverified/locked account). */
public class ForbiddenException extends ApiException {

    public ForbiddenException(String message) {
        super(HttpStatus.FORBIDDEN, message);
    }

    public ForbiddenException(String message, Map<String, Object> details) {
        super(HttpStatus.FORBIDDEN, message, details);
    }
}
