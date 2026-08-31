package com.example.smsfraud.sms.ingestion.dto;

/** Summary returned after every item has been accepted by the configured sink. */
public record SmsIngestionResponse(
        int acceptedItems,
        ProcessingStatus processingStatus) {
}
