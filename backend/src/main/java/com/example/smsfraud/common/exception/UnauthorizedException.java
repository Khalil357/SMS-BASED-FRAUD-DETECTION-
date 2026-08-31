package com.example.smsfraud.common.exception;

import org.springframework.http.HttpStatus;

/** 401 Unauthorized — bad credentials. */
public class UnauthorizedException extends ApiException {

    public UnauthorizedException(String message) {
        super(HttpStatus.UNAUTHORIZED, message);
    }
}
