package com.example.smsfraud.messagefilter;

import com.example.smsfraud.messagefilter.dto.AppleMessageFilterRequest;
import com.example.smsfraud.messagefilter.dto.MessageFilterResponse;
import com.example.smsfraud.ml.MlFraudDetectionClient;
import com.example.smsfraud.ml.dto.FraudCheckResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * Thin adapter: translate Apple Message Filter payloads into the existing ML pipeline.
 * Does not persist user scans (Apple cannot supply a JWT / user context).
 */
@Service
public class MessageFilterService {

    private static final Logger log = LoggerFactory.getLogger(MessageFilterService.class);

    private final MlFraudDetectionClient mlFraudDetectionClient;

    public MessageFilterService(MlFraudDetectionClient mlFraudDetectionClient) {
        this.mlFraudDetectionClient = mlFraudDetectionClient;
    }

    public MessageFilterResponse classify(AppleMessageFilterRequest request) {
        String body = extractBody(request);
        if (body == null || body.isBlank()) {
            return MessageFilterResponse.allow("empty", 1.0);
        }

        try {
            FraudCheckResponse result = mlFraudDetectionClient.analyzeSms(body.trim());
            if (result.isScam()) {
                return MessageFilterResponse.filter(
                        result.label() == null ? "scam" : result.label(),
                        result.confidence());
            }
            return MessageFilterResponse.allow(
                    result.label() == null ? "safe" : result.label(),
                    result.confidence());
        } catch (Exception ex) {
            // Fail open: filtering when ML is down would hide legitimate SMS.
            log.warn("Message filter ML classify failed; allowing message: {}", ex.getMessage());
            return MessageFilterResponse.allow("unavailable", 0.0);
        }
    }

    private static String extractBody(AppleMessageFilterRequest request) {
        if (request == null || request.getQuery() == null) {
            return null;
        }
        if (request.getQuery().getMessage() == null) {
            return null;
        }
        return request.getQuery().getMessage().getText();
    }
}
