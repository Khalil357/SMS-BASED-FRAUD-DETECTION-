package com.example.smsfraud.scan;

import com.example.smsfraud.common.exception.GlobalExceptionHandler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(MockitoExtension.class)
class FraudAlertControllerTest {

    @Mock
    private SmsScanRepository repository;

    private MockMvc mvc;
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.standaloneSetup(
                        new FraudAlertController(new FraudAlertService(repository)))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void readsFraudForAuthenticatedUserAndReturnsMobileFieldsAndPageMetadata() throws Exception {
        SmsScan scan = new SmsScan();
        scan.setScanId(UUID.randomUUID());
        scan.setUserId(userId);
        scan.setMessageBody("Send money to claim your prize");
        scan.setVerdict("FRAUD");
        scan.setScannedAt(Instant.parse("2026-09-06T10:00:00Z"));
        PageRequest pageable = PageRequest.of(1, 2);
        when(repository.findByUserIdAndVerdictOrderByScannedAtDescScanIdDesc(
                userId, "FRAUD", pageable))
                .thenReturn(new PageImpl<>(List.of(scan), pageable, 3));

        mvc.perform(get("/api/scans/fraud")
                        .principal(new UsernamePasswordAuthenticationToken(userId.toString(), null))
                        .param("page", "1").param("size", "2")
                        .param("userId", UUID.randomUUID().toString()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Fraud alerts retrieved"))
                .andExpect(jsonPath("$.data.content[0].scanId").value(scan.getScanId().toString()))
                .andExpect(jsonPath("$.data.content[0].messageBody").value(scan.getMessageBody()))
                .andExpect(jsonPath("$.data.content[0].verdict").value("FRAUD"))
                .andExpect(jsonPath("$.data.content[0].sender").isEmpty())
                .andExpect(jsonPath("$.data.content[0].confidence").isEmpty())
                .andExpect(jsonPath("$.data.content[0].userId").doesNotExist())
                .andExpect(jsonPath("$.data.number").value(1))
                .andExpect(jsonPath("$.data.totalElements").value(3));

        verify(repository).findByUserIdAndVerdictOrderByScannedAtDescScanIdDesc(
                userId, "FRAUD", pageable);
    }

    @Test
    void returnsEmptyPageWithDefaultPagination() throws Exception {
        PageRequest pageable = PageRequest.of(0, 20);
        when(repository.findByUserIdAndVerdictOrderByScannedAtDescScanIdDesc(
                userId, "FRAUD", pageable)).thenReturn(Page.empty(pageable));

        mvc.perform(get("/api/scans/fraud")
                        .principal(new UsernamePasswordAuthenticationToken(userId.toString(), null)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.content").isEmpty())
                .andExpect(jsonPath("$.data.totalElements").value(0));
    }

    @ParameterizedTest
    @CsvSource({"-1,20", "0,0", "0,-1", "0,101"})
    void rejectsInvalidPaginationBeforeQuerying(int page, int size) throws Exception {
        mvc.perform(get("/api/scans/fraud")
                        .principal(new UsernamePasswordAuthenticationToken(userId.toString(), null))
                        .param("page", Integer.toString(page))
                        .param("size", Integer.toString(size)))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(repository);
    }
}
