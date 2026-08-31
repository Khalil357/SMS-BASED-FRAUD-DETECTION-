package com.example.smsfraud.sms.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;

public record CreateSmsRequest(
        @NotBlank @Size(max = 20) String senderPhoneNumber,
        @NotBlank @Size(max = 10000) String messageBody,
        @NotNull Instant receivedAt,
        @Size(max = 255) String deviceSmsId) {
}
