const BASE_URL = 'http://localhost:8080';

interface LoginParams {
  email: string;
  password: string;
}

interface LoginResult {
  success: boolean;
  message?: string;
}

export async function login({ email, password }: LoginParams): Promise<LoginResult> {
  try {
    const response = await fetch(`${BASE_URL}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password }),
    });

    const data = await response.json();

    if (!response.ok) {
      return { success: false, message: data.message ?? "Login failed" };
    }

    return { success: true, message: data.message ?? "Verification code sent" };
  } catch (err) {
    return { success: false, message: "Unable to reach the server" };
  }
}

interface VerifyLoginOtpParams {
  email: string;
  verificationCode: string;
}

interface EmailOnlyParams {
  email: string;
}

interface PhoneOnlyParams {
  phoneNumber: string;
}

interface VerifyCodeParams {
  phoneNumber: string;
  verificationCode: string;
}

interface ResetPasswordParams {
  phoneNumber: string;
  verificationCode: string;
  newPassword: string;
}

interface ApiResult {
  success: boolean;
  message?: string;
}

async function postJson(path: string, body: unknown): Promise<ApiResult> {
  try {
    const response = await fetch(`${BASE_URL}${path}`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
    const data = await response.json();
    if (!response.ok) {
      return { success: false, message: data.message ?? "Request failed" };
    }
    return { success: true, message: data.message ?? "Success" };
  } catch {
    return { success: false, message: "Unable to reach the server" };
  }
}

export async function verifyLoginOtp({
  email,
  verificationCode,
}: VerifyLoginOtpParams): Promise<ApiResult> {
  return postJson("/api/auth/verify-login-otp", { email, verificationCode });
}

export async function resendLoginOtp({ email }: EmailOnlyParams): Promise<ApiResult> {
  return postJson("/api/auth/resend-login-otp", { email });
}

export async function requestPasswordReset({ phoneNumber }: PhoneOnlyParams): Promise<ApiResult> {
  return postJson("/api/auth/forgot-password", { phoneNumber });
}

export async function verifyResetCode({
  phoneNumber,
  verificationCode,
}: VerifyCodeParams): Promise<ApiResult> {
  return postJson("/api/auth/verify-code", { phoneNumber, verificationCode });
}

export async function resendCode({ phoneNumber }: PhoneOnlyParams): Promise<ApiResult> {
  return postJson("/api/auth/resend-code", { phoneNumber });
}

export async function resetPassword({
  phoneNumber,
  verificationCode,
  newPassword,
}: ResetPasswordParams): Promise<ApiResult> {
  return postJson("/api/auth/reset-password", { phoneNumber, verificationCode, newPassword });
}