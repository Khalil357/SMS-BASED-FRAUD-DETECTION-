const BASE_URL = 'http://localhost:8080';
const TOKEN_KEY = 'argus_admin_token';

/** Admin-visible user view, matching the backend `UserResponse` (snake_case). */
export interface AdminUser {
  user_id: string;
  full_name: string;
  email: string;
  phone: string;
  role: 'ADMIN' | 'USER';
  verified: boolean;
  active: boolean;
}

export interface ApiResult<T> {
  success: boolean;
  data?: T;
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

/** Decode the JWT `sub` claim (the logged-in user id) without verifying signature. */
export function getCurrentUserId(): string | null {
  const token = getToken();
  if (!token) return null;
  try {
    const parts = token.split('.');
    if (parts.length !== 3) return null;
    const base64 = parts[1].replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64.padEnd(Math.ceil(base64.length / 4) * 4, '=');
    const payload = JSON.parse(atob(padded)) as { sub?: string };
    return payload.sub ?? null;
  } catch {
    return null;
  }
}

/** Authenticated fetch helper: attaches the Bearer token and unwraps the ApiResponse envelope. */
async function authFetchJson<T>(path: string, init?: RequestInit): Promise<ApiResult<T>> {
  const token = getToken();
  if (!token) {
    return { success: false, message: 'Not authenticated' };
  }
  try {
    const response = await fetch(`${BASE_URL}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        ...(init?.headers ?? {}),
      },
    });
    const body = (await response.json().catch(() => null)) as {
      message?: string;
      data?: T;
    } | null;
    if (!response.ok) {
      return { success: false, message: body?.message ?? `Request failed (${response.status})` };
    }
    return { success: true, data: body?.data ?? (body as unknown as T), message: body?.message };
  } catch {
    return { success: false, message: 'Unable to reach the server' };
  }
}

/** List all users (admin only). */
export function getUsers(): Promise<ApiResult<AdminUser[]>> {
  return authFetchJson<AdminUser[]>('/api/admin/users');
}

/** Change a user's role (admin only). */
export function updateUserRole(
  userId: string,
  role: 'ADMIN' | 'USER',
): Promise<ApiResult<AdminUser>> {
  return authFetchJson<AdminUser>(`/api/admin/users/${userId}/role`, {
    method: 'PATCH',
    body: JSON.stringify({ role }),
  });
}

/** Payload for the admin "add user" form. The portal only creates ADMIN accounts. */
export interface CreateUserPayload {
  full_name: string;
  email: string;
  phone_number: string;
  password: string;
  gender?: 'MALE' | 'FEMALE' | 'OTHER';
}

/** Create a new user (admin only). */
export function createUser(payload: CreateUserPayload): Promise<ApiResult<AdminUser>> {
  return authFetchJson<AdminUser>('/api/admin/users', {
    method: 'POST',
    body: JSON.stringify(payload),
  });
}

/** Payload for the admin "edit user" form. Role is fixed at creation and not editable. */
export interface UpdateUserPayload {
  full_name: string;
  email: string;
  phone_number: string;
  active: boolean;
}

/** Edit a user's profile and active status (admin only). */
export function updateUser(
  userId: string,
  payload: UpdateUserPayload,
): Promise<ApiResult<AdminUser>> {
  return authFetchJson<AdminUser>(`/api/admin/users/${userId}`, {
    method: 'PUT',
    body: JSON.stringify(payload),
  });
}

/** Reset a user's password to a new value (admin only). */
export function resetUserPassword(
  userId: string,
  password: string,
): Promise<ApiResult<void>> {
  return authFetchJson<void>(`/api/admin/users/${userId}/password`, {
    method: 'PATCH',
    body: JSON.stringify({ password }),
  });
}

/** Delete a user (admin only). */
export function deleteUser(userId: string): Promise<ApiResult<void>> {
  return authFetchJson<void>(`/api/admin/users/${userId}`, {
    method: 'DELETE',
  });
}
