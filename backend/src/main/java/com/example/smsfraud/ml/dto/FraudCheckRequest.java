package com.example.smsfraud.ml.dto;

/** Request sent to the external ML fraud detection service. */
public record FraudCheckRequest(String sender, String content) {
}
