package com.example.smsfraud.admin.dto;

import java.time.Instant;
import java.util.UUID;

public record AdminSmsResponse(
        UUID id,
        String sender,
        String message,
        String fraudType,
        double riskScore,
        Instant timestamp
) {}
