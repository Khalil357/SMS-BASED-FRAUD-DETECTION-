package com.example.smsfraud.sms.ingestion;

import com.example.smsfraud.sms.ingestion.dto.ClassifiedSmsItem;
import com.example.smsfraud.sms.ingestion.dto.ProcessingStatus;
import com.example.smsfraud.sms.ingestion.dto.SmsIngestionRequest;
import com.example.smsfraud.sms.ingestion.dto.SmsIngestionResponse;
import org.springframework.stereotype.Service;

/**
 * Orchestrates validated SMS batches and delegates each item to the configured
 * training-data sink. Keeping this class independent from JPA prevents the
 * ingestion endpoint from accidentally persisting raw messages to PostgreSQL.
 */
@Service
public class SmsIngestionService {

    private final SmsTrainingDataSink trainingDataSink;

    public SmsIngestionService(SmsTrainingDataSink trainingDataSink) {
        this.trainingDataSink = trainingDataSink;
    }

    public SmsIngestionResponse ingest(SmsIngestionRequest request) {
        // Validation occurs at the controller boundary; this layer owns dispatch order.
        for (ClassifiedSmsItem item : request.items()) {
            trainingDataSink.accept(item);
        }

        return new SmsIngestionResponse(request.items().size(), ProcessingStatus.ACCEPTED);
    }
}
