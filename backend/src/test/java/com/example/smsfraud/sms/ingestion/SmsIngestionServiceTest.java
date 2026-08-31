package com.example.smsfraud.sms.ingestion;

import com.example.smsfraud.sms.ingestion.dto.ClassifiedSmsItem;
import com.example.smsfraud.sms.ingestion.dto.ContentCategory;
import com.example.smsfraud.sms.ingestion.dto.ProcessingStatus;
import com.example.smsfraud.sms.ingestion.dto.SenderType;
import com.example.smsfraud.sms.ingestion.dto.SmsIngestionRequest;
import com.example.smsfraud.sms.ingestion.dto.SmsIngestionResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.inOrder;

@ExtendWith(MockitoExtension.class)
class SmsIngestionServiceTest {

    @Mock
    private SmsTrainingDataSink trainingDataSink;

    @InjectMocks
    private SmsIngestionService smsIngestionService;

    @Test
    void sendsEveryItemToTrainingDataSinkAndReturnsAcceptedCount() {
        ClassifiedSmsItem first = item("BANK", ContentCategory.TRANSACTIONAL);
        ClassifiedSmsItem second = item("12345", ContentCategory.OTP);
        SmsIngestionRequest request = new SmsIngestionRequest(List.of(first, second));

        SmsIngestionResponse response = smsIngestionService.ingest(request);

        InOrder inOrder = inOrder(trainingDataSink);
        inOrder.verify(trainingDataSink).accept(first);
        inOrder.verify(trainingDataSink).accept(second);
        assertThat(response.acceptedItems()).isEqualTo(2);
        assertThat(response.processingStatus()).isEqualTo(ProcessingStatus.ACCEPTED);
    }

    private ClassifiedSmsItem item(String sender, ContentCategory category) {
        return new ClassifiedSmsItem(
                sender,
                "Training message",
                Instant.parse("2026-08-31T07:30:00Z"),
                SenderType.OFFICIAL,
                category,
                false);
    }
}
