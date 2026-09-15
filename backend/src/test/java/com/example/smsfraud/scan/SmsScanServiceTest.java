package com.example.smsfraud.scan;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.client.RestTemplate;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SmsScanServiceTest {

    @Mock
    private SmsScanRepository smsScanRepository;

    @Mock
    private BlockedSenderRepository blockedSenderRepository;

    @Mock
    private RestTemplate restTemplate;

    @InjectMocks
    private SmsScanService smsScanService;

    @Test
    void savesAMessageWhenTheModelDetectsAScam() {
        UUID userId = UUID.randomUUID();
        String message = "Hela Nitumie kwenye Airtelmoney hii 0680214294 jina FREDI SANGA.";

        // Simulate via blocked sender (always FRAUD).
        when(blockedSenderRepository.existsByPhoneNumber("+255680214294")).thenReturn(true);
        when(smsScanRepository.save(any(SmsScan.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        SmsScan result = smsScanService.queryAndSave(
                userId, "+255680214294", message, "MOBILE_APP");

        ArgumentCaptor<SmsScan> captor = ArgumentCaptor.forClass(SmsScan.class);
        verify(smsScanRepository).save(captor.capture());
        assertThat(result).isNotNull();
        assertThat(captor.getValue().getUserId()).isEqualTo(userId);
        assertThat(captor.getValue().getMessageBody()).isEqualTo(message);
        assertThat(captor.getValue().getVerdict()).isEqualTo("FRAUD");
        assertThat(captor.getValue().getSource()).isEqualTo("MOBILE_APP");
    }

    @Test
    void savesMessageWithFallbackHeuristicsForSuspiciousContent() {
        UUID userId = UUID.randomUUID();
        String message = "Your OTP code is 123456, verify now";

        when(blockedSenderRepository.existsByPhoneNumber(any())).thenReturn(false);
        when(smsScanRepository.save(any(SmsScan.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        SmsScan result = smsScanService.queryAndSave(
                userId, "+255700000000", message, "MOBILE_APP");

        assertThat(result).isNotNull();
        assertThat(result.getUserId()).isEqualTo(userId);
        assertThat(result.getMessageBody()).isEqualTo(message);
        // OTP keyword triggers SUSPICIOUS heuristic
        assertThat(result.getVerdict()).isEqualTo("SUSPICIOUS");
        assertThat(result.getSource()).isEqualTo("MOBILE_APP");
    }

    @Test
    void savesMessageAsSafeForNormalContent() {
        UUID userId = UUID.randomUUID();
        String message = "Hello, are we still meeting for lunch today?";

        when(blockedSenderRepository.existsByPhoneNumber(any())).thenReturn(false);
        when(smsScanRepository.save(any(SmsScan.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        SmsScan result = smsScanService.queryAndSave(
                userId, "+255700000000", message, "MOBILE_APP");

        assertThat(result).isNotNull();
        assertThat(result.getUserId()).isEqualTo(userId);
        assertThat(result.getMessageBody()).isEqualTo(message);
        assertThat(result.getVerdict()).isEqualTo("SAFE");
        assertThat(result.getSource()).isEqualTo("MOBILE_APP");
    }

    @Test
    void blocksMessagesFromBlockedSendersWithHighConfidence() {
        UUID userId = UUID.randomUUID();
        String message = "Send money to claim your prize";
        String sender = "+27829876543";

        when(blockedSenderRepository.existsByPhoneNumber(sender)).thenReturn(true);
        when(smsScanRepository.save(any(SmsScan.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        SmsScan result = smsScanService.queryAndSave(
                userId, sender, message, "AUTO_LISTENER");

        assertThat(result).isNotNull();
        assertThat(result.getVerdict()).isEqualTo("FRAUD");
        assertThat(result.getConfidence()).isEqualTo(1.0);
    }
}
