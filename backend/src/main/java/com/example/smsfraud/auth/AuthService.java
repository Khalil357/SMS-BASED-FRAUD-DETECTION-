package com.example.smsfraud.auth;

import com.example.smsfraud.auth.dto.ForgotPasswordRequest;
import com.example.smsfraud.auth.dto.LoginRequest;
import com.example.smsfraud.auth.dto.ResetPasswordRequest;
import com.example.smsfraud.auth.dto.SignupRequest;
import com.example.smsfraud.auth.dto.VerifyCodeRequest;
import com.example.smsfraud.entity.User;
import com.example.smsfraud.entity.UserRole;
import com.example.smsfraud.repository.UserRepository;
import com.example.smsfraud.repository.UserRoleRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.mail.javamail.MimeMessageHelper;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import jakarta.mail.internet.MimeMessage;
import java.security.SecureRandom;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Self-contained auth logic aligned to the frontend contract in
 * frontend/lib/services/auth_service.dart (6 endpoints under /api/auth).
 *
 * OTPs are stored in-memory (per phone number) and delivered by email as a
 * best-effort; the code is also returned in the response so the flow can be
 * exercised without a configured SMTP server. Replace the in-memory store with
 * Redis or the otp_codes table for production.
 */
@Service
public class AuthService {

    private final UserRepository userRepository;
    private final UserRoleRepository userRoleRepository;
    private final PasswordEncoder passwordEncoder;
    private final JavaMailSender mailSender;
    private final JwtUtil jwtUtil;

    @Value("${email.from}")
    private String fromEmail;

    @Value("${app.name:SMS Fraud Detection}")
    private String appName;

    private static final Duration OTP_TTL = Duration.ofMinutes(5);
    private static final SecureRandom SECURE_RANDOM = new SecureRandom();
    private final Map<String, OtpEntry> otpStore = new ConcurrentHashMap<>();

    public AuthService(UserRepository userRepository,
                       UserRoleRepository userRoleRepository,
                       PasswordEncoder passwordEncoder,
                       JavaMailSender mailSender,
                       JwtUtil jwtUtil) {
        this.userRepository = userRepository;
        this.userRoleRepository = userRoleRepository;
        this.passwordEncoder = passwordEncoder;
        this.mailSender = mailSender;
        this.jwtUtil = jwtUtil;
    }

    private record OtpEntry(String code, Instant expiresAt) {}

    // ---- 1. POST /api/auth/signup --------------------------------------
    public Map<String, Object> register(SignupRequest req) {
        if (userRepository.existsByEmail(req.email())) {
            throw new AuthException("Email already registered", 409);
        }
        if (userRepository.existsByPhone(req.phoneNumber())) {
            throw new AuthException("Phone number already registered", 409);
        }
        UserRole role = userRoleRepository.findByRoleName("USER")
                .orElseThrow(() -> new AuthException("USER role is not configured", 500));

        User user = new User();
        user.setFullName(req.fullName());
        user.setEmail(req.email());
        user.setPhone(req.phoneNumber());
        user.setGender(req.gender());
        user.setPasswordHash(passwordEncoder.encode(req.password()));
        user.setRole(role);
        user.setVerified(false);
        user.setActive(true);
        userRepository.save(user);

        String otp = issueOtp(user.getPhone());
        sendOtpEmail(user, otp);

        Map<String, Object> data = new HashMap<>();
        data.put("user_id", user.getUserId());
        data.put("otp", otp); // dev convenience; remove before production
        return data;
    }

    // ---- 2. POST /api/auth/login ----------------------------------------
    public Map<String, Object> login(LoginRequest req) {
        User user = userRepository.findByPhone(req.phoneNumber())
                .orElseThrow(() -> new AuthException("Invalid phone number or password", 401));
        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            throw new AuthException("Invalid phone number or password", 401);
        }
        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        String token = jwtUtil.generateToken(user.getUserId());
        Map<String, Object> data = new HashMap<>();
        data.put("token", token);
        data.put("user_id", user.getUserId());
        data.put("full_name", user.getFullName());
        data.put("email", user.getEmail());
        data.put("phone_number", user.getPhone());
        return data;
    }

    // ---- 3. POST /api/auth/forgot-password ------------------------------
    public Map<String, Object> forgotPassword(ForgotPasswordRequest req) {
        User user = userRepository.findByPhone(req.phoneNumber())
                .orElseThrow(() -> new AuthException("No account found for that phone number", 404));
        String otp = issueOtp(user.getPhone());
        sendOtpEmail(user, otp);

        Map<String, Object> data = new HashMap<>();
        data.put("otp", otp); // dev convenience
        return data;
    }

    // ---- 4. POST /api/auth/verify-code ----------------------------------
    public Map<String, Object> verifyCode(VerifyCodeRequest req) {
        if (!isOtpValid(req.phoneNumber(), req.verificationCode())) {
            throw new AuthException("Invalid or expired verification code", 400);
        }
        otpStore.remove(req.phoneNumber());
        userRepository.findByPhone(req.phoneNumber())
                .ifPresent(user -> {
                    user.setVerified(true);
                    userRepository.save(user);
                });
        return new HashMap<>();
    }

    // ---- 5. POST /api/auth/resend-code ----------------------------------
    public Map<String, Object> resendCode(ForgotPasswordRequest req) {
        User user = userRepository.findByPhone(req.phoneNumber())
                .orElseThrow(() -> new AuthException("No account found for that phone number", 404));
        String otp = issueOtp(user.getPhone());
        sendOtpEmail(user, otp);

        Map<String, Object> data = new HashMap<>();
        data.put("otp", otp); // dev convenience
        return data;
    }

    // ---- 6. POST /api/auth/reset-password -------------------------------
    public Map<String, Object> resetPassword(ResetPasswordRequest req) {
        if (!isOtpValid(req.phoneNumber(), req.verificationCode())) {
            throw new AuthException("Invalid or expired verification code", 400);
        }
        User user = userRepository.findByPhone(req.phoneNumber())
                .orElseThrow(() -> new AuthException("No account found for that phone number", 404));
        user.setPasswordHash(passwordEncoder.encode(req.newPassword()));
        userRepository.save(user);
        otpStore.remove(req.phoneNumber());
        return new HashMap<>();
    }

    // ---- Helpers ---------------------------------------------------------
    private boolean isOtpValid(String phone, String code) {
        OtpEntry entry = otpStore.get(phone);
        return entry != null
                && entry.expiresAt().isAfter(Instant.now())
                && entry.code().equals(code);
    }

    private String issueOtp(String phone) {
        String code = String.format("%06d", SECURE_RANDOM.nextInt(1_000_000));
        otpStore.put(phone, new OtpEntry(code, Instant.now().plus(OTP_TTL)));
        return code;
    }

    private void sendOtpEmail(User user, String otp) {
        try {
            MimeMessage message = mailSender.createMimeMessage();
            MimeMessageHelper helper = new MimeMessageHelper(message, "UTF-8");
            helper.setFrom(fromEmail);
            helper.setTo(user.getEmail());
            helper.setSubject("🔐 " + appName + " - Verification Code");
            helper.setText("Your verification code is " + otp
                    + ". It expires in " + OTP_TTL.toMinutes() + " minutes.", false);
            mailSender.send(message);
        } catch (Exception e) {
            // Best-effort: SMTP may not be configured during development. The
            // OTP is also returned in the API response for this reason.
            System.out.println("[MAIL] Could not email " + user.getEmail() + ": " + e.getMessage());
        }
    }

    public static class AuthException extends RuntimeException {
        public final int status;

        public AuthException(String message, int status) {
            super(message);
            this.status = status;
        }
    }
}
