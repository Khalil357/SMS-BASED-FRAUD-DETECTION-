package com.example.smsfraud.scan;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.MediaType;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import java.util.Optional;
import java.util.UUID;

import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@ExtendWith(MockitoExtension.class)
class SmsScanControllerTest {

    @Mock
    private SmsScanService service;

    private MockMvc mvc;
    private final UUID userId = UUID.randomUUID();

    @BeforeEach
    void setUp() {
        mvc = MockMvcBuilders.standaloneSetup(new ScanController(service)).build();
        SecurityContextHolder.getContext().setAuthentication(
                new UsernamePasswordAuthenticationToken(userId, null));
    }

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void returnsOkWithEmptyDataWhenNoFraudIsDetected() throws Exception {
        when(service.queryAndSave(userId, null, "Hello", "MANUAL_QUERY"))
                .thenReturn(Optional.empty());

        mvc.perform(post("/api/scans").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"messageBody":"Hello"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").value(
                        "SMS analyzed; no fraud detected, so nothing was saved"))
                .andExpect(jsonPath("$.data").isEmpty());
    }

    @Test
    void returnsCreatedWithSavedFraudScan() throws Exception {
        SmsScan scan = new SmsScan();
        scan.setScanId(UUID.randomUUID());
        scan.setMessageBody("Claim your prize");
        scan.setVerdict("FRAUD");
        when(service.queryAndSave(userId, "Sender", "Claim your prize", "MOBILE_APP"))
                .thenReturn(Optional.of(scan));

        mvc.perform(post("/api/scans").contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"sender":"Sender","messageBody":"Claim your prize","source":"MOBILE_APP"}
                                """))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.message").value("Scan saved"))
                .andExpect(jsonPath("$.data.scanId").value(scan.getScanId().toString()))
                .andExpect(jsonPath("$.data.verdict").value("FRAUD"));
    }
}
