package com.example.smsfraud.messagefilter;

import com.example.smsfraud.messagefilter.dto.AppleMessageFilterRequest;
import com.example.smsfraud.messagefilter.dto.MessageFilterResponse;
import com.example.smsfraud.ml.MlFraudDetectionClient;
import com.example.smsfraud.ml.dto.FraudCheckResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MessageFilterServiceTest {

    @Mock
    private MlFraudDetectionClient mlFraudDetectionClient;

    @InjectMocks
    private MessageFilterService messageFilterService;

    @Test
    void filtersWhenModelDetectsScam() {
        String text = "Your account has been suspended. Verify immediately at https://evil.example";
        when(mlFraudDetectionClient.analyzeSms(text))
                .thenReturn(new FraudCheckResponse(text, "scam", true, 0.9564));

        MessageFilterResponse response = messageFilterService.classify(request(text));

        assertThat(response.action()).isEqualTo("filter");
        assertThat(response.isScam()).isTrue();
        assertThat(response.confidence()).isEqualTo(0.9564);
    }

    @Test
    void allowsWhenModelSaysSafe() {
        String text = "Hey, are we still meeting at 5?";
        when(mlFraudDetectionClient.analyzeSms(text))
                .thenReturn(new FraudCheckResponse(text, "not_scam", false, 0.99));

        MessageFilterResponse response = messageFilterService.classify(request(text));

        assertThat(response.action()).isEqualTo("allow");
        assertThat(response.isScam()).isFalse();
    }

    @Test
    void allowsWhenMlUnavailable() {
        String text = "Your order #12345 has been shipped.";
        when(mlFraudDetectionClient.analyzeSms(text))
                .thenThrow(new IllegalStateException("ML down"));

        MessageFilterResponse response = messageFilterService.classify(request(text));

        assertThat(response.action()).isEqualTo("allow");
        assertThat(response.label()).isEqualTo("unavailable");
    }

    private static AppleMessageFilterRequest request(String text) {
        AppleMessageFilterRequest.Message message = new AppleMessageFilterRequest.Message();
        message.setText(text);
        AppleMessageFilterRequest.Query query = new AppleMessageFilterRequest.Query();
        query.setSender("14085550001");
        query.setMessage(message);
        AppleMessageFilterRequest request = new AppleMessageFilterRequest();
        request.setVersion(1);
        request.setQuery(query);
        return request;
    }
}
