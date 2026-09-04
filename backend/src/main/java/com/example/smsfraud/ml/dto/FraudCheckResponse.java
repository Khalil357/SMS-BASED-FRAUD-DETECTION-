package com.example.smsfraud.ml.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/** Result returned by the external ML fraud detection service. */
public record FraudCheckResponse(
        @JsonProperty("message") String message,
        @JsonProperty("label") String label,
        @JsonProperty("is_scam") boolean isScam,
        @JsonProperty("confidence") double confidence) {
}
