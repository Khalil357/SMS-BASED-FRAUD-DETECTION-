package com.example.smsfraud.scan;

import com.example.smsfraud.common.exception.GlobalExceptionHandler;
import com.example.smsfraud.scan.dto.ReportPreparationResponse;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.time.Instant;
import java.util.UUID;

import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(MockitoExtension.class)
class ScanControllerTest {

    @Mock
    private SmsScanService smsScanService;

    private MockMvc mvc;
    private final UUID userId = UUID.randomUUID();
    private final UUID scanId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.standaloneSetup(new ScanController(smsScanService))
                .setControllerAdvice(new GlobalExceptionHandler())
                .build();
    }

    @Test
    void preparesSmsComposerInstructionsWithoutReportingExternalSuccess() throws Exception {
        when(smsScanService.prepareReport(eq(userId), eq(scanId))).thenReturn(
                new ReportPreparationResponse(UUID.randomUUID(), scanId, "15040", "Fraud",
                        "PREPARED", false, Instant.parse("2026-09-13T10:00:00Z")));

        mvc.perform(post("/api/scans/{scanId}/report-preparation", scanId)
                        .principal(new UsernamePasswordAuthenticationToken(userId.toString(), null))
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.data.recipient").value("15040"))
                .andExpect(jsonPath("$.data.messageBody").value("Fraud"))
                .andExpect(jsonPath("$.data.status").value("PREPARED"))
                .andExpect(jsonPath("$.data.externallySubmitted").value(false));
        verify(smsScanService).prepareReport(userId, scanId);
    }

    @Test
    void deletesTheAuthenticatedUsersRequestedResult() throws Exception {
        mvc.perform(delete("/api/scans/{scanId}", scanId)
                        .principal(new UsernamePasswordAuthenticationToken(userId.toString(), null)))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value("Classification result deleted"));
        verify(smsScanService).deleteForUser(userId, scanId);
    }

    @Test
    void rejectsInvalidScanId() throws Exception {
        mvc.perform(delete("/api/scans/not-a-uuid")
                        .principal(new UsernamePasswordAuthenticationToken(userId.toString(), null)))
                .andExpect(status().isBadRequest());
    }
}
