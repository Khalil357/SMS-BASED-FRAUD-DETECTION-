package com.example.smsfraud.scan;

import com.example.smsfraud.common.dto.ApiResponse;
import com.example.smsfraud.scan.dto.ScanQueryRequest;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Optional;
import java.util.UUID;

@RestController
@RequestMapping("/api/scans")
public class ScanController {

    private final SmsScanService smsScanService;

    public ScanController(SmsScanService smsScanService) {
        this.smsScanService = smsScanService;
    }

    @GetMapping
    public ResponseEntity<ApiResponse<Page<SmsScan>>> list(
            Authentication authentication,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        Page<SmsScan> scans = smsScanService.listForUser(
                authenticatedUserId(authentication), PageRequest.of(page, size));
        return ResponseEntity.ok(ApiResponse.ok("Scans retrieved", scans));
    }

    @PostMapping
    public ResponseEntity<ApiResponse<SmsScan>> scan(
            Authentication authentication,
            @Valid @RequestBody ScanQueryRequest request) {
        Optional<SmsScan> scan = smsScanService.queryAndSave(
                authenticatedUserId(authentication),
                request.getSender(),
                request.getMessageBody(),
                request.getSource());

        if (scan.isEmpty()) {
            return ResponseEntity.ok(
                    ApiResponse.ok("SMS analyzed; no fraud detected, so nothing was saved", null));
        }

        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Fraudulent SMS analyzed and saved successfully", scan.get()));
    }

    private UUID authenticatedUserId(Authentication authentication) {
        return UUID.fromString(authentication.getName());
    }
}
