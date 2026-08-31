package com.example.smsfraud.sms;

import com.example.smsfraud.sms.dto.CreateSmsRequest;
import com.example.smsfraud.sms.dto.SmsResponse;

import java.util.UUID;

public interface SmsService {

    SmsResponse ingest(UUID authenticatedUserId, CreateSmsRequest request);
}
