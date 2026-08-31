package com.example.smsfraud.controller;

import com.example.smsfraud.entity.SmsScan;
import com.example.smsfraud.scan.dto.ScanQueryRequest;
import com.example.smsfraud.service.SmsScanService;
import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/scans")
public class SmsScanController {

    private final SmsScanService service;

    public SmsScanController(SmsScanService service) {
        this.service = service;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {

        UUID userId = currentUserId();
        Page<SmsScan> result = service.listForUser(userId, PageRequest.of(page, size));

        List<Map<String, Object>> items = result.getContent().stream()
                .map(this::toDto)
                .toList();

        Map<String, Object> data = new HashMap<>();
        data.put("content", items);
        data.put("page", result.getNumber());
        data.put("size", result.getSize());
        data.put("totalElements", result.getTotalElements());

        return respond(200, "OK", data);
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> query(@Valid @RequestBody ScanQueryRequest req) {
        UUID userId = currentUserId();
        SmsScan saved = service.queryAndSave(
                userId,
                req.getSender(),
                req.getMessageBody(),
                req.getSource() == null ? "MANUAL_QUERY" : req.getSource());
        return respond(201, "Scan saved", toDto(saved));
    }

    private UUID currentUserId() {
        Object principal = SecurityContextHolder.getContext().getAuthentication().getPrincipal();
        if (!(principal instanceof UUID userId)) {
            throw new IllegalStateException("Unauthenticated");
        }
        return userId;
    }

    private Map<String, Object> toDto(SmsScan s) {
        Map<String, Object> dto = new HashMap<>();
        dto.put("scanId", s.getScanId());
        dto.put("sender", s.getSender() == null ? "" : s.getSender());
        dto.put("messageBody", s.getMessageBody());
        dto.put("verdict", s.getVerdict());
        dto.put("confidence", s.getConfidence() == null ? 0.0 : s.getConfidence());
        dto.put("source", s.getSource());
        dto.put("scannedAt", s.getScannedAt().toString());
        return dto;
    }

    private ResponseEntity<Map<String, Object>> respond(int status, String message, Map<String, Object> data) {
        Map<String, Object> body = new HashMap<>();
        body.put("message", message);
        body.put("data", data == null ? Map.of() : data);
        return ResponseEntity.status(status).body(body);
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ResponseEntity<Map<String, Object>> handleBadRequest(IllegalArgumentException ex) {
        Map<String, Object> body = new HashMap<>();
        body.put("message", ex.getMessage());
        body.put("statusCode", 400);
        return ResponseEntity.badRequest().body(body);
    }
}
