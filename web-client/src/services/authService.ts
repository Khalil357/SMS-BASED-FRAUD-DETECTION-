const BASE_URL = 'http://localhost:8080';

interface LoginParams {
  phoneNumber: string;
  password: string;
}

interface LoginResult {
  success: boolean;
  message?: string;
}

export async function login({ phoneNumber, password }: LoginParams): Promise<LoginResult> {
  try {
    const response = await fetch(`${BASE_URL}/api/auth/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ phoneNumber, password }),
    });

    const data = await response.json();

    if (!response.ok) {
      return { success: false, message: data.message ?? "Login failed" };
    }

    return { success: true, message: data.message ?? "Login successful!" };
  } catch (err) {
    return { success: false, message: "Unable to reach the server" };
  }
}