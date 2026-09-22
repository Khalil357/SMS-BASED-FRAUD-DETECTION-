package com.example.smsfraud.feedback;

import com.example.smsfraud.scan.SmsScan;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.UUID;

@Service
public class FraudRecordService {

    private final FraudRecordRepository repository;

    public FraudRecordService(FraudRecordRepository repository) {

        this.repository = repository;
    }

    @Transactional
    public void deleteRecord(UUID recordId, UUID userId) {

        if (repository.deleteOwnedById(recordId, userId) == 0) {
            throw new RecordNotFoundException(recordId);
        }
    }

    /**
     * Persists a user-confirmed fraud report. Unlike the ML-driven scan
     * pipeline (POST /api/scans), this always records verdict=FRAUD with
     * full confidence, since the user - not the model - is the source of
     * truth here (e.g. tapping "Mark Fraud" on a message the model missed).
     */
    @Transactional
    public SmsScan createRecord(UUID userId, String sender, String messageBody) {
        SmsScan scan = new SmsScan();
        scan.setUserId(userId);
        scan.setSender(sender);
        scan.setMessageBody(messageBody);
        scan.setVerdict("FRAUD");
        scan.setIsScam(true);
        scan.setConfidence(1.0);
        scan.setSource("USER_REPORTED");
        scan.setScannedAt(Instant.now());
        return repository.save(scan);
    }
}
