package com.example.smsfraud.auth.dto;

import jakarta.validation.constraints.NotBlank;

import com.fasterxml.jackson.annotation.JsonProperty;

public record LoginRequest(
        @JsonProperty("phone_number") @NotBlank String phoneNumber,
        @NotBlank String password) {
}
