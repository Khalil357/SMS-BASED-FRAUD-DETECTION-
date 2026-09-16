package com.example.smsfraud.scan;

import com.example.smsfraud.common.dto.ApiResponse;
import com.example.smsfraud.common.exception.BadRequestException;
import com.example.smsfraud.scan.dto.FraudAlertResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/scans/fraud")
public class FraudAlertController {

    private final FraudAlertService fraudAlertService;
    private final SmsScanService smsScanService;

    public FraudAlertController(FraudAlertService fraudAlertService, SmsScanService smsScanService) {
        this.fraudAlertService = fraudAlertService;
        this.smsScanService = smsScanService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Page<FraudAlertResponse>>> list(
            Authentication authentication,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size
    ) {
        if (page < 0 || size < 1 || size > 100) {
            throw new BadRequestException(
                    "page must be >= 0 and size must be between 1 and 100");
        }

        UUID userId = UUID.fromString(authentication.getName());
        Page<FraudAlertResponse> alerts = fraudAlertService.listForUser(
                userId, PageRequest.of(page, size));

        return ResponseEntity.ok(ApiResponse.ok("Fraud alerts retrieved", alerts));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<SmsScan>> createFraudScan(
            Authentication authentication,
            @RequestBody Map<String, String> body
    ) {
        UUID userId = null;
        try {
            if (authentication != null && authentication.getName() != null) {
                userId = UUID.fromString(authentication.getName());
            }
        } catch (Exception ignored) {}

        String sender = body.getOrDefault("sender", "Unknown");
        String message = body.getOrDefault("message", body.getOrDefault("messageBody", ""));

        if (message.isBlank()) {
            throw new BadRequestException("Message text is required");
        }

        SmsScan saved = smsScanService.saveManualFraudScan(userId, sender, message);
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Message marked as fraud and saved to database", saved));
    }
}
