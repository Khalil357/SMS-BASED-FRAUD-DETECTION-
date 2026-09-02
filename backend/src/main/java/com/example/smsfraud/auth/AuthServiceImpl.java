package com.example.smsfraud.auth;

import com.example.smsfraud.auth.dto.LoginRequest;
import com.example.smsfraud.auth.dto.LoginResponse;
import com.example.smsfraud.auth.dto.OtpRequest;
import com.example.smsfraud.auth.dto.OtpResponse;
import com.example.smsfraud.auth.dto.ResetPasswordRequest;
import com.example.smsfraud.auth.dto.RegisterRequest;
import com.example.smsfraud.auth.dto.RegisterResponse;
import com.example.smsfraud.auth.dto.VerifyCodeRequest;
import com.example.smsfraud.common.exception.BadRequestException;
import com.example.smsfraud.common.exception.ConflictException;
import com.example.smsfraud.common.exception.ForbiddenException;
import com.example.smsfraud.common.exception.NotFoundException;
import com.example.smsfraud.common.exception.UnauthorizedException;
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
        smsService.sendSms(user.getPhone(), "Your Secure Signal verification code is " + otp + ".");

        return new RegisterResponse(user.getUserId(), otp);
    }

    @Override
    public LoginResponse login(LoginRequest req) {
        User user = userRepository.findByPhone(req.phoneNumber())
                .orElseGet(() -> userRepository.findByEmail(req.phoneNumber())
                .orElseThrow(() -> new UnauthorizedException("Invalid phone number/email or password")));
        if (!passwordEncoder.matches(req.password(), user.getPasswordHash())) {
            throw new UnauthorizedException("Invalid phone number/email or password");
        }
        if (!user.isActive()) {
            throw new ForbiddenException("Account is deactivated");
        }
        if (user.isLocked()) {
            throw new ForbiddenException("Account is locked");
        }
        if (!user.isVerified()) {
            throw new ForbiddenException("Email not verified. Please verify your email before logging in.");
        }
        user.setLastLoginAt(Instant.now());
        userRepository.save(user);

        String token = tokenProvider.generateToken(user.getUserId());
        return new LoginResponse(token, user.getUserId(), user.getFullName(), user.getEmail(), user.getPhone());
    }

    @Override
    public OtpResponse requestPasswordReset(OtpRequest req) {
        User user = userRepository.findByPhone(req.phoneNumber())
                .orElseGet(() -> userRepository.findByEmail(req.phoneNumber())
                .orElseThrow(() -> new NotFoundException("No account found for that phone number or email")));
        String otp = otpService.issueCode(user.getPhone());
        emailService.sendVerificationCode(user.getEmail(), otp);
        smsService.sendSms(user.getPhone(), "Your Secure Signal password reset code is " + otp + ".");
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
        userRepository.save(user);
        otpService.invalidate(req.phoneNumber());
    }
}
