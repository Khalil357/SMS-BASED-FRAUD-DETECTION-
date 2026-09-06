package com.example.smsfraud.admin.dto;

public record AdminStatsResponse(
        long totalSms,
        long fraudDetected,
        long safeSms,
        long pendingReview
) {}
