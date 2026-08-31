package com.example.smsfraud.sms.ingestion;

import com.example.smsfraud.sms.ingestion.dto.ClassifiedSmsItem;

public interface SmsTrainingDataSink {

    void accept(ClassifiedSmsItem item);
}
