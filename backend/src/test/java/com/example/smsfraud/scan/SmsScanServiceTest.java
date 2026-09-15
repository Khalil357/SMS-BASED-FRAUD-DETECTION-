package com.example.smsfraud.scan;

import com.example.smsfraud.ml.MlFraudDetectionClient;
import com.example.smsfraud.ml.dto.FraudCheckResponse;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.util.Optional;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SmsScanServiceTest {

    @Mock
    private SmsScanRepository smsScanRepository;

    @Mock
    private MlFraudDetectionClient mlFraudDetectionClient;

    @InjectMocks
    private SmsScanService smsScanService;

    @Test
    void savesAMessageWhenTheModelDetectsAScam() {
        UUID userId = UUID.randomUUID();
        String message = "Hela Nitumie kwenye Airtelmoney hii 0680214294 jina FREDI SANGA.";
        when(mlFraudDetectionClient.analyzeSms(message))
                .thenReturn(new FraudCheckResponse(message, "scam", true, 0.9564));
        when(smsScanRepository.save(any(SmsScan.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        Optional<SmsScan> result = smsScanService.queryAndSave(
                userId, "+255680214294", message, "MOBILE_APP");

        ArgumentCaptor<SmsScan> captor = ArgumentCaptor.forClass(SmsScan.class);
        verify(smsScanRepository).save(captor.capture());
        assertThat(result).isPresent();
        assertThat(captor.getValue().getUserId()).isEqualTo(userId);
        assertThat(captor.getValue().getMessageBody()).isEqualTo(message);
        assertThat(captor.getValue().getVerdict()).isEqualTo("FRAUD");
        assertThat(captor.getValue().getConfidence()).isEqualTo(0.9564);
    }

    @Test
    void doesNotSaveAMessageWhenTheModelDoesNotDetectAScam() {
        String message = "Hello, how are you?";
        when(mlFraudDetectionClient.analyzeSms(message))
                .thenReturn(new FraudCheckResponse(message, "not_scam", false, 0.99));

        Optional<SmsScan> result = smsScanService.queryAndSave(
                UUID.randomUUID(), "+255700000000", message, "MOBILE_APP");

        assertThat(result).isEmpty();
        verifyNoInteractions(smsScanRepository);
    }
}
