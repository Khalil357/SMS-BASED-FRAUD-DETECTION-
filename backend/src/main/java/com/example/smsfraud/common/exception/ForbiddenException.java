package com.example.smsfraud.common.exception;

import org.springframework.http.HttpStatus;

/** 403 Forbidden — authenticated, but not permitted (e.g. unverified/locked account). */
public class ForbiddenException extends ApiException {

    public ForbiddenException(String message) {
        super(HttpStatus.FORBIDDEN, message);
    }
}
