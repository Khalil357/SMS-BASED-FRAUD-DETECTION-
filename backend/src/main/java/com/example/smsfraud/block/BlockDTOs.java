package com.example.smsfraud.block;

import java.util.List;

public record BlockRequest(
        String phoneNumber,
        String reason
) {}

public record BlockedListResponse(
        List<String> blockedNumbers
) {}
