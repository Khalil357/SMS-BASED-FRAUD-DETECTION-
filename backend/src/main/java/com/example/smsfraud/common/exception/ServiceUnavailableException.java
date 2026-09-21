package com.example.smsfraud.common.exception;

import org.springframework.http.HttpStatus;

/** 503 Service Unavailable — a required upstream dependency cannot be reached. */
public class ServiceUnavailableException extends ApiException {

    public ServiceUnavailableException(String message) {
        super(HttpStatus.SERVICE_UNAVAILABLE, message);
    }
}
