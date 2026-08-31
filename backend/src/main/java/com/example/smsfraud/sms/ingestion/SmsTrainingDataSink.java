package com.example.smsfraud.sms.ingestion;

import com.example.smsfraud.sms.ingestion.dto.ClassifiedSmsItem;

/**
 * Boundary between HTTP ingestion and the downstream training-data pipeline.
 * Implementations can later publish to Kafka or an ML service without changing
 * the controller or orchestration service. The current ingestion flow must not
 * insert messages into a relational database.
 */
public interface SmsTrainingDataSink {

    void accept(ClassifiedSmsItem item);
}
