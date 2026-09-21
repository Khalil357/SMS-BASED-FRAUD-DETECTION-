package com.example.smsfraud.scan.dto;

import com.fasterxml.jackson.annotation.JsonAlias;
import jakarta.validation.constraints.NotBlank;

/** Payload accepted when a signed-in user explicitly reports a message as fraud. */
public class MarkFraudRequest {

    private String sender;

    @NotBlank
    @JsonAlias({"messageBody", "message_body"})
    private String message;

    public String getSender() {
        return sender;
    }

    public void setSender(String sender) {
        this.sender = sender;
    }

    public String getMessage() {
        return message;
    }

    public void setMessage(String message) {
        this.message = message;
    }
}
