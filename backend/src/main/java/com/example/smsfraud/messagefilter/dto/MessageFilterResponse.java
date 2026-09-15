package com.example.smsfraud.messagefilter.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Response consumed by the iOS Message Filter Extension.
 * {@code action} is the primary field the extension maps to {@code ILMessageFilterAction}.
 */
public record MessageFilterResponse(
        String action,
        @JsonProperty("is_scam") boolean isScam,
        String label,
        double confidence
) {
    public static MessageFilterResponse allow(String label, double confidence) {
        return new MessageFilterResponse("allow", false, label, confidence);
    }

    public static MessageFilterResponse filter(String label, double confidence) {
        return new MessageFilterResponse("filter", true, label, confidence);
    }
}
