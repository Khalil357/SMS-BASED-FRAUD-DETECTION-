package com.example.smsfraud.ml.dto;

/** Result returned by the external ML fraud detection service. */
public record FraudCheckResponse(double probability, boolean isFraud, String riskLevel) {
}
