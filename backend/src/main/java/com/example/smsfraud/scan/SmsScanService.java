package com.example.smsfraud.scan;

import com.example.smsfraud.entity.SmsScan;
import com.example.smsfraud.ml.MlFraudDetectionClient;
import com.example.smsfraud.ml.dto.FraudCheckResponse;
import com.example.smsfraud.smsScannedRepository.SmsScanRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

import java.util.Optional;
import java.util.UUID;

@Service
public class SmsScanService {

    private final SmsScanRepository repo;
    private final MlFraudDetectionClient mlFraudDetectionClient;

    public SmsScanService(SmsScanRepository repo,
                          MlFraudDetectionClient mlFraudDetectionClient) {
        this.repo = repo;
        this.mlFraudDetectionClient = mlFraudDetectionClient;
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

    /** Analyze a message with the ML service and persist the result in PostgreSQL. */
    public Optional<SmsScan> queryAndSave(UUID userId, String sender, String body, String source) {
        String text = body == null ? "" : body.trim();
        if (text.isEmpty()) {
            throw new IllegalArgumentException("messageBody is required");
        }

        FraudCheckResponse result = mlFraudDetectionClient.analyzeSms(text);
        if (!result.isScam()) {
            return Optional.empty();
        }

        return Optional.of(save(userId, sender, text, result.label(), result.confidence(), source));
    }

    public Page<SmsScan> listForUser(UUID userId, Pageable pageable) {
        return repo.findByUserIdOrderByScannedAtDesc(userId, pageable);
    }
}
