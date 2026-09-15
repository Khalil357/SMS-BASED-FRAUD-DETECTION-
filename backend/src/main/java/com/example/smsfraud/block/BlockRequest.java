package com.example.smsfraud.block;

public record BlockRequest(
        String phoneNumber,
        String reason
) {}
