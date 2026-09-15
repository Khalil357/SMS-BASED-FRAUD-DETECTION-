package com.example.smsfraud.auth.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import jakarta.validation.constraints.NotBlank;

public record VerifyLoginOtpRequest(
        @NotBlank String email,
        @NotBlank @JsonProperty("verificationCode") String verificationCode) {
}
