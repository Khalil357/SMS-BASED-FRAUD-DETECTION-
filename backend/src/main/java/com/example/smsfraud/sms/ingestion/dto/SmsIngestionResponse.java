package com.example.smsfraud.sms.ingestion.dto;

public record SmsIngestionResponse(
        int acceptedItems,
        ProcessingStatus processingStatus) {
}
