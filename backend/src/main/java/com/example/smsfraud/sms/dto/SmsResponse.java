package com.example.smsfraud.sms.dto;

import com.example.smsfraud.sms.Sms;

import java.time.Instant;
import java.util.UUID;

public record SmsResponse(
        UUID smsId,
        String senderPhoneNumber,
        String messageBody,
        Instant receivedAt,
        String deviceSmsId) {

    public static SmsResponse from(Sms sms) {
        return new SmsResponse(
                sms.getSmsId(),
                sms.getSenderPhoneNumber(),
                sms.getMessageBody(),
                sms.getReceivedAt(),
                sms.getDeviceSmsId());
    }
}
