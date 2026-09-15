import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  // Session variables & Storage Keys
  static Map<String, dynamic>? currentUser;
  static String? token;

  static const String _keyToken = 'auth_token_v1';
  static const String _keyUser = 'auth_user_v1';

  /// Save session to persistent storage
  static Future<void> saveSession(String tokenStr, Map<String, dynamic> userMap) async {
    token = tokenStr;
    currentUser = userMap;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, tokenStr);
    await prefs.setString(_keyUser, jsonEncode(userMap));
  }

  /// Load session from persistent storage
  static Future<bool> loadSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final savedToken = prefs.getString(_keyToken);
      final savedUserJson = prefs.getString(_keyUser);

      if (savedToken != null && savedToken.isNotEmpty && savedUserJson != null && savedUserJson.isNotEmpty) {
        token = savedToken;
        currentUser = jsonDecode(savedUserJson) as Map<String, dynamic>;
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Clear persistent session (Logout)
  static Future<void> logout() async {
    token = null;
    currentUser = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUser);
    } catch (_) {}
  }

  static final StreamController<bool> _sessionExpiredController = StreamController<bool>.broadcast();
  static Stream<bool> get sessionExpiredStream => _sessionExpiredController.stream;

  /// Helper to send authenticated GET requests
  static Future<http.Response> _getRequest(String path) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final List<String> hostsToTry = customBaseUrl != null 
        ? [customBaseUrl!] 
        : (Platform.isAndroid ? ['http://127.0.0.1:8080', 'http://10.0.2.2:8080'] : ['http://localhost:8080']);

    Object? lastError;
    for (var host in hostsToTry) {
      try {
        final uri = Uri.parse('${host.endsWith('/') ? host.substring(0, host.length - 1) : host}$path');
        final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 401) {
          await logout();
          _sessionExpiredController.add(true);
        }
        return response;
      } catch (e) {
        lastError = e;
        continue;
      }
    }
    throw lastError ?? Exception('Failed to connect to any backend host');
  }

  /// Helper to send POST requests with automatic fallback for physical phone vs emulator
  static Future<http.Response> _postRequest(String path, Map<String, dynamic> body) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encodedBody = jsonEncode(body);

    final List<String> hostsToTry = customBaseUrl != null 
        ? [customBaseUrl!] 
        : (Platform.isAndroid ? ['http://127.0.0.1:8080', 'http://10.0.2.2:8080'] : ['http://localhost:8080']);

    Object? lastError;

    for (var host in hostsToTry) {
      try {
        final uri = Uri.parse('${host.endsWith('/') ? host.substring(0, host.length - 1) : host}$path');
        final response = await http.post(
          uri,
          headers: headers,
          body: encodedBody,
        ).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 401) {
          await logout();
          _sessionExpiredController.add(true);
        }
        return response;
      } catch (e) {
        lastError = e;
        continue; // Try next host
      }
    }

    throw lastError ?? Exception('Failed to connect to any backend host');
  }

  /// Helper to send authenticated DELETE requests
  static Future<http.Response> _deleteRequest(String path) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    final List<String> hostsToTry = customBaseUrl != null 
        ? [customBaseUrl!] 
        : (Platform.isAndroid ? ['http://127.0.0.1:8080', 'http://10.0.2.2:8080'] : ['http://localhost:8080']);

    Object? lastError;
    for (var host in hostsToTry) {
      try {
        final uri = Uri.parse('${host.endsWith('/') ? host.substring(0, host.length - 1) : host}$path');
        final response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 15));
        
        if (response.statusCode == 401) {
          await logout();
          _sessionExpiredController.add(true);
        }
        return response;
      } catch (e) {
        lastError = e;
        continue;
      }
    }
    throw lastError ?? Exception('Failed to connect to any backend host');
  }

  /// Public generic request methods for other services
  static Future<http.Response> get(String path) => _getRequest(path);
  static Future<http.Response> post(String path, Map<String, dynamic> body) => _postRequest(path, body);
  static Future<http.Response> delete(String path) => _deleteRequest(path);

  /// Submit SMS scan payload to backend API
  static Future<Map<String, dynamic>> submitScan({
    required String sender,
    required String messageBody,
    String source = 'MANUAL_QUERY',
  }) async {
    try {
      if (token == null || token!.isEmpty) {
        await loadSession();
      }

      final body = <String, dynamic>{
        'sender': sender,
        'message_body': messageBody,
        'messageBody': messageBody,
        'message': messageBody,
        'source': source,
      };

      final response = await post('/api/scans', body);
      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = decoded['data'] is Map<String, dynamic>
            ? (decoded['data'] as Map<String, dynamic>)
            : decoded;

        final isScam = data['is_scam'] ??
            data['isScam'] ??
            (data['label'] == 'scam' || data['label'] == 'fraud');
        final label = data['label'] ?? (isScam == true ? 'scam' : 'safe');
        final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.95;

        return {
          'success': true,
          'message': decoded['message'] ?? 'Scan submitted successfully',
          'data': data,
          'isScam': isScam == true,
          'label': label,
          'confidence': confidence,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Scan submission failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to submit scan to backend server.',
        'error': e,
      };
    }
  }

  static Future<Map<String, dynamic>> addFraudScan({
    required String sender,
    required String messageBody,
    String source = 'MANUAL_QUERY',
  }) async {
    return await submitScan(
      sender: sender,
      messageBody: messageBody,
      source: source,
    );
  }

  /// Fetch authenticated user's "FRAUD" messages with pagination
  static Future<Map<String, dynamic>> getFraudScans({
    int page = 0,
    int size = 20,
  }) async {
    try {
      if (token == null || token!.isEmpty) {
        await loadSession();
      }

      final response = await get('/api/scans/fraud?page=$page&size=$size');
      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = decoded['data'] is Map<String, dynamic>
            ? (decoded['data'] as Map<String, dynamic>)
            : <String, dynamic>{};
        final content =
            data['content'] is List ? (data['content'] as List) : [];
        return {
          'success': true,
          'message': decoded['message'] ?? 'Fraud scans retrieved successfully',
          'content': content,
          'totalElements': data['totalElements'] ?? content.length,
          'totalPages': data['totalPages'] ?? 1,
          'number': data['number'] ?? page,
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to fetch fraud scans',
          'statusCode': response.statusCode,
          'content': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to backend server.',
        'error': e,
        'content': [],
      };
    }
  }

  /// Delete a fraud scan row from backend
  static Future<Map<String, dynamic>> deleteFraudScan({
    required String id,
  }) async {
    if (id.trim().isEmpty) {
      return {
        'success': false,
        'message': 'Missing backend record ID — cannot delete.',
      };
    }

    try {
      if (token == null || token!.isEmpty) {
        await loadSession();
      }

      final path = '/api/v1/fraud-records/${Uri.encodeComponent(id)}';
      final response = await delete(path);

      if (response.statusCode == 204 || response.statusCode == 200) {
        return {
          'success': true,
          'message': 'Record removed from the database.',
        };
      }

      if (response.statusCode == 404) {
        return {
          'success': true,
          'message': 'Record was already removed.',
        };
      }

      final decoded = _safeJsonDecode(response.body);
      return {
        'success': false,
        'message': decoded['message'] ??
            'Failed to remove the record (status ${response.statusCode}).',
        'statusCode': response.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to backend server.',
        'error': e,
      };
    }
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
  static Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String gender,
    required String password,
  }) async {
    try {
      final response = await post('/api/auth/register', {
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
      final attemptedUrl = customBaseUrl ?? (Platform.isAndroid ? '10.0.2.2 or 127.0.0.1' : 'localhost');
      return {
        'success': false,
        'message': 'Failed to connect to backend at $attemptedUrl. Please verify the backend is running and reachable.',
        'error': e.toString(),
      };
    }
  }

  /// Login user
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final trimmed = identifier.trim();
      final isEmail = trimmed.contains('@');

      final body = <String, dynamic>{
        'password': password,
        'phone_number': trimmed,
        if (isEmail) 'email': trimmed,
      };

      final response = await post('/api/auth/login', body);
      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = decoded['data'] as Map<String, dynamic>? ?? decoded;
        final tokenStr = decoded['token'] as String? ?? data['token'] as String? ?? '';

        await saveSession(tokenStr, data);

        return {
          'success': true,
          'message': decoded['message'] ?? 'Login successful',
          'data': decoded,
          'token': tokenStr,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Login failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      final attemptedUrl = customBaseUrl ?? (Platform.isAndroid ? '10.0.2.2 or 127.0.0.1' : 'localhost');
      return {
        'success': false,
        'message': 'Failed to connect to backend at $attemptedUrl. Please verify the backend is running and reachable.',
        'error': e.toString(),
      };
    }
  }

  /// Request password reset code
  static Future<Map<String, dynamic>> requestPasswordReset({
    required String phoneNumber,
  }) async {
    try {
      final response = await post('/api/auth/password-resets', {
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
      final attemptedUrl = customBaseUrl ?? (Platform.isAndroid ? '10.0.2.2 or 127.0.0.1' : 'localhost');
      return {
        'success': false,
        'message': 'Failed to connect to backend at $attemptedUrl. Please verify the backend is running and reachable.',
        'error': e.toString(),
      };
    }
  }

  /// Resend verification code
  static Future<Map<String, dynamic>> resendCode({
    required String phoneNumber,
  }) async {
    try {
      final response = await post('/api/auth/password-resets/resend', {
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
      final attemptedUrl = customBaseUrl ?? (Platform.isAndroid ? '10.0.2.2 or 127.0.0.1' : 'localhost');
      return {
        'success': false,
        'message': 'Failed to connect to backend at $attemptedUrl. Please verify the backend is running and reachable.',
        'error': e.toString(),
      };
    }
  }

  /// Verify reset code
  static Future<Map<String, dynamic>> verifyResetCode({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    try {
      final response = await post('/api/auth/password-resets/verify', {
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
      final attemptedUrl = customBaseUrl ?? (Platform.isAndroid ? '10.0.2.2 or 127.0.0.1' : 'localhost');
      return {
        'success': false,
        'message': 'Failed to connect to backend at $attemptedUrl. Please verify the backend is running and reachable.',
        'error': e.toString(),
      };
    }
  }

  /// Reset password with verification code
  static Future<Map<String, dynamic>> resetPassword({
    required String phoneNumber,
    required String verificationCode,
    required String newPassword,
  }) async {
    try {
      final response = await post('/api/auth/password-resets/confirm', {
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
      final attemptedUrl = customBaseUrl ?? (Platform.isAndroid ? '10.0.2.2 or 127.0.0.1' : 'localhost');
      return {
        'success': false,
        'message': 'Failed to connect to backend at $attemptedUrl. Please verify the backend is running and reachable.',
        'error': e.toString(),
      };
    }
  }
}
