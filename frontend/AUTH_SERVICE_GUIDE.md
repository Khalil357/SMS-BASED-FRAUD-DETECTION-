## Auth Service Integration Guide

This document explains how to use and configure the new authentication service in your Flutter app.

### 1. Configuration

**File:** `lib/services/auth_service.dart`

Update the `baseUrl` placeholder with your backend server address:

```dart
// PLACEHOLDER: Replace with your backend server address
// Example for local development:
static const String baseUrl = 'http://192.168.1.100:8000';

// Example for production:
static const String baseUrl = 'https://api.yourdomain.com';

// If you need API keys, add them here:
// static const String apiKey = 'YOUR_API_KEY_HERE';
```

### 2. Available API Endpoints

The auth service expects the following endpoints on your backend:

#### Sign Up
- **Method:** POST
- **Endpoint:** `/api/auth/signup`
- **Body:** 
```json
{
  "full_name": "John Doe",
  "email": "john@example.com",
  "phone_number": "+27821234567",
  "gender": "Male",
  "password": "SecurePass123!"
}
```
- **Response:** User data with status 201 or 200

#### Login
- **Method:** POST
- **Endpoint:** `/api/auth/login`
- **Body:**
```json
{
  "phone_number": "+27821234567",
  "password": "SecurePass123!"
}
```
- **Response:** Include `token` field for JWT/Bearer token authentication
```json
{
  "token": "your_auth_token",
  "user": {...}
}
```

#### Forgot Password (Request Reset Code)
- **Method:** POST
- **Endpoint:** `/api/auth/forgot-password`
- **Body:**
```json
{
  "phone_number": "+27821234567"
}
```

#### Verify Reset Code
- **Method:** POST
- **Endpoint:** `/api/auth/verify-code`
- **Body:**
```json
{
  "phone_number": "+27821234567",
  "verification_code": "123456"
}
```

#### Resend Code
- **Method:** POST
- **Endpoint:** `/api/auth/resend-code`
- **Body:**
```json
{
  "phone_number": "+27821234567"
}
```

#### Reset Password
- **Method:** POST
- **Endpoint:** `/api/auth/reset-password`
- **Body:**
```json
{
  "phone_number": "+27821234567",
  "verification_code": "123456",
  "new_password": "NewSecurePass123!"
}
```

### 3. Updated Pages

All authentication pages have been converted to stateful widgets and now handle user input:

- **LoginPage** (`lib/screens/login_page.dart`)
  - Collects phone number and password
  - Calls `AuthService.login()` on submit
  - Displays error messages

- **SignUpPage** (`lib/screens/sign_up_page.dart`)
  - Collects full name, email, phone, gender, password
  - Validates password confirmation
  - Requires terms acceptance
  - Calls `AuthService.signUp()` on submit

- **ForgotPasswordPage** (`lib/screens/forgot_password_page.dart`)
  - Collects phone number
  - Calls `AuthService.requestPasswordReset()` to send reset code
  - Navigates to verification page on success

- **VerificationPage** (`lib/screens/verification_page.dart`)
  - Collects 6-digit verification code via OTP fields
  - Auto-advances to next field when digit is entered
  - Supports resending code
  - Calls `AuthService.verifyResetCode()` on submit
  - **TODO:** Pass phone number from previous page

- **ResetPasswordPage** (`lib/screens/reset_password_page.dart`)
  - Collects new password and confirmation
  - Validates password requirements (8+ chars)
  - Calls `AuthService.resetPassword()` on submit
  - **TODO:** Pass phone number and verification code from previous page

### 4. Passing Data Between Pages

Currently, phone number and verification code are initialized as empty strings in verification and reset password pages. To properly pass this data:

**Option A: Using Route Arguments**
```dart
// In ForgotPasswordPage
widget.onNavigate(AuthPage.verification); // Pass phone as param

// In VerificationPage constructor
VerificationPage({
  required this.onNavigate,
  required this.phoneNumber, // Add this
});
```

**Option B: Using Provider/State Management**
Consider using a state management solution (Provider, Riverpod, GetX) to share auth data across pages.

### 5. Token Storage

After login, store the authentication token for future requests:

```dart
// In LoginPage _handleLogin() method:
if (result['success']) {
  final prefs = await SharedPreferences.getInstance();
  prefs.setString('auth_token', result['token']);
  // Navigate to dashboard
}
```

Add to pubspec.yaml:
```yaml
dependencies:
  shared_preferences: ^2.2.0
```

### 6. Adding Headers to Protected Requests

For future API calls that require authentication:

```dart
final prefs = await SharedPreferences.getInstance();
final token = prefs.getString('auth_token');

final response = await http.get(
  Uri.parse('$baseUrl/api/protected-endpoint'),
  headers: {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  },
);
```

### 7. Error Handling

All auth service methods return a map with:
- `success` (bool): Whether the request succeeded
- `message` (string): Human-readable message
- `data` (dynamic): Response data on success
- `error` (dynamic): Exception details on failure

The pages handle errors by displaying them in red text to the user.

### 8. Testing the Backend Connection

1. Update `baseUrl` in `auth_service.dart`
2. Run `flutter pub get` to install http dependency
3. Run the app and try logging in
4. Check the console for HTTP request logs
5. Verify backend responds with correct data format

### 9. Next Steps

1. ✅ Configure `baseUrl` with your backend URL
2. ✅ Create backend endpoints matching the spec above
3. ✅ Update verification and reset password pages to pass phone number
4. ✅ Implement token storage (SharedPreferences)
5. ✅ Add authentication headers to protected API calls
6. ✅ Test the full auth flow
