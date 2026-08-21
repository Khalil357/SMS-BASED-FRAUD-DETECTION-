package com.example.smsfraud.auth;

import com.example.smsfraud.auth.dto.ForgotPasswordRequest;
import com.example.smsfraud.auth.dto.LoginRequest;
import com.example.smsfraud.auth.dto.ResetPasswordRequest;
import com.example.smsfraud.auth.dto.SignupRequest;
import com.example.smsfraud.auth.dto.VerifyCodeRequest;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.HashMap;
import java.util.Map;

/**
 * Exposes the exact endpoints the Flutter frontend calls
 * (see frontend/lib/services/auth_service.dart).
 */
@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/signup")
    public ResponseEntity<Map<String, Object>> signup(@Valid @RequestBody SignupRequest req) {
        return respond(201, "Account created successfully", authService.register(req));
    }

    @PostMapping("/login")
    public ResponseEntity<Map<String, Object>> login(@Valid @RequestBody LoginRequest req) {
        return respond(200, "Login successful", authService.login(req));
    }

    @PostMapping("/forgot-password")
    public ResponseEntity<Map<String, Object>> forgotPassword(@Valid @RequestBody ForgotPasswordRequest req) {
        return respond(200, "Reset code sent successfully", authService.forgotPassword(req));
    }

    @PostMapping("/verify-code")
    public ResponseEntity<Map<String, Object>> verifyCode(@Valid @RequestBody VerifyCodeRequest req) {
        return respond(200, "Code verified successfully", authService.verifyCode(req));
    }

    @PostMapping("/resend-code")
    public ResponseEntity<Map<String, Object>> resendCode(@Valid @RequestBody ForgotPasswordRequest req) {
        return respond(200, "Code resent successfully", authService.resendCode(req));
    }

    @PostMapping("/reset-password")
    public ResponseEntity<Map<String, Object>> resetPassword(@Valid @RequestBody ResetPasswordRequest req) {
        return respond(200, "Password reset successfully", authService.resetPassword(req));
    }

    private ResponseEntity<Map<String, Object>> respond(int status, String message, Map<String, Object> data) {
        Map<String, Object> body = new HashMap<>();
        body.put("message", message);
        body.put("data", data == null ? Map.of() : data);
        if (data != null && data.containsKey("token")) {
            // The frontend reads data['token'] at the top level of the body.
            body.put("token", data.get("token"));
        }
        return ResponseEntity.status(status).body(body);
    }

    @ExceptionHandler(AuthService.AuthException.class)
    public ResponseEntity<Map<String, Object>> handleAuthException(AuthService.AuthException ex) {
        Map<String, Object> body = new HashMap<>();
        body.put("message", ex.getMessage());
        body.put("statusCode", ex.status);
        return ResponseEntity.status(ex.status).body(body);
    }
}
