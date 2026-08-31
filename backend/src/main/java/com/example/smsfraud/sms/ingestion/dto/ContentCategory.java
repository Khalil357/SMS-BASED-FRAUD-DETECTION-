package com.example.smsfraud.sms.ingestion.dto;

/** Mobile-side classification of the SMS message purpose or risk category. */
public enum ContentCategory {
    TRANSACTIONAL,
    OTP,
    PROMOTIONAL,
    SUSPICIOUS,
    OTHER
}
