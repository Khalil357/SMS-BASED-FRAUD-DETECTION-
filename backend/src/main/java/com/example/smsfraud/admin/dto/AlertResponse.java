package com.example.smsfraud.admin.dto;

import java.time.Instant;
import java.util.UUID;

public record AlertResponse(
        UUID id,
        String sender,
        String recipient,
        double riskScore,
        Instant timestamp
) {}
