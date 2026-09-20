package com.example.smsfraud.auth;

import com.example.smsfraud.auth.dto.LoginRequest;
import com.example.smsfraud.auth.dto.LoginPendingResponse;
import com.example.smsfraud.auth.dto.LoginResponse;
import com.example.smsfraud.auth.dto.OtpRequest;
import com.example.smsfraud.auth.dto.OtpResponse;
import com.example.smsfraud.auth.dto.ResetPasswordRequest;
import com.example.smsfraud.auth.dto.RegisterRequest;
import com.example.smsfraud.auth.dto.RegisterResponse;
import com.example.smsfraud.auth.dto.RefreshResponse;
import com.example.smsfraud.auth.dto.VerifyCodeRequest;
import com.example.smsfraud.common.exception.BadRequestException;
import com.example.smsfraud.common.exception.ConflictException;
import com.example.smsfraud.common.exception.ForbiddenException;
import com.example.smsfraud.common.exception.NotFoundException;
import com.example.smsfraud.common.exception.UnauthorizedException;
import com.example.smsfraud.common.security.TokenClaims;
import com.example.smsfraud.common.security.TokenProvider;
import com.example.smsfraud.email.EmailService;
import com.example.smsfraud.otp.OtpService;
import com.example.smsfraud.sms.SmsSenderService;
import com.example.smsfraud.user.User;
import com.example.smsfraud.user.UserRole;
import com.example.smsfraud.user.UserRepository;
import com.example.smsfraud.user.UserRoleRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import java.time.Instant;

/**
 * Auth orchestration: coordinates persistence, OTP, email, and token concerns.
 * Each of those is owned by its own service, so this class only encodes the
 * auth flow itself.
 */
@Service
public class AuthServiceImpl implements AuthService {

    private final UserRepository userRepository;
    private final UserRoleRepository userRoleRepository;
    private final PasswordEncoder passwordEncoder;
    private final OtpService otpService;
    private final EmailService emailService;
    private final SmsSenderService smsService;
    private final TokenProvider tokenProvider;

    public AuthServiceImpl(UserRepository userRepository,
                           UserRoleRepository userRoleRepository,
                           PasswordEncoder passwordEncoder,
                           OtpService otpService,
                           EmailService emailService,
                           SmsSenderService smsService,
                           TokenProvider tokenProvider) {
        this.userRepository = userRepository;
        this.userRoleRepository = userRoleRepository;
        this.passwordEncoder = passwordEncoder;
        this.otpService = otpService;
        this.emailService = emailService;
        this.smsService = smsService;
        this.tokenProvider = tokenProvider;
    }

    @Override
    public RegisterResponse register(RegisterRequest req) {
        if (userRepository.existsByEmail(req.email())) {
            throw new ConflictException("Email already registered");
        }
        if (userRepository.existsByPhone(req.phoneNumber())) {
            throw new ConflictException("Phone number already registered");
        }
        UserRole role = userRoleRepository.findByRoleName("USER")
                .orElseThrow(() -> new IllegalStateException("USER role is not configured"));

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

        String otp = otpService.issueCode(user.getPhone());
        emailService.sendVerificationCode(user.getEmail(), otp);
        smsService.sendSms(user.getPhone(), "ARGUS: Your verification code is " + otp + ". Do not share this code with anyone. It expires in 5 minutes.");

        return new RegisterResponse(user.getUserId(), otp);
    }

    @Override
    public LoginPendingResponse login(LoginRequest req) {
        User user;
        if (req.email() != null && !req.email().isBlank()) {
            user = userRepository.findByEmail(req.email())
                    .orElseThrow(() -> new UnauthorizedException("Invalid email or password"));
        } else {
            user = userRepository.findByPhone(req.phoneNumber())
                    .orElseThrow(() -> new UnauthorizedException("Invalid phone number or password"));
        }

        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            throw new UnauthorizedException("Invalid phone number or password");
        }
        if (!user.isActive()) {
            throw new ForbiddenException("Account is deactivated");
        }
        if (user.isLocked()) {
            throw new ForbiddenException("Account is locked");
        }
        // Unverified accounts proceed to the OTP step; entering the emailed code both
        // proves email ownership and (in verifyLoginOtp) marks the account verified.
        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        // Two-step login: credentials are valid, so issue one OTP and deliver it
        // through every configured channel. Delivery adapters safely log and skip
        // themselves when their provider credentials are not configured.
        // No token is returned here — the client must verify the OTP via
        // verifyLoginOtp() to receive the JWT.
        if (user.getEmail() != null && !user.getEmail().isBlank()) {
            String otp = otpService.issueCode(user.getEmail());
            emailService.sendVerificationCode(user.getEmail(), otp);
            if (user.getPhone() != null && !user.getPhone().isBlank()) {
                smsService.sendSms(user.getPhone(),
                        "ARGUS: Your login code is " + otp
                                + ". Do not share this code with anyone. It expires in 5 minutes.");
            }
        }

        return new LoginPendingResponse(user.getEmail(), "OTP sent; verify to complete login");
    }

    @Override
    public OtpResponse requestPasswordReset(OtpRequest req) {
        User user = userRepository.findByPhone(req.phoneNumber())
                .orElseThrow(() -> new NotFoundException("No account found for that phone number"));
        String otp = otpService.issueCode(user.getPhone());
        emailService.sendVerificationCode(user.getEmail(), otp);
        smsService.sendSms(user.getPhone(), "ARGUS: Your password reset code is " + otp + ". Do not share this code with anyone. It expires in 5 minutes.");
        return new OtpResponse(otp);
    }

    @Override
    public OtpResponse resendCode(OtpRequest req) {
        return requestPasswordReset(req);
    }

    @Override
    public void verifyCode(VerifyCodeRequest req) {
        if (!otpService.verifyCode(req.phoneNumber(), req.verificationCode())) {
            throw new BadRequestException("Invalid or expired verification code");
        }
        otpService.invalidate(req.phoneNumber());
        userRepository.findByPhone(req.phoneNumber())
                .ifPresent(user -> {
                    user.setVerified(true);
                    userRepository.save(user);
                });
    }

    @Override
    public void resetPassword(ResetPasswordRequest req) {
        if (!otpService.verifyCode(req.phoneNumber(), req.verificationCode())) {
            throw new BadRequestException("Invalid or expired verification code");
        }
        User user = userRepository.findByPhone(req.phoneNumber())
                .orElseThrow(() -> new NotFoundException("No account found for that phone number"));
        user.setPasswordHash(passwordEncoder.encode(req.newPassword()));
        user.setTokenVersion(user.getTokenVersion() + 1);
        user.setUpdatedAt(Instant.now());
        userRepository.save(user);
        otpService.invalidate(req.phoneNumber());
    }

    @Override
    public void resendLoginOtp(String email) {
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new NotFoundException("No account found for that email"));
        String otp = otpService.issueCode(user.getEmail());
        emailService.sendVerificationCode(user.getEmail(), otp);
        if (user.getPhone() != null && !user.getPhone().isBlank()) {
            smsService.sendSms(user.getPhone(),
                    "ARGUS: Your login code is " + otp
                            + ". Do not share this code with anyone. It expires in 5 minutes.");
        }
    }

    @Override
    public LoginResponse verifyLoginOtp(String email, String verificationCode) {
        if (!otpService.verifyCode(email, verificationCode)) {
            throw new BadRequestException("Invalid or expired verification code");
        }
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new NotFoundException("No account found for that email"));

        otpService.invalidate(email);
        user.setLastLoginAt(Instant.now());
        // The OTP was delivered to this email and matched, so the account is now
        // genuinely verified.
        user.setVerified(true);
        userRepository.save(user);

        String accessToken = tokenProvider.generateAccessToken(user.getUserId(), user.getTokenVersion());
        String refreshToken = tokenProvider.generateRefreshToken(user.getUserId(), user.getTokenVersion());
        return new LoginResponse(accessToken, refreshToken, user.getUserId(), user.getFullName(), user.getEmail(), user.getPhone());
    }

    @Override
    public RefreshResponse refresh(String refreshToken) {
        TokenClaims claims = tokenProvider.validateToken(refreshToken);
        if (!"refresh".equals(claims.type())) {
            throw new UnauthorizedException("Invalid refresh token");
        }
        User user = userRepository.findByIdWithRole(claims.userId())
                .orElseThrow(() -> new UnauthorizedException("Session is no longer valid"));
        if (!user.isActive() || user.isLocked()) {
            throw new UnauthorizedException("Account is disabled");
        }
        if (claims.tokenVersion() == null || claims.tokenVersion() != user.getTokenVersion()) {
            throw new UnauthorizedException("Session has been revoked");
        }
        String accessToken = tokenProvider.generateAccessToken(user.getUserId(), user.getTokenVersion());
        return new RefreshResponse(accessToken, refreshToken);
    }

    @Override
    public void logout(String refreshToken) {
        TokenClaims claims;
        try {
            claims = tokenProvider.validateToken(refreshToken);
        } catch (RuntimeException e) {
            return; // already invalid/expired — nothing to revoke
        }
        if (!"refresh".equals(claims.type())) {
            return;
        }
        userRepository.findById(claims.userId()).ifPresent(user -> {
            user.setTokenVersion(user.getTokenVersion() + 1);
            user.setUpdatedAt(Instant.now());
            userRepository.save(user);
        });
    }
}