package com.example.smsfraud.sms.ingestion.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record SmsIngestionRequest(
        @NotEmpty @Size(max = 1000)
        List<@NotNull @Valid ClassifiedSmsItem> items) {

    public SmsIngestionRequest {
        items = items == null ? null : List.copyOf(items);
    }
}
