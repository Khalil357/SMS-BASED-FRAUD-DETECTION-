package com.example.smsfraud.admin;

import com.example.smsfraud.admin.dto.AdminStatsResponse;
import com.example.smsfraud.admin.dto.AlertResponse;
import com.example.smsfraud.admin.dto.AdminSmsResponse;
import com.example.smsfraud.admin.dto.BlockSenderRequest;
import com.example.smsfraud.admin.dto.FraudTrendPoint;
import com.example.smsfraud.sender.BlockedSender;
import com.example.smsfraud.common.dto.ApiResponse;
import com.example.smsfraud.user.UserRepository;
import com.example.smsfraud.user.dto.UserResponse;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.data.domain.Page;

import java.util.List;

/**
 * Admin-only endpoints, gated by {@code hasRole('ADMIN')}. Demonstrates the RBAC
 * wiring: authorities are loaded from the database per request by the JWT filter.
 */
@RestController
@RequestMapping("/api/admin")
@PreAuthorize("hasRole('ADMIN')")
public class AdminController {

    private final UserRepository userRepository;
    private final AdminService adminService;

    public AdminController(UserRepository userRepository, AdminService adminService) {
        this.userRepository = userRepository;
        this.adminService = adminService;
    }

    @GetMapping("/stats")
    public ResponseEntity<ApiResponse<AdminStatsResponse>> getStats() {
        return ResponseEntity.ok(ApiResponse.ok("Stats retrieved", adminService.getSystemStats()));
    }

    @GetMapping("/fraud-trend")
    public ResponseEntity<ApiResponse<List<FraudTrendPoint>>> getFraudTrend(
            @RequestParam(defaultValue = "7") int period) {
        return ResponseEntity.ok(ApiResponse.ok("Fraud trend retrieved", adminService.getFraudTrend(period)));
    }

    @GetMapping("/alerts")
    public ResponseEntity<ApiResponse<List<AlertResponse>>> getRecentAlerts(
            @RequestParam(defaultValue = "10") int limit) {
        return ResponseEntity.ok(ApiResponse.ok("Recent alerts retrieved", adminService.getRecentAlerts(limit)));
    }

    @GetMapping("/scans")
    public ResponseEntity<ApiResponse<Page<AdminSmsResponse>>> getSmsScans(
            @RequestParam(required = false) String status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.ok("SMS scans retrieved", adminService.getSmsScans(status, page, size)));
    }

    @GetMapping("/users")
    public ResponseEntity<ApiResponse<List<UserResponse>>> listUsers() {
        List<UserResponse> users = userRepository.findAllWithRoles().stream()
                .map(UserResponse::from)
                .toList();
        return ResponseEntity.ok(ApiResponse.ok("Users retrieved", users));
    }

    @GetMapping("/senders")
    public ResponseEntity<ApiResponse<List<String>>> listAllSenders() {
        return ResponseEntity.ok(ApiResponse.ok("Senders retrieved", adminService.getAllSenders()));
    }

    @GetMapping("/senders/blocked")
    public ResponseEntity<ApiResponse<List<BlockedSender>>> listBlockedSenders() {
        return ResponseEntity.ok(ApiResponse.ok("Blocked senders retrieved", adminService.getBlockedSenders()));
    }

    @PostMapping("/senders/block")
    public ResponseEntity<ApiResponse<Void>> blockSender(@Valid @RequestBody BlockSenderRequest req) {
        adminService.blockSender(req.phoneNumber(), req.reason());
        return ResponseEntity.ok(ApiResponse.ok("Sender blocked successfully"));
    }
}
