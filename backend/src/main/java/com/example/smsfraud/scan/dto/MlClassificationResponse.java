package com.example.smsfraud.scan.dto;

public record MlClassificationResponse(String verdict, double confidence) {
}
