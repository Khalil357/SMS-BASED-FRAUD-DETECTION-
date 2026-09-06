package com.example.smsfraud.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

import com.fasterxml.jackson.annotation.JsonProperty;

public record RegisterRequest(
        @JsonProperty("full_name") @NotBlank String fullName,
        @NotBlank @Email String email,
        @JsonProperty("phone_number") @NotBlank String phoneNumber,
        String gender,
        @NotBlank String password) {
}
