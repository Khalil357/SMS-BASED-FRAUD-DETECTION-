package com.example.smsfraud.sms;

import com.example.smsfraud.common.dto.ApiResponse;
import com.example.smsfraud.sms.dto.CreateSmsRequest;
import com.example.smsfraud.sms.dto.SmsResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/sms")
public class SmsController {

    private final SmsService smsService;

    public SmsController(SmsService smsService) {
        this.smsService = smsService;
    }

    @PostMapping
    public ResponseEntity<ApiResponse<SmsResponse>> ingest(
            @AuthenticationPrincipal UUID authenticatedUserId,
            @Valid @RequestBody CreateSmsRequest request) {
        SmsResponse response = smsService.ingest(authenticatedUserId, request);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("SMS ingested successfully", response));
    }
}
