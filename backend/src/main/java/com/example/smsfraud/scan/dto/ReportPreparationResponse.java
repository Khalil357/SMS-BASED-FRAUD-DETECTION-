package com.example.smsfraud.scan.dto;

import java.time.Instant;
import java.util.UUID;

/** Instructions for the mobile client to prefill its own SMS composer. */
public record ReportPreparationResponse(
        UUID reportAttemptId,
        UUID scanId,
        String recipient,
        String messageBody,
        String status,
        boolean externallySubmitted,
        Instant preparedAt) {
}
