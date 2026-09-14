package com.example.smsfraud.feedback;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
public class FraudRecordService {

    private final FraudRecordRepository repository;

    public FraudRecordService(FraudRecordRepository repository) {

        this.repository = repository;
    }

    @Transactional
    public void deleteRecord(UUID recordId) {

        if (!repository.existsById(recordId)) {
            throw new RecordNotFoundException(recordId);
        }
        repository.deleteById(recordId);
    }
}
