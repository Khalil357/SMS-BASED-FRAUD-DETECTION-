package com.example.smsfraud.sms.ingestion;

import com.example.smsfraud.common.security.TokenProvider;
import com.example.smsfraud.sms.ingestion.dto.ProcessingStatus;
import com.example.smsfraud.sms.ingestion.dto.SmsIngestionResponse;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(SmsIngestionController.class)
@AutoConfigureMockMvc(addFilters = false)
class SmsIngestionControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private SmsIngestionService smsIngestionService;

    @MockitoBean
    private TokenProvider tokenProvider;

    @Test
    void acceptsValidClassifiedSmsBatch() throws Exception {
        when(smsIngestionService.ingest(any()))
                .thenReturn(new SmsIngestionResponse(1, ProcessingStatus.ACCEPTED));

        mockMvc.perform(post("/api/v1/sms/ingest")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "items": [
                                    {
                                      "sender": "BANK",
                                      "body": "Your transaction was completed",
                                      "timestamp": "2026-08-31T07:30:00Z",
                                      "sender_type": "OFFICIAL",
                                      "content_category": "TRANSACTIONAL",
                                      "is_flagged_by_client": false
                                    }
                                  ]
                                }
                                """))
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.message").value("SMS training data accepted"))
                .andExpect(jsonPath("$.data.accepted_items").value(1))
                .andExpect(jsonPath("$.data.processing_status").value("ACCEPTED"));
    }

    @Test
    void rejectsInvalidClassifiedSmsBatch() throws Exception {
        mockMvc.perform(post("/api/v1/sms/ingest")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "items": [
                                    {
                                      "sender": "",
                                      "body": "",
                                      "timestamp": null,
                                      "sender_type": null,
                                      "content_category": null,
                                      "is_flagged_by_client": null
                                    }
                                  ]
                                }
                                """))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.message").value("Validation failed"));

        verifyNoInteractions(smsIngestionService);
    }
}
