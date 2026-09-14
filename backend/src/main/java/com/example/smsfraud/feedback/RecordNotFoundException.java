package com.example.smsfraud.feedback;

import java.util.UUID;

public class RecordNotFoundException extends RuntimeException {

    public RecordNotFoundException(UUID recordId) {

        super("Fraud record with ID " + recordId + " not found.");
    }
}
