package com.example.smsfraud.common.exception;

import org.springframework.http.HttpStatus;

/** 400 Bad Request — invalid input or state the client can correct. */
public class BadRequestException extends ApiException {

    public BadRequestException(String message) {
        super(HttpStatus.BAD_REQUEST, message);
    }
}
