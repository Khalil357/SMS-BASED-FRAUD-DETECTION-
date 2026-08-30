package com.example.smsfraud.sms;

import com.example.smsfraud.sms.dto.CreateSmsRequest;
import com.example.smsfraud.sms.dto.SmsResponse;
import com.example.smsfraud.user.User;
import com.example.smsfraud.user.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.time.Instant;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class SmsServiceImplTest {

    @Mock
    private SmsRepository smsRepository;

    @Mock
    private UserRepository userRepository;

    @InjectMocks
    private SmsServiceImpl smsService;

    @Test
    void ingestsSmsForAuthenticatedUser() {
        UUID userId = UUID.randomUUID();
        User user = new User();
        CreateSmsRequest request = new CreateSmsRequest(
                "+255712345678", "Your SMS text", Instant.parse("2026-08-28T06:42:15Z"), "15782");
        when(userRepository.findById(userId)).thenReturn(java.util.Optional.of(user));
        when(smsRepository.save(any(Sms.class))).thenAnswer(invocation -> {
            Sms sms = invocation.getArgument(0);
            sms.setSmsId(UUID.randomUUID());
            return sms;
        });

        SmsResponse response = smsService.ingest(userId, request);

        ArgumentCaptor<Sms> captor = ArgumentCaptor.forClass(Sms.class);
        verify(smsRepository).save(captor.capture());
        assertThat(captor.getValue().getUser()).isSameAs(user);
        assertThat(response.messageBody()).isEqualTo("Your SMS text");
        assertThat(response.deviceSmsId()).isEqualTo("15782");
    }
}
