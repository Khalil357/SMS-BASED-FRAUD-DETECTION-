package com.example.smsfraud.scan;

import com.example.smsfraud.ml.MlFraudDetectionClient;
import com.example.smsfraud.ml.dto.FraudCheckResponse;
import com.example.smsfraud.common.exception.BadRequestException;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.time.Instant;
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

    /** Uses the ML service as the sole fraud-decision authority. */
    public SmsScan queryAndSave(UUID userId, String sender, String body, String source) {
        String message = body == null ? "" : body.trim();
        if (message.isEmpty()) {
            throw new IllegalArgumentException("messageBody is required");
        }

        FraudCheckResponse result = mlFraudDetectionClient.analyzeSms(message);
        SmsScan scan = new SmsScan();
        scan.setUserId(userId);
        scan.setSender(sender);
        scan.setMessageBody(message);
        scan.setVerdict(result.isScam() ? "FRAUD" : "SAFE");
        scan.setConfidence(result.confidence());
        scan.setIsScam(result.isScam());
        scan.setSource(source == null || source.isBlank() ? "MANUAL_QUERY" : source);
        scan.setScannedAt(Instant.now());
        // Keep a complete model-scanned history. This lets the mobile client show
        // safe as well as fraudulent scans and prevents it from falling back to
        // a second, local rules engine when the model says a message is safe.
        return repository.save(scan);
    }

    /** Records an authenticated user's explicit fraud report. */
    public SmsScan markAsFraud(UUID userId, String sender, String body) {
        String message = body == null ? "" : body.trim();
        if (message.isEmpty()) {
            throw new BadRequestException("message is required when marking a scan as fraud");
        }

        SmsScan scan = new SmsScan();
        scan.setUserId(userId);
        scan.setSender(sender);
        scan.setMessageBody(message);
        scan.setVerdict("FRAUD");
        scan.setConfidence(1.0);
        scan.setIsScam(true);
        scan.setSource("USER_REPORTED");
        scan.setScannedAt(Instant.now());
        return repository.save(scan);
    }

    public Page<SmsScan> listForUser(UUID userId, Pageable pageable) {
        return repository.findByUserIdOrderByScannedAtDesc(userId, pageable);
    }
}
