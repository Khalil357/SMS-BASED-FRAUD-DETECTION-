package com.example.smsfraud.block;

import java.util.List;

public record BlockedListResponse(
        List<String> blockedNumbers
) {}
