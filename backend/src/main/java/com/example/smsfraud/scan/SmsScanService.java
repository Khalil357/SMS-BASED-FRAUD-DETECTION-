package com.example.smsfraud.scan;

import com.example.smsfraud.ml.MlFraudDetectionClient;
import com.example.smsfraud.ml.dto.FraudCheckResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

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

    /** Uses the ML service as the sole fraud-decision authority. */
    public Optional<SmsScan> queryAndSave(UUID userId, String sender, String body, String source) {
        String message = body == null ? "" : body.trim();
        if (message.isEmpty()) {
            throw new IllegalArgumentException("messageBody is required");
        }

        FraudCheckResponse result = mlFraudDetectionClient.analyzeSms(message);
        if (!result.isScam()) {
            return Optional.empty();
        }

        SmsScan scan = new SmsScan();
        scan.setUserId(userId);
        scan.setSender(sender);
        scan.setMessageBody(message);
        scan.setVerdict("FRAUD");
        scan.setConfidence(result.confidence());
        scan.setSource(source == null || source.isBlank() ? "MANUAL_QUERY" : source);
        return Optional.of(repository.save(scan));
    }

    public Page<SmsScan> listForUser(UUID userId, Pageable pageable) {
        return repository.findByUserIdOrderByScannedAtDesc(userId, pageable);
    }
}
