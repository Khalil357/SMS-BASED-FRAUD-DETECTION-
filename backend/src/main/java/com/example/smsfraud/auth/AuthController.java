package com.example.smsfraud.auth;

import com.example.smsfraud.auth.dto.LoginRequest;
import com.example.smsfraud.auth.dto.LoginResponse;
import com.example.smsfraud.auth.dto.OtpRequest;
import com.example.smsfraud.auth.dto.OtpResponse;
import com.example.smsfraud.auth.dto.ResetPasswordRequest;
import com.example.smsfraud.auth.dto.SignupRequest;
import com.example.smsfraud.auth.dto.SignupResponse;
import com.example.smsfraud.auth.dto.VerifyCodeRequest;
import com.example.smsfraud.common.dto.ApiResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Exposes the auth endpoints the Flutter frontend calls (see
 * frontend/lib/services/auth_service.dart). Resource-based URLs; all responses
 * use the {@link ApiResponse} envelope.
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/register")
    public ResponseEntity<ApiResponse<SignupResponse>> register(@Valid @RequestBody SignupRequest req) {
        return ResponseEntity.status(HttpStatus.CREATED)
                .body(ApiResponse.ok("Account created successfully", authService.register(req)));
    }

    @PostMapping("/login")
    public ResponseEntity<ApiResponse<LoginResponse>> login(@Valid @RequestBody LoginRequest req) {
        return ResponseEntity.ok(ApiResponse.ok("Login successful", authService.login(req)));
    }

    @PostMapping("/password-resets")
    public ResponseEntity<ApiResponse<OtpResponse>> requestPasswordReset(@Valid @RequestBody OtpRequest req) {
        return ResponseEntity.ok(ApiResponse.ok("Reset code sent successfully", authService.requestPasswordReset(req)));
    }

    @PostMapping("/password-resets/resend")
    public ResponseEntity<ApiResponse<OtpResponse>> resendCode(@Valid @RequestBody OtpRequest req) {
        return ResponseEntity.ok(ApiResponse.ok("Code resent successfully", authService.resendCode(req)));
    }

    @PostMapping("/password-resets/verify")
    public ResponseEntity<ApiResponse<Void>> verifyCode(@Valid @RequestBody VerifyCodeRequest req) {
        authService.verifyCode(req);
        return ResponseEntity.ok(ApiResponse.ok("Code verified successfully"));
    }

    @PostMapping("/password-resets/confirm")
    public ResponseEntity<ApiResponse<Void>> resetPassword(@Valid @RequestBody ResetPasswordRequest req) {
        authService.resetPassword(req);
        return ResponseEntity.ok(ApiResponse.ok("Password reset successfully"));
    }
}
