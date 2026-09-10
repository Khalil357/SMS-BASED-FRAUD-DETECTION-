const BASE_URL = 'http://localhost:8080';
const TOKEN_KEY = 'argus_admin_token';

interface LoginParams {
  email: string;
  password: string;
}

interface LoginResult {
  success: boolean;
  message?: string;
}

/** Read the stored admin JWT (if any). */
export function getToken(): string | null {
  try {
    return localStorage.getItem(TOKEN_KEY);
  } catch {
    return null;
  }
}

/** Clear the stored admin JWT. */
export function clearToken(): void {
  try {
    localStorage.removeItem(TOKEN_KEY);
  } catch {
    // ignore
  }
}

function storeToken(token?: string | null): void {
  if (token) {
    try {
      localStorage.setItem(TOKEN_KEY, token);
    } catch {
      // ignore
    }
  }
}

export async function login({ email, password }: LoginParams): Promise<LoginResult> {
  const cleanEmail = email.trim().toLowerCase();
  return postJson("/api/auth/login", { email: cleanEmail, password });
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
  const cleanEmail = email.trim().toLowerCase();

  try {
    const response = await fetch(`${BASE_URL}/api/auth/verify-login-otp`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email: cleanEmail, verificationCode }),
    });

    const data = await response.json();

    if (!response.ok) {
      return { success: false, message: data.message ?? "Verification failed" };
    }

    // LoginResponse is nested under `data`; persist the JWT for admin API calls.
    const token = data.data?.token ?? data.token;
    storeToken(token);

    return { success: true, message: data.message ?? "Login successful" };
  } catch {
    return { success: false, message: "Unable to reach the server" };
  }
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