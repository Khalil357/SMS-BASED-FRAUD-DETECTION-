import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _prefsKeyToken = 'auth_token';
  static const String _prefsKeyUser = 'auth_user';

  /// Pass API_BASE_URL when building for a physical device or a deployed API.
  ///
  /// `10.0.2.2` is only the Android emulator's route back to the development
  /// computer. A phone needs the computer's LAN address or a public HTTPS URL.
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String _resolvedBaseUrl = '';
  static Future<void>? _inFlightDiscovery;
  static DateTime? _lastFailureAt;

  /// Candidate endpoints probed so the app works over the USB cable
  /// (`adb reverse`), on the same WiFi (laptop LAN IP), or on the emulator —
  /// without rebuilding whenever the transport changes.
  static const List<String> _fallbackHosts = <String>[
    'http://127.0.0.1:8080',
    'http://192.168.18.15:8080',
    'http://192.168.100.149:8080',
    'http://10.0.2.2:8080',
  ];

  static String _stripSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  // Resolve the API endpoint for emulators, desktop targets, and configured devices.
  static String get baseUrl {
    if (_resolvedBaseUrl.isNotEmpty) {
      return _resolvedBaseUrl;
    }
    if (_configuredBaseUrl.isNotEmpty) {
      return _stripSlash(_configuredBaseUrl);
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    return 'http://localhost:8080';
  }

  static List<String> get candidates => <String>{
        if (_configuredBaseUrl.isNotEmpty) _stripSlash(_configuredBaseUrl),
        ..._fallbackHosts,
      }.toList();

  /// Probe candidate backend URLs (2s each) until one answers. Re-probes on
  /// every call while still unresolved, so plugging the USB cable in later
  /// (restoring `adb reverse`) just works. Fast no-op once resolved.
  static Future<void> ensureBackendReachable() async {
    if (_resolvedBaseUrl.isNotEmpty) return;
    final inFlight = _inFlightDiscovery;
    if (inFlight != null) return inFlight;
    final probe = _discover();
    _inFlightDiscovery = probe;
    try {
      await probe;
    } finally {
      _inFlightDiscovery = null;
    }
  }

  static Future<void> _discover() async {
    for (final candidate in candidates) {
      try {
        final resp = await http
            .get(Uri.parse('$candidate/api/health'))
            .timeout(const Duration(seconds: 2));
        // Any HTTP response proves a backend is behind that address — even a
        // 401/404, since the API locks every route behind Spring Security.
        _resolvedBaseUrl = candidate;
        _lastFailureAt = null;
        return;
      } catch (_) {
        // Unreachable host — try the next candidate.
      }
    }
    _lastFailureAt = DateTime.now();
  }

  // Session variables
  static Map<String, dynamic>? currentUser;
  static String? token;
  static Timer? _sessionTimer;
  static void Function(String?)? onSessionExpired;

  static Future<void> _saveSession(String jwtToken, Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyToken, jwtToken);
      await prefs.setString(_prefsKeyUser, jsonEncode(userData));
    } catch (_) {}
  }

  static Future<void> _clearSessionPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyToken);
      await prefs.remove(_prefsKeyUser);
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jwtToken = prefs.getString(_prefsKeyToken);
      final userJson = prefs.getString(_prefsKeyUser);
      if (jwtToken != null && userJson != null && _isUsableToken(jwtToken)) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        final expiry = _decodeTokenExpiry(jwtToken);
        if (expiry != null && !expiry.isAfter(DateTime.now())) {
          // Token already expired — treat as no active session.
          await _clearSessionPrefs();
          return null;
        }
        currentUser = userData;
        token = jwtToken;
        _scheduleSessionTimer();
        return {'success': true, 'token': token, 'data': currentUser};
      }
    } catch (_) {}
    return null;
  }

  static void _clearSession(String? message) {
    currentUser = null;
    token = null;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    _clearSessionPrefs();
    onSessionExpired?.call(message);
  }

  static Future<void> logout() async {
    _clearSession(null);
  }

  static bool _isUsableToken(String value) {
    final candidate = value.trim();
    return candidate.isNotEmpty && candidate.split('.').length >= 3;
  }

  static DateTime? _decodeTokenExpiry(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;
      String payload = parts[1];
      String normalized = payload.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = json['exp'] as int?;
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    } catch (_) {
      return null;
    }
  }

  static void _scheduleSessionTimer() {
    if (token == null) return;
    final expiry = _decodeTokenExpiry(token!);
    if (expiry == null) return;
    final duration = expiry.difference(DateTime.now());
    if (duration.inMilliseconds > 0) {
      _sessionTimer?.cancel();
      _sessionTimer = Timer(duration, () => _clearSession('Session expired'));
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

  static String _connectionErrorMessage() {
    final probed = candidates.map((u) => u.split('//').last).join(', ');
    return 'Cannot reach the backend. Tried: $probed. '
        'Make sure the backend is running (docker compose up) and the phone is '
        'either plugged in over USB (adb reverse) or on the same WiFi as the computer.';
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
    await ensureBackendReachable();
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
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
        'message': _connectionErrorMessage(),
        'error': e,
      };
    }
  }

  /// Login user with either phone number or email address
  /// POST /api/auth/login
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    await ensureBackendReachable();
    try {
      final trimmed = identifier.trim();
      final isEmail = trimmed.contains('@');

      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'password': password,
          'phone_number': trimmed,
          if (isEmail) 'email': trimmed,
        }),
      );

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = decoded['data'] as Map<String, dynamic>? ?? decoded;
        final tokenStr = (decoded['token'] ??
                data['token'] ??
                data['access_token'] ??
                data['accessToken'])
            ?.toString();
        if (tokenStr == null || tokenStr.trim().isEmpty) {
          return {
            'success': false,
            'message': 'No session token returned by the server',
            'statusCode': response.statusCode,
          };
        }
        currentUser = data;
        token = tokenStr;
        await _saveSession(token!, currentUser ?? {});
        _scheduleSessionTimer();
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
        'message': _connectionErrorMessage(),
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/password-resets'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
        }),
      );

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
        'message': _connectionErrorMessage(),
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/password-resets/resend'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
        }),
      );

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
        'message': _connectionErrorMessage(),
        'error': e,
      };
    }
  }

  /// Verify reset code / sign-up code
  /// POST /api/auth/password-resets/verify
  static Future<Map<String, dynamic>> verifyResetCode({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/password-resets/verify'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
          'verification_code': verificationCode,
        }),
      );

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
        'message': _connectionErrorMessage(),
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
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/password-resets/confirm'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone_number': phoneNumber,
          'verification_code': verificationCode,
          'new_password': newPassword,
        }),
      );

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
        'message': _connectionErrorMessage(),
        'error': e,
      };
    }
  }

  /// Submit SMS scan payload to backend API
  /// POST /api/scans
  static Future<Map<String, dynamic>> submitScan({
    required String sender,
    required String messageBody,
    String source = 'MANUAL_QUERY',
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'sender': sender,
        'messageBody': messageBody,
        'message': messageBody,
        'source': source,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/api/scans'),
        headers: headers,
        body: body,
      );

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
          'message': decoded['message'] ?? 'Scan processed successfully',
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
        'message': _connectionErrorMessage(),
        'error': e,
      };
    }
  }

  /// Fetch authenticated user's "FRAUD" messages with pagination
  /// GET /api/scans/fraud?page=0&size=20
  static Future<Map<String, dynamic>> getFraudScans({
    int page = 0,
    int size = 20,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/api/scans/fraud?page=$page&size=$size'),
        headers: headers,
      );

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = decoded['data'] is Map<String, dynamic>
            ? (decoded['data'] as Map<String, dynamic>)
            : <String, dynamic>{};
        final content = data['content'] is List ? (data['content'] as List) : [];
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
        'message': _connectionErrorMessage(),
        'error': e,
        'content': [],
      };
    }
  }

  /// Block a phone number
  /// POST /api/block
  static Future<Map<String, dynamic>> blockNumber({
    required String phoneNumber,
    String? reason,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final body = jsonEncode({
        'phoneNumber': phoneNumber,
        'reason': ?reason,
      });

      final response = await http.post(
        Uri.parse('$baseUrl/api/block'),
        headers: headers,
        body: body,
      );

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Number blocked successfully',
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to block number',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': _connectionErrorMessage(),
        'error': e,
      };
    }
  }

  /// Unblock a phone number
  /// DELETE /api/block
  static Future<Map<String, dynamic>> unblockNumber({
    required String phoneNumber,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.delete(
        Uri.parse('$baseUrl/api/block'),
        headers: headers,
        body: jsonEncode({'phoneNumber': phoneNumber}),
      );

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Number unblocked successfully',
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to unblock number',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': _connectionErrorMessage(),
        'error': e,
      };
    }
  }

  /// Fetch user's blocked numbers
  /// GET /api/block
  static Future<Map<String, dynamic>> getBlockedNumbers() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

      final response = await http.get(
        Uri.parse('$baseUrl/api/block'),
        headers: headers,
      );

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = decoded['data'] is Map<String, dynamic>
            ? (decoded['data'] as Map<String, dynamic>)
            : <String, dynamic>{};
        final blocked = data['blockedNumbers'] is List
            ? (data['blockedNumbers'] as List).cast<String>()
            : <String>[];
        return {
          'success': true,
          'message': decoded['message'] ?? 'Blocked numbers retrieved',
          'blockedNumbers': blocked,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Failed to fetch blocked numbers',
          'statusCode': response.statusCode,
          'blockedNumbers': [],
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': _connectionErrorMessage(),
        'error': e,
        'blockedNumbers': [],
      };
    }
  }
}
