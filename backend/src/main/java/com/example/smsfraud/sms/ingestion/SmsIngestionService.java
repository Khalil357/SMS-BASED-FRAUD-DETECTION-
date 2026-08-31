package com.example.smsfraud.sms.ingestion;

import com.example.smsfraud.sms.ingestion.dto.ClassifiedSmsItem;
import com.example.smsfraud.sms.ingestion.dto.ProcessingStatus;
import com.example.smsfraud.sms.ingestion.dto.SmsIngestionRequest;
import com.example.smsfraud.sms.ingestion.dto.SmsIngestionResponse;
import org.springframework.stereotype.Service;

@Service
public class SmsIngestionService {

    private final SmsTrainingDataSink trainingDataSink;

    public SmsIngestionService(SmsTrainingDataSink trainingDataSink) {
        this.trainingDataSink = trainingDataSink;
    }

    public SmsIngestionResponse ingest(SmsIngestionRequest request) {
        for (ClassifiedSmsItem item : request.items()) {
            trainingDataSink.accept(item);
        }

        return new SmsIngestionResponse(request.items().size(), ProcessingStatus.ACCEPTED);
    }
}
