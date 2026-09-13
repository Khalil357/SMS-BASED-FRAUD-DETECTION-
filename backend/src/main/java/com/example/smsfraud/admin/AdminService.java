package com.example.smsfraud.admin;

import com.example.smsfraud.admin.dto.AdminStatsResponse;
import com.example.smsfraud.admin.dto.AlertResponse;
import com.example.smsfraud.admin.dto.AdminSmsResponse;
import com.example.smsfraud.admin.dto.FraudTrendPoint;
import com.example.smsfraud.sender.BlockedSender;
import org.springframework.data.domain.Page;
import java.util.List;

public interface AdminService {
    AdminStatsResponse getSystemStats();
    List<FraudTrendPoint> getFraudTrend(int days);
    List<AlertResponse> getRecentAlerts(int limit);
    Page<AdminSmsResponse> getSmsScans(String status, int page, int size);
    List<String> getAllSenders();
    List<BlockedSender> getBlockedSenders();
    void blockSender(String phoneNumber, String reason);
}
