package com.example.smsfraud.scan;

import com.example.smsfraud.scan.dto.FraudAlertResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/** Reads stored fraud alerts without invoking classification or persistence. */
@Service
public class FraudAlertService {

    private final SmsScanRepository repository;

    public FraudAlertService(SmsScanRepository repository) {
        this.repository = repository;
    }

    @Transactional(readOnly = true)
    public Page<FraudAlertResponse> listForUser(UUID userId, Pageable pageable) {
        return repository
                .findByUserIdAndVerdictOrderByScannedAtDescScanIdDesc(
                        userId, "FRAUD", pageable)
                .map(FraudAlertResponse::from);
    }
}
