package com.example.smsfraud.sms.ingestion.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

/**
 * Validated batch accepted by the ingestion endpoint. The batch limit prevents
 * a single request from consuming unbounded memory or producing excessive logs.
 */
public record SmsIngestionRequest(
        @NotEmpty @Size(max = 1000)
        List<@NotNull @Valid ClassifiedSmsItem> items) {

    public SmsIngestionRequest {
        // Defensive copying keeps the record immutable even if the caller mutates its list.
        items = items == null ? null : List.copyOf(items);
    }
}
