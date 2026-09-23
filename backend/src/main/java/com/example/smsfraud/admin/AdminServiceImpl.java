package com.example.smsfraud.admin;

import com.example.smsfraud.admin.dto.AdminStatsResponse;
import com.example.smsfraud.admin.dto.AlertResponse;
import com.example.smsfraud.admin.dto.AdminSmsResponse;
import com.example.smsfraud.admin.dto.CreateUserRequest;
import com.example.smsfraud.admin.dto.FraudTrendPoint;
import com.example.smsfraud.admin.dto.UpdateUserRequest;
import com.example.smsfraud.common.exception.BadRequestException;
import com.example.smsfraud.common.exception.ConflictException;
import com.example.smsfraud.common.exception.NotFoundException;
import com.example.smsfraud.email.EmailService;
import com.example.smsfraud.sender.BlockedSender;
import com.example.smsfraud.sender.BlockedSenderRepository;
import com.example.smsfraud.scan.SmsScan;
import com.example.smsfraud.scan.SmsScanRepository;
import com.example.smsfraud.user.User;
import com.example.smsfraud.user.UserRepository;
import com.example.smsfraud.user.UserRole;
import com.example.smsfraud.user.UserRoleRepository;
import com.example.smsfraud.user.dto.UserResponse;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;

@Service
public class AdminServiceImpl implements AdminService {

    private final SmsScanRepository smsScanRepository;
    private final UserRepository userRepository;
    private final UserRoleRepository userRoleRepository;
    private final BlockedSenderRepository blockedSenderRepository;
    private final PasswordEncoder passwordEncoder;
    private final EmailService emailService;

    public AdminServiceImpl(SmsScanRepository smsScanRepository,
                            UserRepository userRepository,
                            UserRoleRepository userRoleRepository,
                            BlockedSenderRepository blockedSenderRepository,
                            PasswordEncoder passwordEncoder,
                            EmailService emailService) {
        this.smsScanRepository = smsScanRepository;
        this.userRepository = userRepository;
        this.userRoleRepository = userRoleRepository;
        this.blockedSenderRepository = blockedSenderRepository;
        this.passwordEncoder = passwordEncoder;
        this.emailService = emailService;
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
                scan.getScannedAt(),
                scan.getSource()
        ));
    }

    @Override
    public Page<AdminSmsResponse> getUserReportedFraud(int page, int size) {
        PageRequest pageRequest = PageRequest.of(page, size);
        Page<SmsScan> scans = smsScanRepository.findBySourceOrderByScannedAtDesc(
                "USER_REPORTED", pageRequest);

        return scans.map(scan -> new AdminSmsResponse(
                scan.getScanId(),
                scan.getSender() != null ? scan.getSender() : "Unknown",
                scan.getMessageBody(),
                scan.getVerdict(),
                scan.getConfidence() != null ? scan.getConfidence() : 0.0,
                scan.getScannedAt(),
                scan.getSource()
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

    @Override
    @Transactional
    public UserResponse updateUserRole(UUID userId, String role, UUID actorId) {
        String normalized = role == null ? "" : role.trim().toUpperCase();
        if (!"ADMIN".equals(normalized) && !"USER".equals(normalized)) {
            throw new BadRequestException("role must be either ADMIN or USER");
        }

        User target = userRepository.findByIdWithRole(userId)
                .orElseThrow(() -> new NotFoundException("User not found"));
        if (target.getUserId().equals(actorId)) {
            throw new BadRequestException("You cannot change your own role");
        }

        String currentRole = target.getRole().getRoleName();
        if (currentRole.equals(normalized)) {
            return UserResponse.from(target); // no-op
        }

        // Guard: never demote the last remaining active admin.
        if ("USER".equals(normalized) && "ADMIN".equals(currentRole) && target.isActive()) {
            if (userRepository.countActiveByRole("ADMIN") <= 1) {
                throw new BadRequestException("Cannot demote the last active admin");
            }
        }

        UserRole newRole = userRoleRepository.findByRoleName(normalized)
                .orElseThrow(() -> new IllegalStateException(normalized + " role is not configured"));
        target.setRole(newRole);
        // Bump the version so the user's existing access + refresh tokens are revoked
        // and they must re-authenticate with the new role.
        target.setTokenVersion(target.getTokenVersion() + 1);
        target.setUpdatedAt(Instant.now());
        userRepository.save(target);

        return UserResponse.from(target);
    }

    @Override
    @Transactional
    public UserResponse createUser(CreateUserRequest req) {
        String email = req.email().trim().toLowerCase();
        String phone = req.phoneNumber().trim();

        if (userRepository.existsByEmail(email)) {
            throw new ConflictException("A user with this email already exists");
        }
        if (userRepository.existsByPhone(phone)) {
            throw new ConflictException("A user with this phone number already exists");
        }

        // The admin portal only creates ADMIN accounts; regular USER accounts
        // self-register through the mobile app.
        UserRole role = userRoleRepository.findByRoleName("ADMIN")
                .orElseThrow(() -> new IllegalStateException("ADMIN role is not configured"));

        User user = new User();
        user.setFullName(req.fullName().trim());
        user.setEmail(email);
        user.setPhone(phone);
        user.setGender(req.gender() == null ? null : req.gender().name());
        user.setPasswordHash(passwordEncoder.encode(req.password()));
        user.setRole(role);
        // The admin sets the password, but the account is only "verified" once the
        // user actually proves they own this email (via the login OTP). A welcome
        // email below tells them they've been added.
        user.setVerified(false);
        user.setActive(true);
        user.setLocked(false);
        user.setFailedLoginAttempts(0);
        user.setTokenVersion(0);
        user.setCreatedAt(Instant.now());
        user.setUpdatedAt(Instant.now());
        userRepository.save(user);

        emailService.sendWelcomeEmail(email, user.getFullName(), "ADMIN");

        return UserResponse.from(user);
    }

    @Override
    @Transactional
    public UserResponse updateUser(UUID userId, UpdateUserRequest req, UUID actorId) {
        User target = userRepository.findByIdWithRole(userId)
                .orElseThrow(() -> new NotFoundException("User not found"));

        String email = req.email().trim().toLowerCase();
        String phone = req.phoneNumber().trim();

        if (userRepository.existsByEmail(email) && !target.getEmail().equalsIgnoreCase(email)) {
            throw new ConflictException("A user with this email already exists");
        }
        if (userRepository.existsByPhone(phone) && !target.getPhone().equals(phone)) {
            throw new ConflictException("A user with this phone number already exists");
        }

        // Guard: never deactivate the last remaining active admin.
        if (target.isActive() && !req.active() && "ADMIN".equals(target.getRole().getRoleName())) {
            if (userRepository.countActiveByRole("ADMIN") <= 1) {
                throw new BadRequestException("Cannot deactivate the last active admin");
            }
        }

        target.setFullName(req.fullName().trim());
        target.setEmail(email);
        target.setPhone(phone);
        target.setActive(req.active());
        target.setUpdatedAt(Instant.now());
        userRepository.save(target);

        emailService.sendAccountUpdatedEmail(email, target.getFullName());

        return UserResponse.from(target);
    }

    @Override
    @Transactional
    public void resetUserPassword(UUID userId, String newPassword, UUID actorId) {
        User target = userRepository.findByIdWithRole(userId)
                .orElseThrow(() -> new NotFoundException("User not found"));

        target.setPasswordHash(passwordEncoder.encode(newPassword));
        // Revoke existing sessions so the old credentials no longer work anywhere.
        target.setTokenVersion(target.getTokenVersion() + 1);
        target.setUpdatedAt(Instant.now());
        userRepository.save(target);
    }

    @Override
    @Transactional
    public void deleteUser(UUID userId, UUID actorId) {
        User target = userRepository.findByIdWithRole(userId)
                .orElseThrow(() -> new NotFoundException("User not found"));

        if (target.getUserId().equals(actorId)) {
            throw new BadRequestException("You cannot delete your own account");
        }

        // Guard: never delete the last remaining active admin.
        if ("ADMIN".equals(target.getRole().getRoleName()) && target.isActive()) {
            if (userRepository.countActiveByRole("ADMIN") <= 1) {
                throw new BadRequestException("Cannot delete the last active admin");
            }
        }

        userRepository.delete(target);
    }
}
