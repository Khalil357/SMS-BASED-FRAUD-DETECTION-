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
      // Prioritize 127.0.0.1 for physical devices (requires adb reverse tcp:8080 tcp:8080)
      return 'http://127.0.0.1:8080';
    }
    return 'http://localhost:8080';
  }

  // Session variables & Storage Keys
  static Map<String, dynamic>? currentUser;
  static String? token;

  static const String _keyToken = 'auth_token_v1';
  static const String _keyUser = 'auth_user_v1';

  static bool _isUsableAccessToken(String? value) {
    final candidate = value?.trim() ?? '';
    return candidate.isNotEmpty && candidate.split('.').length == 3;
  }

  static Future<bool> _ensureAuthenticated() async {
    if (_isUsableAccessToken(token)) return true;
    return loadSession();
  }

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

      if (_isUsableAccessToken(savedToken) && savedUserJson != null && savedUserJson.isNotEmpty) {
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

  /// Private helper for multi-host resilience
  static Future<http.Response> _sendRequest(String method, String path, {Map<String, dynamic>? body, Duration timeout = const Duration(seconds: 15)}) async {
    final headers = {
      'Content-Type': 'application/json',
      if (_isUsableAccessToken(token)) 'Authorization': 'Bearer $token',
    };
    final encodedBody = body != null ? jsonEncode(body) : null;

    final List<String> hostsToTry = customBaseUrl != null 
        ? [customBaseUrl!] 
        : (Platform.isAndroid ? ['http://127.0.0.1:8080', 'http://10.0.2.2:8080'] : ['http://localhost:8080']);

    Object? lastError;
    for (var host in hostsToTry) {
      try {
        final uri = Uri.parse('${host.endsWith('/') ? host.substring(0, host.length - 1) : host}$path');
        http.Response response;
        
        switch (method.toUpperCase()) {
          case 'GET': response = await http.get(uri, headers: headers).timeout(timeout); break;
          case 'POST': response = await http.post(uri, headers: headers, body: encodedBody).timeout(timeout); break;
          case 'DELETE': response = await http.delete(uri, headers: headers).timeout(timeout); break;
          default: throw UnsupportedError('Method $method not supported');
        }
        
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
    throw lastError ?? Exception('Failed to connect to any backend host at $hostsToTry');
  }

  /// Public generic request methods
  static Future<http.Response> get(String path) => _sendRequest('GET', path);
  static Future<http.Response> post(String path, Map<String, dynamic> body) => _sendRequest('POST', path, body: body);
  static Future<http.Response> delete(String path) => _sendRequest('DELETE', path);

  /// Submit SMS scan payload to backend API
  static Future<Map<String, dynamic>> submitScan({
    required String sender,
    required String messageBody,
    String source = 'MANUAL_QUERY',
  }) async {
    try {
      if (!await _ensureAuthenticated()) {
        return {'success': false, 'message': 'Authentication required.', 'statusCode': 401};
      }

      final body = {
        'sender': sender,
        'message_body': messageBody,
        'messageBody': messageBody,
        'source': source,
      };

      final response = await _sendRequest('POST', '/api/scans', body: body, timeout: const Duration(seconds: 25));
      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = decoded['data'] is Map<String, dynamic> ? decoded['data'] : decoded;
        final isScam = data['is_scam'] ?? data['isScam'] ?? (data['label'] == 'scam' || data['label'] == 'fraud');
        return {
          'success': true,
          'message': decoded['message'] ?? 'Scan submitted successfully',
          'data': data,
          'isScam': isScam == true,
          'label': data['label'] ?? (isScam == true ? 'scam' : 'safe'),
          'confidence': (data['confidence'] as num?)?.toDouble() ?? 0.95,
        };
      }
      return {'success': false, 'message': decoded['message'] ?? 'Scan failed', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Connection error', 'error': e.toString()};
    }
  }

  /// Fetch authenticated user's "FRAUD" messages
  static Future<Map<String, dynamic>> getFraudScans({int page = 0, int size = 20}) async {
    try {
      if (!await _ensureAuthenticated()) return {'success': false, 'content': [], 'statusCode': 401};
      final response = await get('/api/scans/fraud?page=$page&size=$size');
      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = decoded['data'] is Map<String, dynamic> ? decoded['data'] : {};
        final content = data['content'] is List ? data['content'] : [];
        return {
          'success': true,
          'content': content,
          'totalElements': data['totalElements'] ?? content.length,
          'data': data,
        };
      }
      return {'success': false, 'content': [], 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'content': [], 'error': e.toString()};
    }
  }

  /// Delete a fraud scan row
  static Future<Map<String, dynamic>> deleteFraudScan({required String id}) async {
    try {
      if (!await _ensureAuthenticated()) return {'success': false, 'statusCode': 401};
      final response = await delete('/api/v1/fraud-records/${Uri.encodeComponent(id)}');
      if (response.statusCode == 204 || response.statusCode == 200) {
        return {'success': true, 'message': 'Record removed.'};
      }
      return {'success': false, 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Map<String, dynamic> _safeJsonDecode(String body) {
    if (body.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(body);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) { return {}; }
  }

  /// Auth: SignUp
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
        return {'success': true, 'message': decoded['message'], 'data': decoded['data'] ?? decoded};
      }
      return {'success': false, 'message': decoded['message'] ?? 'Sign up failed', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Connection error', 'error': e.toString()};
    }
  }

  /// Auth: Login (Two-Step support)
  static Future<Map<String, dynamic>> login({required String identifier, required String password}) async {
    try {
      final trimmed = identifier.trim();
      final isEmail = trimmed.contains('@');
      final response = await post('/api/auth/login', {
        'password': password,
        'phone_number': trimmed,
        if (isEmail) 'email': trimmed,
      });
      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = decoded['data'] as Map<String, dynamic>? ?? decoded;
        return {
          'success': true,
          'requiresOtp': true,
          'message': decoded['message'] ?? 'OTP sent for verification',
          'email': data['email']?.toString() ?? '',
          'data': data,
        };
      }
      return {'success': false, 'message': decoded['message'] ?? 'Login failed', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Connection error', 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> verifyLoginOtp({required String email, required String verificationCode}) async {
    try {
      final response = await post('/api/auth/verify-login-otp', {'email': email, 'verificationCode': verificationCode});
      final decoded = _safeJsonDecode(response.body);
      if (response.statusCode == 200) {
        final data = decoded['data'] as Map<String, dynamic>? ?? {};
        final tokenStr = data['token']?.toString() ?? '';
        if (tokenStr.isEmpty) return {'success': false, 'message': 'No token returned'};
        await saveSession(tokenStr, data);
        return {'success': true, 'data': data};
      }
      return {'success': false, 'message': decoded['message'] ?? 'Invalid code', 'statusCode': response.statusCode};
    } catch (e) {
      return {'success': false, 'message': 'Verification failed', 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> resendLoginOtp({required String email}) async {
    try {
      final response = await post('/api/auth/resend-login-otp', {'email': email});
      return {'success': response.statusCode == 200, 'message': _safeJsonDecode(response.body)['message']};
    } catch (e) { return {'success': false, 'error': e.toString()}; }
  }

  /// Password Resets
  static Future<Map<String, dynamic>> requestPasswordReset({required String phoneNumber}) async {
    try {
      final response = await post('/api/auth/password-resets', {'phone_number': phoneNumber});
      final decoded = _safeJsonDecode(response.body);
      return {'success': response.statusCode == 200, 'message': decoded['message'], 'data': decoded['data']};
    } catch (e) { return {'success': false, 'error': e.toString()}; }
  }

  static Future<Map<String, dynamic>> resendCode({required String phoneNumber}) async {
    try {
      final response = await post('/api/auth/password-resets/resend', {'phone_number': phoneNumber});
      return {'success': response.statusCode == 200, 'message': _safeJsonDecode(response.body)['message']};
    } catch (e) { return {'success': false, 'error': e.toString()}; }
  }

  static Future<Map<String, dynamic>> verifyResetCode({required String phoneNumber, required String verificationCode}) async {
    try {
      final response = await post('/api/auth/password-resets/verify', {'phone_number': phoneNumber, 'verification_code': verificationCode});
      return {'success': response.statusCode == 200, 'message': _safeJsonDecode(response.body)['message']};
    } catch (e) { return {'success': false, 'error': e.toString()}; }
  }

  static Future<Map<String, dynamic>> resetPassword({required String phoneNumber, required String verificationCode, required String newPassword}) async {
    try {
      final response = await post('/api/auth/password-resets/confirm', {'phone_number': phoneNumber, 'verification_code': verificationCode, 'new_password': newPassword});
      return {'success': response.statusCode == 200, 'message': _safeJsonDecode(response.body)['message']};
    } catch (e) { return {'success': false, 'error': e.toString()}; }
  }
}
