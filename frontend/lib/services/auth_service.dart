import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class AuthService {
  /// Custom backend URL override (e.g. http://192.168.100.224:8080)
  static String? customBaseUrl;

  /// Dynamic baseUrl getter for logging/debugging
  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.trim().isNotEmpty) {
      return customBaseUrl!.trim();
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  // Session variables
  static Map<String, dynamic>? currentUser;
  static String? token;

  /// Helper to send POST requests with automatic fallback for physical phone vs emulator
  static Future<http.Response> _postRequest(String path, Map<String, dynamic> body) async {
    final headers = {'Content-Type': 'application/json'};
    final encodedBody = jsonEncode(body);

    if (customBaseUrl != null && customBaseUrl!.trim().isNotEmpty) {
      return await http.post(
        Uri.parse('${customBaseUrl!.trim()}$path'),
        headers: headers,
        body: encodedBody,
      ).timeout(const Duration(seconds: 10));
    }

    if (Platform.isAndroid) {
      // 1. Try 10.0.2.2 (standard for Android Emulator)
      try {
        return await http.post(
          Uri.parse('http://10.0.2.2:8080$path'),
          headers: headers,
          body: encodedBody,
        ).timeout(const Duration(seconds: 3));
      } catch (_) {
        // 2. Fallback to 127.0.0.1 (ADB reverse for physical phone)
        return await http.post(
          Uri.parse('http://127.0.0.1:8080$path'),
          headers: headers,
          body: encodedBody,
        ).timeout(const Duration(seconds: 6));
      }
    }

    return await http.post(
      Uri.parse('http://localhost:8080$path'),
      headers: headers,
      body: encodedBody,
    ).timeout(const Duration(seconds: 10));
  }

  /// Safely decode JSON — returns empty map on null/empty/malformed body
  static Map<String, dynamic> _safeJsonDecode(String body) {
    if (body.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Register a new user
  /// POST /api/auth/register
  static Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String gender,
    required String password,
  }) async {
    try {
      final response = await _postRequest('/api/auth/register', {
        'full_name': fullName,
        'email': email,
        'phone_number': phoneNumber,
        'gender': gender,
        'password': password,
      });

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Account created successfully',
          'data': decoded['data'] ?? decoded,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Sign up failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to backend server. Please verify the backend is running.',
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
      final response = await _postRequest('/api/auth/login', {
        'phone_number': phoneNumber,
        'password': password,
      });

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = decoded['data'] as Map<String, dynamic>? ?? decoded;
        currentUser = data;
        token = decoded['token'] as String? ?? data['token'] as String?;
        return {
          'success': true,
          'message': decoded['message'] ?? 'Login successful',
          'data': decoded,
          'token': token,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Login failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to backend server. Please verify the backend is running.',
        'error': e,
      };
    }
  }

  /// Request password reset code
  /// POST /api/auth/password-resets
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String phoneNumber,
  }) async {
    try {
      final response = await _postRequest('/api/auth/password-resets', {
        'phone_number': phoneNumber,
      });

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Reset code sent successfully',
          'data': decoded['data'] ?? decoded,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to send reset code',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to backend server. Please verify the backend is running.',
        'error': e,
      };
    }
  }

  /// Resend verification code
  /// POST /api/auth/password-resets/resend
  static Future<Map<String, dynamic>> resendCode({
    required String phoneNumber,
  }) async {
    try {
      final response = await _postRequest('/api/auth/password-resets/resend', {
        'phone_number': phoneNumber,
      });

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Code resent successfully',
          'data': decoded['data'] ?? decoded,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to resend code',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to backend server. Please verify the backend is running.',
        'error': e,
      };
    }
  }

  /// Verify reset code
  /// POST /api/auth/password-resets/verify
  static Future<Map<String, dynamic>> verifyResetCode({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    try {
      final response = await _postRequest('/api/auth/password-resets/verify', {
        'phone_number': phoneNumber,
        'verification_code': verificationCode,
      });

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Code verified successfully',
          'data': decoded['data'] ?? decoded,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Invalid verification code',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to backend server. Please verify the backend is running.',
        'error': e,
      };
    }
  }

  /// Reset password with verification code
  /// POST /api/auth/password-resets/confirm
  static Future<Map<String, dynamic>> resetPassword({
    required String phoneNumber,
    required String verificationCode,
    required String newPassword,
  }) async {
    try {
      final response = await _postRequest('/api/auth/password-resets/confirm', {
        'phone_number': phoneNumber,
        'verification_code': verificationCode,
        'new_password': newPassword,
      });

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Password reset successfully',
          'data': decoded['data'] ?? decoded,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to reset password',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to backend server. Please verify the backend is running.',
        'error': e,
      };
    }
  }
}
