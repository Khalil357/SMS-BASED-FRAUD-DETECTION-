package com.example.smsfraud.common.exception;

import org.springframework.http.HttpStatus;

/** 409 Conflict — the resource already exists or violates a uniqueness constraint. */
public class ConflictException extends ApiException {

    public ConflictException(String message) {
        super(HttpStatus.CONFLICT, message);
    }
}
