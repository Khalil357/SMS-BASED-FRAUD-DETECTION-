package com.example.smsfraud.auth.dto;

import jakarta.validation.constraints.NotBlank;
import com.fasterxml.jackson.annotation.JsonProperty;

public record LoginRequest(
        @JsonProperty("phone_number") String phoneNumber,
        @JsonProperty("email") String email,
        @NotBlank String password) {
}
