package com.example.smsfraud.admin;

import com.example.smsfraud.common.exception.BadRequestException;
import com.example.smsfraud.common.exception.NotFoundException;
import com.example.smsfraud.email.EmailService;
import com.example.smsfraud.scan.SmsScan;
import com.example.smsfraud.scan.SmsScanRepository;
import com.example.smsfraud.sender.BlockedSenderRepository;
import com.example.smsfraud.user.UserRepository;
import com.example.smsfraud.user.UserRoleRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;
import java.util.UUID;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class AdminFraudScanDeletionTest {

    private SmsScanRepository scans;
    private AdminServiceImpl service;

    @BeforeEach
    void setUp() {
        scans = mock(SmsScanRepository.class);
        service = new AdminServiceImpl(scans, mock(UserRepository.class),
                mock(UserRoleRepository.class), mock(BlockedSenderRepository.class),
                mock(PasswordEncoder.class), mock(EmailService.class));
    }

    @Test
    void deletesAnExistingFraudScan() {
        UUID scanId = UUID.randomUUID();
        SmsScan scan = new SmsScan();
        scan.setScanId(scanId);
        scan.setVerdict("FRAUD");
        when(scans.findById(scanId)).thenReturn(Optional.of(scan));

        service.deleteFraudScan(scanId);

        verify(scans).delete(scan);
    }

    @Test
    void rejectsARecordThatIsNotFraud() {
        UUID scanId = UUID.randomUUID();
        SmsScan scan = new SmsScan();
        scan.setVerdict("SAFE");
        when(scans.findById(scanId)).thenReturn(Optional.of(scan));

        assertThrows(BadRequestException.class, () -> service.deleteFraudScan(scanId));

        verify(scans, never()).delete(scan);
    }

    @Test
    void reportsMissingScans() {
        UUID scanId = UUID.randomUUID();
        when(scans.findById(scanId)).thenReturn(Optional.empty());

        assertThrows(NotFoundException.class, () -> service.deleteFraudScan(scanId));
    }
}
