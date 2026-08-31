package com.example.smsfraud.sms.ingestion.dto;

/** Mobile-side classification of the sender identity or address format. */
public enum SenderType {
    OFFICIAL,
    PERSONAL,
    SHORTCODE,
    UNKNOWN
}
