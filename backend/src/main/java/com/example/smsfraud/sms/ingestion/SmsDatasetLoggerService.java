package com.example.smsfraud.sms.ingestion;

import com.example.smsfraud.sms.ingestion.dto.ClassifiedSmsItem;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Lightweight training-data sink that emits one structured, searchable log
 * event per SMS. It deliberately has no repository or database dependency.
 *
 * <p>Application logs still contain message content, so production deployments
 * must apply suitable access controls and retention policies.</p>
 */
@Service
public class SmsDatasetLoggerService implements SmsTrainingDataSink {

    private static final Logger log = LoggerFactory.getLogger(SmsDatasetLoggerService.class);

    @Override
    public void accept(ClassifiedSmsItem item) {
        // Escape control characters so one SMS cannot forge additional log entries.
        log.info(
                "[ML_TRAINING_DATA] sender=\"{}\" body=\"{}\" timestamp=\"{}\" "
                        + "sender_type=\"{}\" content_category=\"{}\" flagged_by_client={}",
                escape(item.sender()),
                escape(item.body()),
                item.timestamp(),
                item.senderType(),
                item.contentCategory(),
                item.isFlaggedByClient());
    }

    private String escape(String value) {
        return value
                .replace("\\", "\\\\")
                .replace("\r", "\\r")
                .replace("\n", "\\n")
                .replace("\"", "\\\"");
    }
}
