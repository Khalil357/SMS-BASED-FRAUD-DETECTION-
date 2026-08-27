import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  // Local backend (web/desktop on the same machine). For an Android emulator
  // use 'http://10.0.2.2:8080'; for a physical device use your LAN IP.
  static const String baseUrl = 'http://localhost:8080';

  // Session variables
  static Map<String, dynamic>? currentUser;
  static String? token;

  // PLACEHOLDER: Add any API keys or authentication tokens if needed
  // static const String apiKey = 'YOUR_API_KEY_HERE';

  /// Register a new user
  /// POST /api/auth/signup
  static Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String gender,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/signup'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'phone_number': phoneNumber,
          'gender': gender,
          'password': password,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Account created successfully',
          'data': jsonDecode(response.body),
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Sign up failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'error': e,
      };
    }
  }

  /// Login user
  /// POST /api/auth/login
  static Future<Map<String, dynamic>> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        currentUser = data['data'] as Map<String, dynamic>?;
        token = data['token'] as String?;
        return {
          'success': true,
          'message': 'Login successful',
          'data': data,
          'token': data['token'], // Store this for future authenticated requests
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Login failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'error': e,
      };
    }
  }

  /// Request password reset code
  /// POST /api/auth/forgot-password
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/forgot-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Reset code sent successfully',
          'data': jsonDecode(response.body),
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to send reset code',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'error': e,
      };
    }
  }

  /// Verify reset code
  /// POST /api/auth/verify-code
  static Future<Map<String, dynamic>> verifyResetCode({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/verify-code'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
          'verification_code': verificationCode,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Code verified successfully',
          'data': jsonDecode(response.body),
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Invalid verification code',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'error': e,
      };
    }
  }

  /// Resend verification code
  /// POST /api/auth/resend-code
  static Future<Map<String, dynamic>> resendCode({
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/resend-code'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Code resent successfully',
          'data': jsonDecode(response.body),
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to resend code',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'error': e,
      };
    }
  }

  /// Reset password with verification code
  /// POST /api/auth/reset-password
  static Future<Map<String, dynamic>> resetPassword({
    required String phoneNumber,
    required String verificationCode,
    required String newPassword,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/reset-password'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
          'verification_code': verificationCode,
          'new_password': newPassword,
        }),
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Password reset successfully',
          'data': jsonDecode(response.body),
        };
      } else {
        final errorData = jsonDecode(response.body);
        return {
          'success': false,
          'message': errorData['message'] ?? 'Failed to reset password',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
        'error': e,
      };
    }
  }
}
