package com.example.smsfraud.sms.ingestion.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;

public record ClassifiedSmsItem(
        @NotBlank @Size(max = 100) String sender,
        @NotBlank @Size(max = 10000) String body,
        @NotNull Instant timestamp,
        @NotNull SenderType senderType,
        @NotNull ContentCategory contentCategory,
        @NotNull Boolean isFlaggedByClient) {
}
