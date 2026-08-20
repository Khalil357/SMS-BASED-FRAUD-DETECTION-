package com.example.smsfraud.config;

import com.example.smsfraud.dto.request.*;
import com.example.smsfraud.dto.response.AuthResponse;
import com.example.smsfraud.dto.response.UserInfo;
import com.example.smsfraud.entity.User;
import com.example.smsfraud.entity.UserRole;
import com.example.smsfraud.exception.*;
import com.example.smsfraud.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;

/**
 * 🛡️ AuthService - Handles authentication logic
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class AuthService {

    // ===== Dependencies =====
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final OtpService otpService;
    private final EmailService emailService;
    private final RefreshTokenService refreshTokenService;
    private final AuditService auditService;
    private final PasswordPolicy passwordPolicy;
    private final HttpServletRequest request;

    // ============================================================
    // 1. REGISTER - 7 Exception Throws
    // ============================================================
    
    @Transactional
    public AuthResponse register(RegisterRequest request) {
        log.info("📝 Registration attempt for: {}", request.getEmail());

        // ============================================================
        // EXCEPTION 1: Passwords do not match
        // ============================================================
        if (!request.getPassword().equals(request.getConfirmPassword())) {
            auditService.logFailure(null, "REGISTER", request, "Passwords do not match");
            throw RegistrationException.passwordsDoNotMatch();
        }

        // ============================================================
        // EXCEPTION 2: Invalid email format
        // ============================================================
        if (!isValidEmail(request.getEmail())) {
            auditService.logFailure(null, "REGISTER", request, "Invalid email");
            throw RegistrationException.invalidEmail(request.getEmail());
        }

        // ============================================================
        // EXCEPTION 3: Invalid phone format
        // ============================================================
        if (!isValidPhone(request.getPhoneNumber())) {
            auditService.logFailure(null, "REGISTER", request, "Invalid phone");
            throw RegistrationException.invalidPhone(request.getPhoneNumber());
        }

        // ============================================================
        // EXCEPTION 4: Weak password
        // ============================================================
        if (!passwordPolicy.isValid(request.getPassword())) {
            PasswordPolicy.ValidationResult result = 
                passwordPolicy.validateWithDetails(request.getPassword());
            String errors = String.join(", ", result.getErrors());
            auditService.logFailure(null, "REGISTER", request, "Weak password: " + errors);
            throw RegistrationException.weakPassword(errors);
        }

        // ============================================================
        // EXCEPTION 5: Email already exists
        // ============================================================
        if (userRepository.existsByEmail(request.getEmail())) {
            auditService.logFailure(null, "REGISTER", request, "Email already exists");
            throw RegistrationException.emailAlreadyExists(request.getEmail());
        }

        // ============================================================
        // EXCEPTION 6: Phone already exists
        // ============================================================
        if (userRepository.existsByPhoneNumber(request.getPhoneNumber())) {
            auditService.logFailure(null, "REGISTER", request, "Phone already exists");
            throw RegistrationException.phoneAlreadyExists(request.getPhoneNumber());
        }

        // ============================================================
        // EXCEPTION 7: Terms not accepted
        // ============================================================
        if (request.getAcceptTerms() == null || !request.getAcceptTerms()) {
            auditService.logFailure(null, "REGISTER", request, "Terms not accepted");
            throw RegistrationException.termsNotAccepted();
        }

        // ✅ All business rules passed
        User user = User.builder()
            .name(request.getName())
            .email(request.getEmail())
            .phoneNumber(request.getPhoneNumber())
            .passwordHash(passwordEncoder.encode(request.getPassword()))
            .role(UserRole.USER)
            .isVerified(false)
            .isActive(true)
            .isLocked(false)
            .failedLoginAttempts(0)
            .refreshTokenVersion(0L)
            .loginMethod("email")
            .build();

        user = userRepository.save(user);
        log.info("✅ User registered: {}", user.getId());

        // ============================================================
        // ✅ FIX: Generate OTP using User object (email-based)
        // ============================================================
        try {
            String otp = otpService.generateOtp(user);  // ✅ Pass User object
            // OTP already sent by OtpService
        } catch (Exception e) {
            auditService.logFailure(user.getId(), "REGISTER", request, "OTP generation failed");
            throw OtpException.generationFailed(e.getMessage());
        }

        // Generate tokens
        String accessToken = jwtTokenProvider.generateAccessToken(user);
        String refreshToken = jwtTokenProvider.generateRefreshToken(user);
        String deviceId = request.getDeviceId();
        refreshTokenService.storeRefreshToken(user.getId(), deviceId, refreshToken);

        auditService.logSuccess(user.getId(), "REGISTER", request, null);
        return buildAuthResponse(user, accessToken, refreshToken);
    }

    // ============================================================
    // 2. LOGIN - 6 Exception Throws
    // ============================================================
    
    @Transactional
    public AuthResponse login(LoginRequest request) {
        log.info("🔐 Login attempt for: {}", request.getEmail());

        // ============================================================
        // EXCEPTION 9: User not found
        // ============================================================
        User user = userRepository.findByEmail(request.getEmail())
            .orElseThrow(() -> {
                auditService.logFailure(null, "LOGIN", request, "User not found");
                return LoginException.userNotFound(request.getEmail());
            });

        // ============================================================
        // EXCEPTION 10: Account locked
        // ============================================================
        if (user.getIsLocked()) {
            auditService.logFailure(user.getId(), "LOGIN", request, "Account locked");
            throw LockedAccountException.unlockInstructions(user.getEmail());
        }

        // ============================================================
        // EXCEPTION 11: Account disabled
        // ============================================================
        if (!user.getIsActive()) {
            auditService.logFailure(user.getId(), "LOGIN", request, "Account disabled");
            throw LoginException.accountDisabled();
        }

        // ============================================================
        // EXCEPTION 12: Invalid credentials (wrong password)
        // ============================================================
        if (!passwordEncoder.matches(request.getPassword(), user.getPasswordHash())) {
            user.setFailedLoginAttempts(user.getFailedLoginAttempts() + 1);
            
            // ============================================================
            // EXCEPTION 13: Too many attempts → Account locked
            // ============================================================
            if (user.getFailedLoginAttempts() >= 5) {
                user.setIsLocked(true);
                user.setLockedAt(LocalDateTime.now());
                userRepository.save(user);
                emailService.sendAccountLockedEmail(user);
                auditService.logFailure(user.getId(), "LOGIN", request, 
                    "Account locked after 5 failed attempts");
                throw LockedAccountException.tooManyAttempts(5, 5);
            }
            
            userRepository.save(user);
            auditService.logFailure(user.getId(), "LOGIN", request, "Invalid password");
            throw LoginException.invalidCredentials();
        }

        // ============================================================
        // EXCEPTION 14: Account not verified
        // ============================================================
        if (!user.getIsVerified()) {
            // ✅ FIX: Use email-based OTP generation
            String otp = otpService.generateOtp(user);  // ✅ Pass User object
            // OTP already sent by OtpService
            auditService.logFailure(user.getId(), "LOGIN", request, "User not verified - OTP sent");
            throw LoginException.accountNotVerified();
        }

        // ✅ All business rules passed
        user.setFailedLoginAttempts(0);
        user.setLastLoginAt(LocalDateTime.now());
        user = userRepository.save(user);

        String accessToken = jwtTokenProvider.generateAccessToken(user);
        String refreshToken = jwtTokenProvider.generateRefreshToken(user);
        String deviceId = request.getDeviceId();
        refreshTokenService.storeRefreshToken(user.getId(), deviceId, refreshToken);

        auditService.logSuccess(user.getId(), "LOGIN", request, null);
        return buildAuthResponse(user, accessToken, refreshToken);
    }

    // ============================================================
    // 3. OTP VERIFICATION - 5 Exception Throws
    // ============================================================
    
    @Transactional
    public AuthResponse verifyOtp(OtpRequest request) {
        log.info("✅ OTP verification for email: {}", request.getEmail());

        // ============================================================
        // EXCEPTION 15: User not found (by email)
        // ============================================================
        User user = userRepository.findByEmail(request.getEmail())
            .orElseThrow(() -> {
                auditService.logFailure(null, "OTP_VERIFY", request, "User not found");
                return UserNotFoundException.withEmail(request.getEmail());
            });

        // ============================================================
        // EXCEPTION 16: Already verified
        // ============================================================
        if (user.getIsVerified()) {
            auditService.logFailure(user.getId(), "OTP_VERIFY", request, "Already verified");
            throw OtpException.alreadyVerified();
        }

        // ============================================================
        // ✅ FIX: Use email-based OTP validation
        // ============================================================
        // EXCEPTION 17: Too many OTP attempts
        if (!otpService.canAttemptOtp(user.getEmail())) {  // ✅ Use email
            auditService.logFailure(user.getId(), "OTP_VERIFY", request, "Too many attempts");
            throw OtpException.tooManyAttempts();
        }

        // ============================================================
        // EXCEPTION 18: Invalid OTP
        // ============================================================
        boolean isValid = otpService.validateOtp(user.getEmail(), request.getOtp());  // ✅ Use email
        
        if (!isValid) {
            int remaining = otpService.getRemainingAttempts(user.getEmail());  // ✅ Use email
            auditService.logFailure(user.getId(), "OTP_VERIFY", request, "Invalid OTP");
            
            // ============================================================
            // EXCEPTION 19: Too many attempts (triggered by invalid OTP)
            // ============================================================
            if (remaining == 0) {
                throw OtpException.tooManyAttempts();
            }
            
            throw OtpException.invalidOtp(remaining);
        }

        // ✅ All business rules passed
        user.setVerified(true);
        user = userRepository.save(user);
        log.info("✅ User verified: {}", user.getEmail());

        emailService.sendWelcomeEmail(user);

        String accessToken = jwtTokenProvider.generateAccessToken(user);
        String refreshToken = jwtTokenProvider.generateRefreshToken(user);
        String deviceId = request.getDeviceId();
        refreshTokenService.storeRefreshToken(user.getId(), deviceId, refreshToken);

        auditService.logSuccess(user.getId(), "OTP_VERIFY", request, null);
        return buildAuthResponse(user, accessToken, refreshToken);
    }

    // ============================================================
    // 4. FORGOT PASSWORD - 2 Exception Throws
    // ============================================================
    
    @Transactional
    public void forgotPassword(ForgotPasswordRequest request) {
        log.info("🔑 Password reset requested for: {}", request.getEmail());

        // ============================================================
        // EXCEPTION 20: User not found
        // ============================================================
        User user = userRepository.findByEmail(request.getEmail())
            .orElseThrow(() -> {
                auditService.logFailure(null, "PASSWORD_RESET_REQUEST", request, "User not found");
                return UserNotFoundException.withEmail(request.getEmail());
            });

        // ============================================================
        // EXCEPTION 21: Account disabled
        // ============================================================
        if (!user.getIsActive()) {
            auditService.logFailure(user.getId(), "PASSWORD_RESET_REQUEST", request, "Account disabled");
            throw LoginException.accountDisabled();
        }

        // ✅ FIX: Generate OTP using email
        String otp = otpService.generateOtp(user);  // ✅ Pass User object
        // OTP already sent by OtpService

        auditService.logSuccess(user.getId(), "PASSWORD_RESET_REQUEST", request, null);
    }

    // ============================================================
    // 5. RESET PASSWORD - 7 Exception Throws
    // ============================================================
    
    @Transactional
    public void resetPassword(ResetPasswordRequest request) {
        log.info("🔑 Password reset attempt for: {}", request.getEmail());

        // ============================================================
        // EXCEPTION 22: Passwords do not match
        // ============================================================
        if (!request.getNewPassword().equals(request.getConfirmPassword())) {
            auditService.logFailure(null, "PASSWORD_RESET", request, "Passwords do not match");
            throw RegistrationException.passwordsDoNotMatch();
        }

        // ============================================================
        // EXCEPTION 23: Password too short
        // ============================================================
        if (request.getNewPassword().length() < 8) {
            auditService.logFailure(null, "PASSWORD_RESET", request, "Password too short");
            throw PasswordPolicyException.tooShort();
        }

        // ============================================================
        // EXCEPTION 24: No uppercase
        // ============================================================
        if (!request.getNewPassword().matches(".*[A-Z].*")) {
            auditService.logFailure(null, "PASSWORD_RESET", request, "No uppercase");
            throw PasswordPolicyException.noUppercase();
        }

        // ============================================================
        // EXCEPTION 25: No lowercase
        // ============================================================
        if (!request.getNewPassword().matches(".*[a-z].*")) {
            auditService.logFailure(null, "PASSWORD_RESET", request, "No lowercase");
            throw PasswordPolicyException.noLowercase();
        }

        // ============================================================
        // EXCEPTION 26: No digit
        // ============================================================
        if (!request.getNewPassword().matches(".*\\d.*")) {
            auditService.logFailure(null, "PASSWORD_RESET", request, "No digit");
            throw PasswordPolicyException.noDigit();
        }

        // ============================================================
        // EXCEPTION 27: No special character
        // ============================================================
        if (!request.getNewPassword().matches(".*[@$!%*?&].*")) {
            auditService.logFailure(null, "PASSWORD_RESET", request, "No special char");
            throw PasswordPolicyException.noSpecial();
        }

        // ============================================================
        // EXCEPTION 28: Password too common
        // ============================================================
        if (isCommonPassword(request.getNewPassword())) {
            auditService.logFailure(null, "PASSWORD_RESET", request, "Password too common");
            throw PasswordPolicyException.tooCommon();
        }

        // ============================================================
        // EXCEPTION 29: User not found
        // ============================================================
        User user = userRepository.findByEmail(request.getEmail())
            .orElseThrow(() -> {
                auditService.logFailure(null, "PASSWORD_RESET", request, "User not found");
                return UserNotFoundException.withEmail(request.getEmail());
            });

        // ============================================================
        // ✅ FIX: Use email-based OTP validation
        // ============================================================
        // EXCEPTION 30: Too many attempts
        if (!otpService.canAttemptOtp(user.getEmail())) {  // ✅ Use email
            auditService.logFailure(user.getId(), "PASSWORD_RESET", request, "Too many attempts");
            throw OtpException.tooManyAttempts();
        }

        // ============================================================
        // EXCEPTION 31: Invalid OTP
        // ============================================================
        boolean isValid = otpService.validateOtp(user.getEmail(), request.getOtp());  // ✅ Use email
        
        if (!isValid) {
            int remaining = otpService.getRemainingAttempts(user.getEmail());  // ✅ Use email
            auditService.logFailure(user.getId(), "PASSWORD_RESET", request, "Invalid OTP");
            
            // ============================================================
            // EXCEPTION 32: Too many attempts (triggered by invalid OTP)
            // ============================================================
            if (remaining == 0) {
                throw OtpException.tooManyAttempts();
            }
            
            throw OtpException.invalidOtp(remaining);
        }

        // ✅ All business rules passed
        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        user.setRefreshTokenVersion(user.getRefreshTokenVersion() + 1);
        user.setFailedLoginAttempts(0);
        user.setIsLocked(false);
        user.setLockedAt(null);
        user = userRepository.save(user);

        refreshTokenService.deleteAllRefreshTokens(user.getId());

        auditService.logSuccess(user.getId(), "PASSWORD_RESET", request, null);
        log.info("✅ Password reset successful for: {}", user.getEmail());
    }

    // ============================================================
    // 6. REFRESH TOKEN - 4 Exception Throws
    // ============================================================
    
    @Transactional
    public AuthResponse refreshToken(RefreshTokenRequest request) {
        log.info("🔄 Token refresh requested");

        // ============================================================
        // EXCEPTION 33: Invalid refresh token
        // ============================================================
        String userId;
        try {
            userId = jwtTokenProvider.extractUserId(request.getRefreshToken());
        } catch (Exception e) {
            auditService.logFailure(null, "TOKEN_REFRESH", request, "Invalid refresh token");
            throw RefreshTokenException.invalidToken();
        }

        // ============================================================
        // EXCEPTION 34: User not found
        // ============================================================
        User user = userRepository.findById(userId)
            .orElseThrow(() -> {
                auditService.logFailure(null, "TOKEN_REFRESH", request, "User not found");
                return UserNotFoundException.withId(userId);
            });

        // ============================================================
        // EXCEPTION 35: Refresh token expired
        // ============================================================
        boolean isValid = refreshTokenService.validateRefreshToken(
            userId, request.getDeviceId(), request.getRefreshToken()
        );
        
        if (!isValid) {
            auditService.logFailure(userId, "TOKEN_REFRESH", request, "Invalid refresh token");
            throw RefreshTokenException.expiredToken();
        }

        // ============================================================
        // EXCEPTION 36: Token version mismatch (password reset)
        // ============================================================
        Long tokenVersion = jwtTokenProvider.extractTokenVersion(request.getRefreshToken());
        if (!tokenVersion.equals(user.getRefreshTokenVersion())) {
            refreshTokenService.deleteAllRefreshTokens(userId);
            auditService.logFailure(userId, "TOKEN_REFRESH", request, "Token version mismatch");
            throw RefreshTokenException.tokenRevoked();
        }

        // ✅ All business rules passed
        String newAccessToken = jwtTokenProvider.generateAccessToken(user);

        auditService.logSuccess(userId, "TOKEN_REFRESH", request, null);

        return AuthResponse.builder()
            .accessToken(newAccessToken)
            .refreshToken(request.getRefreshToken())
            .tokenType("Bearer")
            .expiresIn(900L)
            .userInfo(mapToUserInfo(user))
            .build();
    }

    // ============================================================
    // 7. LOGOUT - 2 Exception Throws
    // ============================================================
    
    @Transactional
    public void logout(LogoutRequest request) {
        log.info("🚪 Logout requested");

        // ============================================================
        // EXCEPTION 37: Cannot extract userId from token
        // ============================================================
        String userId;
        try {
            userId = jwtTokenProvider.extractUserId(request.getRefreshToken());
        } catch (Exception e) {
            auditService.logFailure(null, "LOGOUT", request, "Invalid token");
            throw TokenException.invalidToken();
        }

        // ============================================================
        // EXCEPTION 38: User not found
        // ============================================================
        User user = userRepository.findById(userId)
            .orElseThrow(() -> {
                auditService.logFailure(null, "LOGOUT", request, "User not found");
                return UserNotFoundException.withId(userId);
            });

        // ============================================================
        // EXCEPTION 39: Account disabled
        // ============================================================
        if (!user.getIsActive()) {
            auditService.logFailure(userId, "LOGOUT", request, "User inactive");
            throw LoginException.accountDisabled();
        }

        // ✅ All business rules passed
        refreshTokenService.deleteRefreshToken(userId, request.getDeviceId());

        auditService.logSuccess(userId, "LOGOUT", request, null);
    }

    // ============================================================
    // 8. CHANGE PASSWORD - 4 Exception Throws
    // ============================================================
    
    @Transactional
    public void changePassword(String userId, ChangePasswordRequest request) {
        log.info("🔑 Password change requested for: {}", userId);

        // ============================================================
        // EXCEPTION 40: User not found
        // ============================================================
        User user = userRepository.findById(userId)
            .orElseThrow(() -> {
                auditService.logFailure(null, "PASSWORD_CHANGE", request, "User not found");
                return UserNotFoundException.withId(userId);
            });

        // ============================================================
        // EXCEPTION 41: Current password incorrect
        // ============================================================
        if (!passwordEncoder.matches(request.getCurrentPassword(), user.getPasswordHash())) {
            auditService.logFailure(userId, "PASSWORD_CHANGE", request, "Invalid current password");
            throw LoginException.invalidCredentials();
        }

        // ============================================================
        // EXCEPTION 42: New passwords do not match
        // ============================================================
        if (!request.getNewPassword().equals(request.getConfirmNewPassword())) {
            auditService.logFailure(userId, "PASSWORD_CHANGE", request, "Passwords do not match");
            throw RegistrationException.passwordsDoNotMatch();
        }

        // ============================================================
        // EXCEPTION 43: New password is weak
        // ============================================================
        if (!passwordPolicy.isValid(request.getNewPassword())) {
            PasswordPolicy.ValidationResult result = 
                passwordPolicy.validateWithDetails(request.getNewPassword());
            String errors = String.join(", ", result.getErrors());
            auditService.logFailure(userId, "PASSWORD_CHANGE", request, "Weak password: " + errors);
            throw RegistrationException.weakPassword(errors);
        }

        // ✅ All business rules passed
        user.setPasswordHash(passwordEncoder.encode(request.getNewPassword()));
        user.setRefreshTokenVersion(user.getRefreshTokenVersion() + 1);
        userRepository.save(user);

        refreshTokenService.deleteAllRefreshTokens(userId);

        auditService.logSuccess(userId, "PASSWORD_CHANGE", request, null);
        log.info("✅ Password changed for: {}", user.getEmail());
    }

    // ============================================================
    // 9. RESEND OTP - 2 Exception Throws
    // ============================================================
    
    @Transactional
    public void resendOtp(String email) {
        log.info("📧 Resend OTP requested for: {}", email);

        // ============================================================
        // EXCEPTION 44: User not found
        // ============================================================
        User user = userRepository.findByEmail(email)
            .orElseThrow(() -> {
                auditService.logFailure(null, "RESEND_OTP", null, "User not found");
                return UserNotFoundException.withEmail(email);
            });

        // ============================================================
        // EXCEPTION 45: Already verified
        // ============================================================
        if (user.getIsVerified()) {
            auditService.logFailure(user.getId(), "RESEND_OTP", null, "Already verified");
            throw OtpException.alreadyVerified();
        }

        // ============================================================
        // ✅ FIX: Use email-based OTP request check
        // ============================================================
        // EXCEPTION 46: Too many OTP attempts
        if (!otpService.canRequestOtp(user.getEmail())) {  // ✅ Use email
            auditService.logFailure(user.getId(), "RESEND_OTP", null, "Too many attempts");
            throw OtpException.tooManyAttempts();
        }

        // ✅ FIX: Generate OTP using user object
        String otp = otpService.generateOtp(user);  // ✅ Pass User object
        // OTP already sent by OtpService

        auditService.logSuccess(user.getId(), "RESEND_OTP", null, null);
        log.info("📧 OTP resent to: {}", email);
    }

    // ============================================================
    // HELPERS
    // ============================================================
    
    private AuthResponse buildAuthResponse(User user, String accessToken, String refreshToken) {
        return AuthResponse.builder()
            .accessToken(accessToken)
            .refreshToken(refreshToken)
            .tokenType("Bearer")
            .expiresIn(900L)
            .userInfo(mapToUserInfo(user))
            .build();
    }

    private UserInfo mapToUserInfo(User user) {
        return UserInfo.builder()
            .id(user.getId())
            .name(user.getName())
            .email(user.getEmail())
            .phoneNumber(user.getPhoneNumber())
            .role(user.getRole().name())
            .isVerified(user.getIsVerified())
            .isActive(user.getIsActive())
            .isLocked(user.getIsLocked())
            .lastLoginAt(user.getLastLoginAt())
            .createdAt(user.getCreatedAt())
            .build();
    }

    private boolean isValidEmail(String email) {
        return email != null && email.matches("^[A-Za-z0-9+_.-]+@(.+)$");
    }

    private boolean isValidPhone(String phone) {
        return phone != null && phone.matches("^\\+?[1-9][0-9]{7,14}$");
    }

    private boolean isCommonPassword(String password) {
        String[] common = {"password", "12345678", "qwerty", "admin", "welcome"};
        for (String p : common) {
            if (password.toLowerCase().equals(p)) {
                return true;
            }
        }
        return false;
    }
}