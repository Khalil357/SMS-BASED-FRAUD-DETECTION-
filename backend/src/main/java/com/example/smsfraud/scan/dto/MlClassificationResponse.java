package com.example.smsfraud.scan.dto;

public record MlClassificationResponse(String label, boolean is_scam, double confidence) {
}
