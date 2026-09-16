package com.example.smsfraud.scan;

import com.example.smsfraud.ml.MlFraudDetectionClient;
import com.example.smsfraud.ml.dto.FraudCheckResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

@Service
public class SmsScanService {

    private final SmsScanRepository repository;
    private final MlFraudDetectionClient mlFraudDetectionClient;

    public SmsScanService(SmsScanRepository repository,
                          MlFraudDetectionClient mlFraudDetectionClient) {
        this.repository = repository;
        this.mlFraudDetectionClient = mlFraudDetectionClient;
    }

    /** Analyzes and ALWAYS saves scan results to database. */
    public Optional<SmsScan> queryAndSave(UUID userId, String sender, String body, String source) {
        String message = body == null ? "" : body.trim();
        if (message.isEmpty()) {
            throw new IllegalArgumentException("messageBody is required");
        }

        boolean isScam = false;
        double confidence = 0.95;

        try {
            FraudCheckResponse result = mlFraudDetectionClient.analyzeSms(message);
            isScam = result.isScam();
            confidence = result.confidence();
        } catch (Exception e) {
            // Fallback heuristic if ML service is unreachable
            String lower = message.toLowerCase();
            isScam = lower.contains("http") || lower.contains("www.") || lower.contains("bit.ly")
                    || lower.contains("win") || lower.contains("claim") || lower.contains("urgent")
                    || lower.contains("bank") || lower.contains("verify") || lower.contains("otp")
                    || lower.contains("suspended") || lower.contains("deactivated");
            confidence = isScam ? 0.85 : 0.90;
        }

        SmsScan scan = new SmsScan();
        scan.setUserId(userId);
        scan.setSender(sender == null || sender.isBlank() ? "Unknown" : sender);
        scan.setMessageBody(message);
        scan.setVerdict(isScam ? "FRAUD" : "SAFE");
        scan.setConfidence(confidence);
        scan.setIsScam(isScam);
        scan.setSource(source == null || source.isBlank() ? "MANUAL_QUERY" : source);
        scan.setScannedAt(Instant.now());

        return Optional.of(repository.save(scan));
    }

    public SmsScan saveManualFraudScan(UUID userId, String sender, String body) {
        String message = body == null ? "" : body.trim();
        SmsScan scan = new SmsScan();
        scan.setUserId(userId);
        scan.setSender(sender == null || sender.isBlank() ? "Unknown" : sender);
        scan.setMessageBody(message);
        scan.setVerdict("FRAUD");
        scan.setConfidence(1.0);
        scan.setIsScam(true);
        scan.setSource("USER_REPORT");
        scan.setScannedAt(Instant.now());
        return repository.save(scan);
    }

    public Page<SmsScan> listForUser(UUID userId, Pageable pageable) {
        return repository.findByUserIdOrderByScannedAtDesc(userId, pageable);
    }
}
