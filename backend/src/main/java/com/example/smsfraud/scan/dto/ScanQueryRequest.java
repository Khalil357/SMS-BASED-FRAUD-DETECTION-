package com.example.smsfraud.scan.dto;

import jakarta.validation.constraints.NotBlank;

public class ScanQueryRequest {

    private String sender;

    @NotBlank
    private String messageBody;

    private String source;

    public String getSender() {
        return sender;
    }

    public void setSender(String sender) {
        this.sender = sender;
    }

    public String getMessageBody() {
        return messageBody;
    }

    public void setMessageBody(String messageBody) {
        this.messageBody = messageBody;
    }

    public String getSource() {
        return source;
    }

    public void setSource(String source) {
        this.source = source;
    }
}
