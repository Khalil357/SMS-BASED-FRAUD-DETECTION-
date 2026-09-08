package com.example.smsfraud.scan.dto;

import com.example.smsfraud.scan.SmsScan;

import java.time.Instant;
import java.util.UUID;

public record FraudAlertResponse(
        UUID scanId,
        String sender,
        String messageBody,
        String verdict,
        Double confidence,
        Instant scannedAt
) {
    public static FraudAlertResponse from(SmsScan scan) {
        return new FraudAlertResponse(
                scan.getScanId(),
                scan.getSender(),
                scan.getMessageBody(),
                scan.getVerdict(),
                scan.getConfidence(),
                scan.getScannedAt()
        );
    }
}
