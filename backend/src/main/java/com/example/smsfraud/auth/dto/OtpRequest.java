package com.example.smsfraud.auth.dto;

import jakarta.validation.constraints.NotBlank;

public record OtpRequest(@NotBlank String phoneNumber) {
}
