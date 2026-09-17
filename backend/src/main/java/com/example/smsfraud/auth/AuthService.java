package com.example.smsfraud.auth;

import com.example.smsfraud.auth.dto.LoginRequest;
import com.example.smsfraud.auth.dto.LoginResponse;
import com.example.smsfraud.auth.dto.OtpRequest;
import com.example.smsfraud.auth.dto.OtpResponse;
import com.example.smsfraud.auth.dto.ResetPasswordRequest;
import com.example.smsfraud.auth.dto.RegisterRequest;
import com.example.smsfraud.auth.dto.RegisterResponse;
import com.example.smsfraud.auth.dto.VerifyCodeRequest;

/**
 * Contract for the auth feature. Orchestration lives in the implementation;
 * OTP issuance/verification, email delivery, and token handling are delegated
 * to their own services.
 */
public interface AuthService {

    RegisterResponse register(RegisterRequest req);

    LoginResponse login(LoginRequest req);

    OtpResponse requestPasswordReset(OtpRequest req);

    OtpResponse resendCode(OtpRequest req);

    void verifyCode(VerifyCodeRequest req);

    void resetPassword(ResetPasswordRequest req);
}
