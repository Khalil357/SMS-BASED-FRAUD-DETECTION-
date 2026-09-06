package com.example.smsfraud.scan;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import com.example.smsfraud.sender.BlockedSenderRepository;
import com.example.smsfraud.scan.dto.MlClassificationRequest;
import com.example.smsfraud.scan.dto.MlClassificationResponse;

import java.util.Locale;
import java.util.UUID;

@Service
public class SmsScanService {
    private static final Logger log = LoggerFactory.getLogger(SmsScanService.class);

    private final SmsScanRepository repo;
    private final BlockedSenderRepository blockedSenderRepository;
    private final RestTemplate restTemplate;

    @Value("${ml.service.url:}")
    private String mlServiceUrl;

    public SmsScanService(SmsScanRepository repo, BlockedSenderRepository blockedSenderRepository, RestTemplate restTemplate) {
        this.repo = repo;
        this.blockedSenderRepository = blockedSenderRepository;
        this.restTemplate = restTemplate;
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
     * Analyze and persist a user-submitted message.
     */
    public SmsScan queryAndSave(UUID userId, String sender, String body, String source) {
        String text = body == null ? "" : body.trim();
        if (text.isEmpty()) {
            throw new IllegalArgumentException("messageBody is required");
        }

        VerdictResult result = classify(text, sender);
        return save(userId, sender, text, result.verdict(), result.confidence(), source);
    }

    public Page<SmsScan> listForUser(UUID userId, Pageable pageable) {
        return repo.findByUserIdOrderByScannedAtDesc(userId, pageable);
    }

    private VerdictResult classify(String text, String sender) {
        // 1. Check Blocked Senders First (Highest Priority)
        if (sender != null && !sender.isBlank()) {
            if (blockedSenderRepository.existsByPhoneNumber(sender)) {
                log.info("Sender {} is blocked. Auto-classifying as FRAUD.", sender);
                return new VerdictResult("FRAUD", 1.0);
            }
        }

        // 2. Call the containerized ML service if it is configured
        if (mlServiceUrl != null && !mlServiceUrl.isBlank()) {
            try {
                MlClassificationRequest request = new MlClassificationRequest(text);
                MlClassificationResponse response = restTemplate.postForObject(mlServiceUrl + "/predict", request, MlClassificationResponse.class);
                if (response != null && response.label() != null) {
                    String label = response.label().toLowerCase(Locale.ROOT);
                    String verdict = response.is_scam() || "scam".equals(label)
                            ? "FRAUD"
                            : "SAFE";
                    return new VerdictResult(verdict, response.confidence());
                }
            } catch (Exception e) {
                log.error("Failed to reach ML service at {}. Falling back to heuristics.", mlServiceUrl, e);
            }
        }

        // 3. Fallback Heuristics
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
