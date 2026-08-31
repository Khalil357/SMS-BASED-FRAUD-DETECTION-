package com.example.smsfraud.sms.ingestion.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;

/**
 * Immutable classification supplied by the mobile client. The client flag is
 * contextual input only; it must not be treated as a trusted ML fraud verdict.
 */
public record ClassifiedSmsItem(
        @NotBlank @Size(max = 100) String sender,
        @NotBlank @Size(max = 10000) String body,
        @NotNull Instant timestamp,
        @NotNull SenderType senderType,
        @NotNull ContentCategory contentCategory,
        @NotNull Boolean isFlaggedByClient) {
}
