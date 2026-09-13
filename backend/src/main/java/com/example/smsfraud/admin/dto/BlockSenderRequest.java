package com.example.smsfraud.admin.dto;

import jakarta.validation.constraints.NotBlank;

public record BlockSenderRequest(
        @NotBlank String phoneNumber,
        String reason
) {}
