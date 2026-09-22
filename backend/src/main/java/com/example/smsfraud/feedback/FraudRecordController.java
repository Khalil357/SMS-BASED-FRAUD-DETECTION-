package com.example.smsfraud.feedback;

import com.example.smsfraud.scan.SmsScan;
import com.example.smsfraud.scan.dto.ScanQueryRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;
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

    /**
     * Records a user-confirmed fraud report - the backend counterpart to the
     * app's "Mark Fraud" action. This intentionally does not go through the
     * ML classifier (POST /api/scans): the user has already made the call,
     * and re-running the model here could silently overrule them.
     */
    @PostMapping
    public ResponseEntity<Map<String, Object>> createRecord(
            @Valid @RequestBody ScanQueryRequest request,
            Authentication authentication) {
        UUID userId = UUID.fromString(authentication.getName());
        SmsScan saved = fraudRecordService.createRecord(
                userId, request.getSender(), request.getMessageBody());

        Map<String, Object> data = new HashMap<>();
        data.put("scanId", saved.getScanId());
        data.put("sender", saved.getSender());
        data.put("messageBody", saved.getMessageBody());
        data.put("verdict", saved.getVerdict());

        Map<String, Object> body = new HashMap<>();
        body.put("message", "Marked as fraud.");
        body.put("data", data);
        return ResponseEntity.status(201).body(body);
    }
}
