package com.example.smsfraud.admin;

import com.example.smsfraud.admin.dto.AdminStatsResponse;
import com.example.smsfraud.admin.dto.AlertResponse;
import com.example.smsfraud.admin.dto.AdminSmsResponse;
import com.example.smsfraud.admin.dto.BlockSenderRequest;
import com.example.smsfraud.admin.dto.CreateUserRequest;
import com.example.smsfraud.admin.dto.FraudTrendPoint;
import com.example.smsfraud.admin.dto.ResetUserPasswordRequest;
import com.example.smsfraud.admin.dto.UpdateRoleRequest;
import com.example.smsfraud.admin.dto.UpdateUserRequest;
import com.example.smsfraud.sender.BlockedSender;
import com.example.smsfraud.common.dto.ApiResponse;
import com.example.smsfraud.user.UserRepository;
import com.example.smsfraud.user.dto.UserResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.data.domain.Page;

import java.util.List;
import java.util.UUID;

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

    @GetMapping("/marked-fraud")
    public ResponseEntity<ApiResponse<Page<AdminSmsResponse>>> getMarkedFraud(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return ResponseEntity.ok(ApiResponse.ok(
                "User-reported fraud retrieved", adminService.getUserReportedFraud(page, size)));
    }

    @GetMapping("/users")
    public ResponseEntity<ApiResponse<List<UserResponse>>> listUsers() {
        // Return both administrators and mobile users. The portal separates them by role.
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

    @PatchMapping("/users/{userId}/role")
    public ResponseEntity<ApiResponse<UserResponse>> updateUserRole(
            @PathVariable UUID userId,
            @Valid @RequestBody UpdateRoleRequest req,
            Authentication authentication) {
        UUID actorId = UUID.fromString(authentication.getName());
        UserResponse updated = adminService.updateUserRole(userId, req.role(), actorId);
        return ResponseEntity.ok(ApiResponse.ok("Role updated", updated));
    }

    @PostMapping("/users")
    public ResponseEntity<ApiResponse<UserResponse>> createUser(@Valid @RequestBody CreateUserRequest req) {
        UserResponse created = adminService.createUser(req);
        return ResponseEntity.status(HttpStatus.CREATED).body(ApiResponse.ok("User created", created));
    }

    @PutMapping("/users/{userId}")
    public ResponseEntity<ApiResponse<UserResponse>> updateUser(
            @PathVariable UUID userId,
            @Valid @RequestBody UpdateUserRequest req,
            Authentication authentication) {
        UUID actorId = UUID.fromString(authentication.getName());
        UserResponse updated = adminService.updateUser(userId, req, actorId);
        return ResponseEntity.ok(ApiResponse.ok("User updated", updated));
    }

    @PatchMapping("/users/{userId}/password")
    public ResponseEntity<ApiResponse<Void>> resetUserPassword(
            @PathVariable UUID userId,
            @Valid @RequestBody ResetUserPasswordRequest req,
            Authentication authentication) {
        UUID actorId = UUID.fromString(authentication.getName());
        adminService.resetUserPassword(userId, req.password(), actorId);
        return ResponseEntity.ok(ApiResponse.ok("Password reset successfully"));
    }

    @DeleteMapping("/users/{userId}")
    public ResponseEntity<ApiResponse<Void>> deleteUser(
            @PathVariable UUID userId,
            Authentication authentication) {
        UUID actorId = UUID.fromString(authentication.getName());
        adminService.deleteUser(userId, actorId);
        return ResponseEntity.ok(ApiResponse.ok("User deleted successfully"));
    }
}
