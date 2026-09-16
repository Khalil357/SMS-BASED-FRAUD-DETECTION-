package com.example.smsfraud.scan.dto;

import com.example.smsfraud.scan.SmsScan;
import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.Instant;
import java.util.Locale;
import java.util.UUID;

/**
 * Fraud alert DTO. Each component serializes with the global SNAKE_CASE
 * strategy; the extra {@code get*Alias()} methods expose the camelCase /
 * snake_case keys the mobile clients parse ({@code message}, {@code is_scam},
 * {@code label}, {@code createdAt}).
 */
public record FraudAlertResponse(
        UUID scanId,
        String sender,
        String messageBody,
        String verdict,
        Double confidence,
        Instant scannedAt
) {

    public static FraudAlertResponse from(SmsScan scan) {
        return new FraudAlertResponse(
                scan.getScanId(),
                scan.getSender(),
                scan.getMessageBody(),
                scan.getVerdict(),
                scan.getConfidence(),
                scan.getScannedAt());
    }

    @JsonProperty("message")
    public String getMessage() {
        return messageBody;
    }

    @JsonProperty("messageBody")
    public String getMessageBodyAlias() {
        return messageBody;
    }

    @JsonProperty("is_scam")
    public boolean getIsScam() {
        return "FRAUD".equalsIgnoreCase(verdict);
    }

    @JsonProperty("isScam")
    public boolean getIsScamAlias() {
        return "FRAUD".equalsIgnoreCase(verdict);
    }

    @JsonProperty("label")
    public String getLabel() {
        if (verdict == null) return "safe";
        return "FRAUD".equalsIgnoreCase(verdict) ? "scam" : verdict.toLowerCase(Locale.ROOT);
    }

    @JsonProperty("createdAt")
    public String getCreatedAt() {
        return scannedAt != null ? scannedAt.toString() : null;
    }
}