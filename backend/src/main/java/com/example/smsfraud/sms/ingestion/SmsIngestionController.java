package com.example.smsfraud.sms.ingestion;

import com.example.smsfraud.common.dto.ApiResponse;
import com.example.smsfraud.sms.ingestion.dto.SmsIngestionRequest;
import com.example.smsfraud.sms.ingestion.dto.SmsIngestionResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Accepts classified SMS batches from the Flutter client. The existing security
 * configuration protects this route because only {@code /api/auth/**} is public.
 * Processing is asynchronous from the client's perspective, hence HTTP 202.
 */
@RestController
@RequestMapping("/api/v1/sms")
public class SmsIngestionController {

    private final SmsIngestionService smsIngestionService;

    public SmsIngestionController(SmsIngestionService smsIngestionService) {
        this.smsIngestionService = smsIngestionService;
    }

    @PostMapping("/ingest")
    public ResponseEntity<ApiResponse<SmsIngestionResponse>> ingest(
            @Valid @RequestBody SmsIngestionRequest request) {
        SmsIngestionResponse response = smsIngestionService.ingest(request);
        return ResponseEntity.status(HttpStatus.ACCEPTED)
                .body(ApiResponse.ok("SMS training data accepted", response));
    }
}
