package com.example.smsfraud.feedback;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.UUID;

@RestController
@RequestMapping("/api/v1/fraud-records")
public class FraudRecordController {

    private final FraudRecordService fraudRecordService;

    public FraudRecordController(FraudRecordService fraudRecordService) {
        this.fraudRecordService = fraudRecordService;
    }

    @DeleteMapping("/{recordId}")
    public ResponseEntity<Void> deleteInaccurateRecord(
            @PathVariable("recordId") UUID recordId,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        fraudRecordService.deleteRecord(recordId, userId);
        return ResponseEntity.noContent().build();
    }
}
