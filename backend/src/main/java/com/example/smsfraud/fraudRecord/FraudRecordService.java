package com.example.smsfraud.fraudRecord;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;


@Service
public class FraudRecordService {
    private final FraudRecordRepository repository;

    public FraudRecordService(FraudRecordRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public void deleteRecord(long recordId) {

        /*if (!repository.existsById(recordId)) {
            throw new RecordNotFoundException("Fraud record with ID " + recordId + " not found.");
        } */

        repository.deleteById(recordId);
    }

}