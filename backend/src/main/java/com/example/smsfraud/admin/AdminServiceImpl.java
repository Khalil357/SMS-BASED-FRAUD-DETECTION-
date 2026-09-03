package com.example.smsfraud.admin;

import com.example.smsfraud.admin.dto.AdminStatsResponse;
import com.example.smsfraud.admin.dto.AlertResponse;
import com.example.smsfraud.admin.dto.AdminSmsResponse;
import com.example.smsfraud.admin.dto.FraudTrendPoint;
import com.example.smsfraud.sender.BlockedSender;
import com.example.smsfraud.sender.BlockedSenderRepository;
import com.example.smsfraud.scan.SmsScan;
import com.example.smsfraud.scan.SmsScanRepository;
import com.example.smsfraud.user.User;
import com.example.smsfraud.user.UserRepository;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

@Service
public class AdminServiceImpl implements AdminService {

    private final SmsScanRepository smsScanRepository;
    private final UserRepository userRepository;
    private final BlockedSenderRepository blockedSenderRepository;

    public AdminServiceImpl(SmsScanRepository smsScanRepository, UserRepository userRepository, BlockedSenderRepository blockedSenderRepository) {
        this.smsScanRepository = smsScanRepository;
        this.userRepository = userRepository;
        this.blockedSenderRepository = blockedSenderRepository;
    }

    @Override
    public AdminStatsResponse getSystemStats() {
        long totalSms = smsScanRepository.count();
        long fraudDetected = smsScanRepository.countByVerdict("FRAUD");
        long safeSms = smsScanRepository.countByVerdict("SAFE");
        long pendingReview = smsScanRepository.countByVerdict("REVIEW");
        // Or if the system marks low confidence as "SUSPICIOUS" that works too.

        return new AdminStatsResponse(totalSms, fraudDetected, safeSms, pendingReview);
    }

    @Override
    public List<FraudTrendPoint> getFraudTrend(int days) {
        Instant startDate = Instant.now().minus(days, ChronoUnit.DAYS);
        List<SmsScan> frauds = smsScanRepository.findByVerdictAndScannedAtAfter("FRAUD", startDate);

        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("EEE").withZone(ZoneId.systemDefault());
        
        Map<String, Long> grouped = frauds.stream()
                .collect(Collectors.groupingBy(
                        scan -> formatter.format(scan.getScannedAt()),
                        Collectors.counting()
                ));

        List<FraudTrendPoint> trend = new ArrayList<>();
        // Iterate over the last N days to keep order
        for (int i = days - 1; i >= 0; i--) {
            Instant date = Instant.now().minus(i, ChronoUnit.DAYS);
            String dayName = formatter.format(date);
            trend.add(new FraudTrendPoint(dayName, grouped.getOrDefault(dayName, 0L)));
        }
        return trend;
    }

    @Override
    public List<AlertResponse> getRecentAlerts(int limit) {
        return smsScanRepository.findByVerdictOrderByScannedAtDesc("FRAUD", PageRequest.of(0, limit))
                .stream()
                .map(scan -> {
                    String recipient = userRepository.findById(scan.getUserId())
                            .map(User::getPhone)
                            .orElse("Unknown");
                            
                    return new AlertResponse(
                            scan.getScanId(),
                            scan.getSender() != null ? scan.getSender() : "Unknown",
                            recipient,
                            scan.getConfidence() != null ? scan.getConfidence() : 0.99,
                            scan.getScannedAt()
                    );
                })
                .collect(Collectors.toList());
    }

    @Override
    public Page<AdminSmsResponse> getSmsScans(String status, int page, int size) {
        PageRequest pageRequest = PageRequest.of(page, size);
        Page<SmsScan> scans;

        if (status != null && !status.isBlank()) {
            scans = smsScanRepository.findByVerdictOrderByScannedAtDesc(status.toUpperCase(), pageRequest);
        } else {
            scans = smsScanRepository.findAllByOrderByScannedAtDesc(pageRequest);
        }

        return scans.map(scan -> new AdminSmsResponse(
                scan.getScanId(),
                scan.getSender() != null ? scan.getSender() : "Unknown",
                scan.getMessageBody(),
                scan.getVerdict(),
                scan.getConfidence() != null ? scan.getConfidence() : 0.0,
                scan.getScannedAt()
        ));
    }

    @Override
    public List<String> getAllSenders() {
        return smsScanRepository.findDistinctSenders();
    }

    @Override
    public List<BlockedSender> getBlockedSenders() {
        return blockedSenderRepository.findAll();
    }

    @Override
    public void blockSender(String phoneNumber, String reason) {
        if (!blockedSenderRepository.existsByPhoneNumber(phoneNumber)) {
            BlockedSender blocked = new BlockedSender();
            blocked.setPhoneNumber(phoneNumber);
            blocked.setReason(reason);
            blockedSenderRepository.save(blocked);
        }
    }
}
