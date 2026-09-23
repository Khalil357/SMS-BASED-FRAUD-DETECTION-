package com.example.smsfraud.admin;

import com.example.smsfraud.admin.dto.AdminStatsResponse;
import com.example.smsfraud.admin.dto.AlertResponse;
import com.example.smsfraud.admin.dto.AdminSmsResponse;
import com.example.smsfraud.admin.dto.CreateUserRequest;
import com.example.smsfraud.admin.dto.FraudTrendPoint;
import com.example.smsfraud.admin.dto.UpdateUserRequest;
import com.example.smsfraud.sender.BlockedSender;
import com.example.smsfraud.user.dto.UserResponse;
import org.springframework.data.domain.Page;
import java.util.List;
import java.util.UUID;

public interface AdminService {
    AdminStatsResponse getSystemStats();
    List<FraudTrendPoint> getFraudTrend(int days);
    List<AlertResponse> getRecentAlerts(int limit);
    Page<AdminSmsResponse> getSmsScans(String status, int page, int size);
    void deleteFraudScan(UUID scanId);
    List<String> getAllSenders();
    List<BlockedSender> getBlockedSenders();
    void blockSender(String phoneNumber, String reason);

    UserResponse updateUserRole(UUID userId, String role, UUID actorId);

    UserResponse createUser(CreateUserRequest req);

    UserResponse updateUser(UUID userId, UpdateUserRequest req, UUID actorId);

    void resetUserPassword(UUID userId, String newPassword, UUID actorId);

    void deleteUser(UUID userId, UUID actorId);
}
