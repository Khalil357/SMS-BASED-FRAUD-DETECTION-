package com.example.smsfraud.feedback;

import com.example.smsfraud.common.exception.GlobalExceptionHandler;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.UUID;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(MockitoExtension.class)
class FraudRecordControllerTest {

    @Mock
    private FraudRecordRepository repository;

    private MockMvc mvc;
    private final UUID scanId = UUID.fromString("9c428bf8-b4aa-4f2b-a19c-cdb360f1df32");
    private final UUID userId = UUID.fromString("f6259721-3304-497f-a9b7-a9196d95704c");
    private final Authentication authentication =
            UsernamePasswordAuthenticationToken.authenticated(userId.toString(), null, java.util.List.of());

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.standaloneSetup(
                        new FraudRecordController(new FraudRecordService(repository)))
                .setControllerAdvice(new GlobalExceptionHandler(), new FeedbackExceptionHandler())
                .build();
    }

    @Test
    void deletesExistingRecordAndReturnsNoContent() throws Exception {
        when(repository.deleteOwnedById(scanId, userId)).thenReturn(1);

        mvc.perform(delete("/api/v1/fraud-records/{recordId}", scanId).principal(authentication))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        verify(repository).deleteOwnedById(scanId, userId);
    }

    @Test
    void missingOrForeignRecordReturnsNotFound() throws Exception {
        when(repository.deleteOwnedById(scanId, userId)).thenReturn(0);

        mvc.perform(delete("/api/v1/fraud-records/{recordId}", scanId).principal(authentication))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.status").value(404))
                .andExpect(jsonPath("$.message").value("Fraud record with ID " + scanId + " not found."));

        verify(repository).deleteOwnedById(scanId, userId);
    }

    @Test
    void repeatedDeletionReturnsNotFound() throws Exception {
        when(repository.deleteOwnedById(scanId, userId)).thenReturn(1, 0);

        mvc.perform(delete("/api/v1/fraud-records/{recordId}", scanId).principal(authentication))
                .andExpect(status().isNoContent());
        mvc.perform(delete("/api/v1/fraud-records/{recordId}", scanId).principal(authentication))
                .andExpect(status().isNotFound());

        verify(repository, org.mockito.Mockito.times(2)).deleteOwnedById(scanId, userId);
    }

    @ParameterizedTest
    @ValueSource(strings = {"invalid", "42", "9c428bf8-b4aa-4f2b-a19c-cdb360f1df3z"})
    void malformedRecordIdReturnsBadRequestWithoutDatabaseAccess(String recordId) throws Exception {
        mvc.perform(delete("/api/v1/fraud-records/{recordId}", recordId).principal(authentication))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.status").value(400));

        verifyNoInteractions(repository);
    }
}
