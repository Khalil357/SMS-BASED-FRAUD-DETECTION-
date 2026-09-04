package com.example.smsfraud.ml.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/** Request sent to the external ML fraud detection service. */
public record FraudCheckRequest(@JsonProperty("message") String message) {
}
