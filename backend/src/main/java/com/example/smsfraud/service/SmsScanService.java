package com.example.smsfraud.service;

import com.example.smsfraud.entity.SmsScan;
import com.example.smsfraud.repository.SmsScanRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.util.Locale;
import java.util.UUID;

@Service
public class SmsScanService {

    private final SmsScanRepository repo;

    public SmsScanService(SmsScanRepository repo) {
        this.repo = repo;
    }

    public SmsScan save(UUID userId, String sender, String body,
                        String verdict, Double confidence, String source) {
        SmsScan scan = new SmsScan();
        scan.setUserId(userId);
        scan.setSender(sender);
        scan.setMessageBody(body);
        scan.setVerdict(verdict);
        scan.setConfidence(confidence);
        scan.setSource(source == null || source.isBlank() ? "MANUAL_QUERY" : source);
        return repo.save(scan);
    }

    /**
     * Analyze + persist a user-submitted message.
     * Placeholder rules until a real ML model is wired in.
     */
    public SmsScan queryAndSave(UUID userId, String sender, String body, String source) {
        String text = body == null ? "" : body.trim();
        if (text.isEmpty()) {
            throw new IllegalArgumentException("messageBody is required");
        }

        VerdictResult result = classify(text);
        return save(userId, sender, text, result.verdict(), result.confidence(), source);
    }

    public Page<SmsScan> listForUser(UUID userId, Pageable pageable) {
        return repo.findByUserIdOrderByScannedAtDesc(userId, pageable);
    }

    private VerdictResult classify(String text) {
        String lower = text.toLowerCase(Locale.ROOT);
        if (containsAny(lower, "otp", "pin", "password", "bank", "urgent", "click", "verify account", "won", "prize")) {
            return new VerdictResult("SUSPICIOUS", 0.75);
        }
        if (containsAny(lower, "fraud", "scam", "send money", "gift card", "bitcoin", "wire transfer")) {
            return new VerdictResult("FRAUD", 0.9);
        }
        return new VerdictResult("SAFE", 0.6);
    }

    private static boolean containsAny(String text, String... needles) {
        for (String n : needles) {
            if (text.contains(n)) {
                return true;
            }
        }
        return false;
    }

    private record VerdictResult(String verdict, double confidence) {}
}
