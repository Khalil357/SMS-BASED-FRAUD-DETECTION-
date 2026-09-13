package com.example.smsfraud.fraudRecord;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

public class FraudRecordController {
    private final FraudRecordService fraudRecordService;

    public FraudRecordController  (FraudRecordService fraudRecordService){
        this.fraudRecordService = fraudRecordService;
    }

    @DeleteMapping("/{recordId}")
    public ResponseEntity <void> deleteInaccurateRecord(@PathVariable long recordId) {
        fraudRecordService.deleteRecord(recordId);
        return ResponseEntity.noContent().build();
    }
}
