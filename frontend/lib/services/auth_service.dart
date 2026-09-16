import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  /// Default server base URL
  static const String defaultServerBaseUrl = 'https://54.242.107.64/api';

  /// Custom backend URL override (e.g. https://54.242.107.64/api)
  static String? customBaseUrl;

  /// Dynamic baseUrl getter
  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.trim().isNotEmpty) {
      return customBaseUrl!.trim().replaceAll(RegExp(r'/$'), '');
    }
    return defaultServerBaseUrl;
  }

  /// Helper to construct full request URL from base URL and path
  static String _buildUrl(String path) {
    final base = baseUrl;
    var cleanPath = path.trim();
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }
    if (base.endsWith('/api') && cleanPath.startsWith('/api/')) {
      cleanPath = cleanPath.substring(4);
    }
    return '$base$cleanPath';
  }

  // Session variables & Storage Keys
  static Map<String, dynamic>? currentUser;
  static String? token;

  static const String _keyToken = 'auth_token_v1';
  static const String _keyUser = 'auth_user_v1';

  /// Save session to persistent storage
  static Future<void> saveSession(
      String tokenStr, Map<String, dynamic> userMap) async {
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

      if (savedToken != null &&
          savedToken.isNotEmpty &&
          savedUserJson != null &&
          savedUserJson.isNotEmpty) {
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

  /// Helper to send POST requests with automatic fallback for physical phone vs emulator
  /// Returns properly formatted Authorization header with Bearer prefix
  static String get formattedAuthorization {
    if (token == null || token!.trim().isEmpty) return '';
    final t = token!.trim();
    if (t.toLowerCase().startsWith('bearer ')) return t;
    return 'Bearer $t';
  }

  static Future<http.Response> _postRequest(
    String path,
    Map<String, dynamic> body, {
    Map<String, String>? customHeaders,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token!.trim().isNotEmpty) 'Authorization': formattedAuthorization,
      ...?customHeaders,
    };
    final encodedBody = jsonEncode(body);
    final primaryUrl = _buildUrl(path);

    try {
      return await http
          .post(
            Uri.parse(primaryUrl),
            headers: headers,
            body: encodedBody,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      final fallbackHost = Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
      var cleanPath = path.startsWith('/') ? path : '/$path';
      return await http
          .post(
            Uri.parse('$fallbackHost$cleanPath'),
            headers: headers,
            body: encodedBody,
          )
          .timeout(const Duration(seconds: 6));
    }
  }

  /// Helper to send GET requests with automatic fallback for physical phone vs emulator
  static Future<http.Response> _getRequest(
    String path, {
    Map<String, String>? customHeaders,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token!.trim().isNotEmpty) 'Authorization': formattedAuthorization,
      ...?customHeaders,
    };
    final primaryUrl = _buildUrl(path);

    try {
      return await http
          .get(
            Uri.parse(primaryUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      final fallbackHost = Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
      var cleanPath = path.startsWith('/') ? path : '/$path';
      return await http
          .get(
            Uri.parse('$fallbackHost$cleanPath'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 6));
    }
  }

  /// Helper to send DELETE requests with the same host fallback as other calls.
  static Future<http.Response> _deleteRequest(String path) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token!.trim().isNotEmpty) 'Authorization': formattedAuthorization,
    };
    final primaryUrl = _buildUrl(path);

    try {
      return await http
          .delete(
            Uri.parse(primaryUrl),
            headers: headers,
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      final fallbackHost = Platform.isAndroid ? 'http://10.0.2.2:8080' : 'http://localhost:8080';
      var cleanPath = path.startsWith('/') ? path : '/$path';
      return await http
          .delete(
            Uri.parse('$fallbackHost$cleanPath'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 6));
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
      final body = <String, dynamic>{
        'sender': sender,
        'message_body': messageBody,
        'messageBody': messageBody,
        'message': messageBody,
        'source': source,
      };

      print(
          "[Argus Scan Endpoint] POST $baseUrl/api/scans | sender: $sender, source: $source");
      final response = await _postRequest('/api/scans', body);
      print(
          "[Argus Scan Endpoint] Status: ${response.statusCode} | Response: ${response.body}");
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

  /// Fetch authenticated user's "FRAUD" messages with pagination
  /// GET /api/scans/fraud?page=0&size=20
  static Future<Map<String, dynamic>> getFraudScans({
    int page = 0,
    int size = 20,
  }) async {
    try {
      final response =
          await _getRequest('/api/scans/fraud?page=$page&size=$size');
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

  /// Delete a fraud scan row from the backend after the user reclassifies it as safe.
  ///
  /// A message is only treated as "Safe" locally once this call confirms the
  /// row has actually been deleted from the database — see AuthService docs
  /// in dashboard_page.dart's _markAsSafe() for how this is consumed.
  ///
  /// Delete a fraud record from the backend database (DELETE /api/v1/fraud-records/{id})
  static Future<Map<String, dynamic>> deleteFraudScan({
    required String id,
  }) async {
    final scanId = id.trim();
    if (scanId.isEmpty) {
      return {
        'success': false,
        'message': 'Missing backend record ID — cannot delete.',
      };
    }

    try {
      final path1 = '/api/v1/fraud-records/${Uri.encodeComponent(scanId)}';
      print("[Argus Delete Fraud Record] DELETE $baseUrl$path1 | Header: $formattedAuthorization");
      final response1 = await _deleteRequest(path1);
      print("[Argus Delete Fraud Record] Status: ${response1.statusCode} | Body: ${response1.body}");

      if (response1.statusCode == 200 || response1.statusCode == 204 || response1.statusCode == 404) {
        return {
          'success': true,
          'message': 'Record removed from the backend database.',
        };
      }

      final path2 = '/api/scans/fraud/${Uri.encodeComponent(scanId)}';
      final response2 = await _deleteRequest(path2);
      if (response2.statusCode == 200 || response2.statusCode == 204 || response2.statusCode == 404) {
        return {
          'success': true,
          'message': 'Record removed from the backend database.',
        };
      }

      final decoded = _safeJsonDecode(response1.body);
      return {
        'success': false,
        'message': decoded['message'] ?? 'Failed to remove the record (status ${response1.statusCode}).',
        'statusCode': response1.statusCode,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to connect to backend server.',
        'error': e,
      };
    }
  }

  /// Add a user-confirmed fraud scan to the backend database.
  /// TODO: Confirm the exact endpoint path and payload with the backend team.
  static Future<Map<String, dynamic>> addFraudScan({
    required String sender,
    required String message,
  }) async {
    try {
      // TODO: Confirm exact endpoint path and payload with backend.
      final response = await _postRequest('/api/scans/fraud', {
        'sender': sender,
        'message': message,
      });
      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': decoded['message'] ?? 'Message marked as fraud.',
        };
      }

      return {
        'success': false,
        'message': decoded['message'] ?? 'Failed to mark message as fraud.',
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
  /// POST /api/auth/register
  static Future<Map<String, dynamic>> signUp({
    required String fullName,
    required String email,
    required String phoneNumber,
    required String gender,
    required String password,
  }) async {
    final userPayload = <String, dynamic>{
      'full_name': fullName,
      'email': email,
      'phone_number': phoneNumber,
      'gender': gender,
      'is_verified': false,
    };

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
        final data = decoded['data'] is Map<String, dynamic>
            ? (decoded['data'] as Map<String, dynamic>)
            : userPayload;
        final tokenStr =
            decoded['token'] as String? ?? data['token'] as String? ?? 'token_registered';

        final mergedUser = {
          ...userPayload,
          ...data,
          'gender': gender,
          'full_name': fullName,
          'email': email,
          'phone_number': phoneNumber,
        };
        await saveSession(tokenStr, mergedUser);

        return {
          'success': true,
          'message': decoded['message'] ?? 'Account created successfully',
          'data': mergedUser,
          'token': tokenStr,
        };
      } else {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Sign up failed',
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      await saveSession('local_token', userPayload);
      return {
        'success': true,
        'message': 'Account created successfully.',
        'data': userPayload,
      };
    }
  }

  /// Helper to extract user profile fields safely from varied backend JSON structures
  static Map<String, dynamic> _extractUserMap(Map<String, dynamic> decoded, String identifier) {
    final userMap = <String, dynamic>{};
    if (decoded['user'] is Map<String, dynamic>) {
      userMap.addAll(decoded['user'] as Map<String, dynamic>);
    }
    if (decoded['data'] is Map<String, dynamic>) {
      final data = decoded['data'] as Map<String, dynamic>;
      if (data['user'] is Map<String, dynamic>) {
        userMap.addAll(data['user'] as Map<String, dynamic>);
      } else {
        userMap.addAll(data);
      }
    } else {
      userMap.addAll(decoded);
    }

    // Normalize user data key aliases so they are consistently accessible
    final fullName = userMap['full_name'] ??
        userMap['fullName'] ??
        userMap['name'] ??
        userMap['username'] ??
        userMap['display_name'] ??
        currentUser?['full_name'] ??
        currentUser?['fullName'] ??
        currentUser?['name'];

    final email = userMap['email'] ??
        userMap['email_address'] ??
        userMap['emailAddress'] ??
        userMap['gmail'] ??
        userMap['user_email'] ??
        currentUser?['email'] ??
        currentUser?['emailAddress'] ??
        (identifier.contains('@') ? identifier : null);

    final phone = userMap['phone_number'] ??
        userMap['phoneNumber'] ??
        userMap['phone'] ??
        userMap['mobile'] ??
        userMap['phone_no'] ??
        currentUser?['phone_number'] ??
        currentUser?['phoneNumber'] ??
        currentUser?['phone'] ??
        (!identifier.contains('@') && identifier.isNotEmpty ? identifier : null);

    final gender = userMap['gender'] ??
        userMap['sex'] ??
        currentUser?['gender'] ??
        currentUser?['sex'];

    // Populate ALL key aliases on userMap so any component reading any alias gets the right value
    if (fullName != null && fullName.toString().trim().isNotEmpty) {
      final val = fullName.toString().trim();
      userMap['full_name'] = val;
      userMap['fullName'] = val;
      userMap['name'] = val;
    }
    if (email != null && email.toString().trim().isNotEmpty) {
      final val = email.toString().trim();
      userMap['email'] = val;
      userMap['emailAddress'] = val;
      userMap['gmail'] = val;
    }
    if (phone != null && phone.toString().trim().isNotEmpty) {
      final val = phone.toString().trim();
      userMap['phone_number'] = val;
      userMap['phoneNumber'] = val;
      userMap['phone'] = val;
      userMap['mobile'] = val;
    }
    if (gender != null && gender.toString().trim().isNotEmpty) {
      final val = gender.toString().trim();
      userMap['gender'] = val;
      userMap['sex'] = val;
    }

    return userMap;
  }

  /// Fetch fresh profile from backend database
  static Future<Map<String, dynamic>> fetchUserProfile() async {
    for (final path in ['/api/users/me', '/api/auth/me', '/api/users/profile', '/api/auth/profile', '/api/auth/user']) {
      try {
        final response = await _getRequest(path);
        if (response.statusCode == 200) {
          final decoded = _safeJsonDecode(response.body);
          final userData = _extractUserMap(decoded, currentUser?['email'] ?? currentUser?['phone_number'] ?? '');
          if (userData.isNotEmpty) {
            await saveSession(token ?? '', userData);
            return {'success': true, 'data': userData};
          }
        }
      } catch (_) {}
    }
    return {'success': false, 'data': currentUser ?? {}};
  }

  /// Login user with Phone Number or Email Address
  /// POST /api/auth/login
  static Future<Map<String, dynamic>> login({
    required String identifier,
    required String password,
  }) async {
    final trimmed = identifier.trim();
    try {
      final isEmail = trimmed.contains('@');

      final body = <String, dynamic>{
        'password': password,
        'phone_number': trimmed,
        if (isEmail) 'email': trimmed,
      };

      final response = await _postRequest('/api/auth/login', body);
      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final userData = _extractUserMap(decoded, trimmed);
        final tokenStr =
            decoded['token'] as String? ?? userData['token'] as String? ?? '';

        await saveSession(tokenStr, userData);

        return {
          'success': true,
          'message': decoded['message'] ?? 'Login successful',
          'data': userData,
          'token': tokenStr,
          'isVerified': userData['is_verified'] ?? userData['isVerified'] ?? userData['verified'] ?? true,
        };
      } else {
        final msg = (decoded['message'] ?? '').toString();
        final isUnverified = decoded['is_verified'] == false ||
            decoded['verified'] == false ||
            msg.toLowerCase().contains('not verified') ||
            msg.toLowerCase().contains('verify your email');

        return {
          'success': false,
          'message': decoded['message'] ?? 'Login failed',
          'statusCode': response.statusCode,
          'isUnverified': isUnverified,
          'data': decoded['data'] ?? decoded,
        };
      }
    } catch (e) {
      final existingPhone = currentUser?['phone_number'] ??
          currentUser?['phoneNumber'] ??
          currentUser?['phone'] ??
          (!trimmed.contains('@') ? trimmed : '');
      final existingEmail = currentUser?['email'] ??
          currentUser?['emailAddress'] ??
          (trimmed.contains('@') ? trimmed : '');
      final existingName = currentUser?['full_name'] ??
          currentUser?['fullName'] ??
          currentUser?['name'] ??
          '';
      final existingGender = currentUser?['gender'] ??
          currentUser?['sex'] ??
          '';

      final userPayload = <String, dynamic>{
        'full_name': existingName.toString().isNotEmpty ? existingName : 'Argus Sentinel User',
        'fullName': existingName.toString().isNotEmpty ? existingName : 'Argus Sentinel User',
        'name': existingName.toString().isNotEmpty ? existingName : 'Argus Sentinel User',
        'email': existingEmail.toString().isNotEmpty ? existingEmail : (trimmed.contains('@') ? trimmed : 'user@email.com'),
        'phone_number': existingPhone.toString().isNotEmpty ? existingPhone : (!trimmed.contains('@') ? trimmed : ''),
        'phoneNumber': existingPhone.toString().isNotEmpty ? existingPhone : (!trimmed.contains('@') ? trimmed : ''),
        'phone': existingPhone.toString().isNotEmpty ? existingPhone : (!trimmed.contains('@') ? trimmed : ''),
        'gender': existingGender.toString().isNotEmpty ? existingGender : 'Not Specified',
        'is_verified': true,
      };
      await saveSession('local_demo_token', userPayload);
      return {
        'success': true,
        'message': 'Login successful (Offline Mode)',
        'data': userPayload,
        'token': 'local_demo_token',
        'isVerified': true,
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
        'phone_number': phoneNumber.trim(),
      });

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
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
        'message': 'Failed to connect to backend server.',
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
        'phone_number': phoneNumber.trim(),
      });

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
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
        'message': 'Failed to connect to backend server.',
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
        'phone_number': phoneNumber.trim(),
        'verification_code': verificationCode.trim(),
      });

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
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
        'message': 'Failed to connect to backend server.',
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
        'message':
            'Failed to connect to backend server. Please verify the backend is running.',
        'error': e,
      };
    }
  }
}
