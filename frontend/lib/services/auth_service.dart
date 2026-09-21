import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  /// Build-time override, e.g.:
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.25:8080
  static const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Optional secondary host probed only when [baseUrl] is unreachable. Useful
  /// for a physical phone: use the dev machine's LAN IP, or 127.0.0.1 when the
  /// port is forwarded over USB with `adb reverse tcp:8080 tcp:8080`.
  static const String _envApiFallbackUrl = String.fromEnvironment('API_FALLBACK_URL');

  /// Default server base URL. Override at build time with
  /// `flutter run --dart-define=API_BASE_URL=...`; otherwise the deployed
  /// backend on AWS EC2 is used.
  static String get defaultServerBaseUrl {
    final override = _envApiBaseUrl.trim();
    if (override.isNotEmpty) return override;
    return 'https://54.242.107.64';
  }

  /// Custom backend URL override (e.g. https://54.242.107.64)
  static String? customBaseUrl;

  /// Dynamic baseUrl getter
  static String get baseUrl {
    if (customBaseUrl != null && customBaseUrl!.trim().isNotEmpty) {
      return customBaseUrl!.trim().replaceAll(RegExp(r'/$'), '');
    }
    return defaultServerBaseUrl;
  }

  /// Ordered fallback hosts probed only when [baseUrl] is unreachable.
  static List<String> get _fallbackHosts {
    final base = baseUrl.replaceAll(RegExp(r'/$'), '');
    return <String>[
      if (_envApiFallbackUrl.trim().isNotEmpty) _envApiFallbackUrl.trim(),
      if (Platform.isAndroid) 'http://10.0.2.2:8080',
      'http://localhost:8080',
    ]
        .map((h) => h.replaceAll(RegExp(r'/$'), ''))
        .where((h) => h != base)
        .toList();
  }

  static List<String> _requestUrls(String path) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return <String>[
      _buildUrl(path),
      for (final host in _fallbackHosts) '$host$cleanPath',
    ];
  }

  static Future<http.Response> _sendWithFallback(
    List<String> urls,
    Future<http.Response> Function(String url) send,
  ) async {
    Object? lastError;
    for (var i = 0; i < urls.length; i++) {
      final url = urls[i];
      final timeout = Duration(seconds: i == 0 ? 10 : 6);
      try {
        return await send(url).timeout(timeout);
      } catch (e) {
        lastError = e;
        debugPrint('[AuthService] Request failed for $url ($e). '
            '${i < urls.length - 1 ? 'Trying next host.' : ''}');
      }
    }
    throw lastError ?? StateError('No backend host resolved for $urls');
  }

  /// Helper to construct full request URL from base URL and path
  static String _buildUrl(String path) {
    final base = baseUrl.replaceAll(RegExp(r'/$'), '');
    var cleanPath = path.trim();
    if (!cleanPath.startsWith('/')) {
      cleanPath = '/$cleanPath';
    }
    if (!base.endsWith('/api') && !cleanPath.startsWith('/api/') && cleanPath != '/api') {
      cleanPath = '/api$cleanPath';
    }
    return '$base$cleanPath';
  }

  /// Normalizes backend & local scan data maps so snake_case & camelCase fields
  /// are uniformly accessible throughout the Flutter app.
  static Map<String, dynamic> normalizeScan(Map<String, dynamic> scan) {
    final rawScanId = scan['scanId'] ?? scan['scan_id'] ?? scan['id'] ?? scan['backendId'];
    final scanIdStr = rawScanId?.toString();
    final messageBody = scan['messageBody'] ?? scan['message_body'] ?? scan['message'] ?? '';
    final scannedAt = scan['scannedAt'] ?? scan['scanned_at'] ?? scan['time'] ?? scan['date'] ?? DateTime.now().toIso8601String();

    final isScamBool = scan['isScam'] == true ||
        scan['is_scam'] == true ||
        scan['label'] == 'scam' ||
        scan['label'] == 'fraud' ||
        scan['type'] == 'Fraud';
    final typeStr = scan['type'] ?? (isScamBool ? 'Fraud' : 'Safe');

    return {
      ...scan,
      'scanId': scanIdStr,
      'scan_id': scanIdStr,
      'id': scan['id'] ?? scanIdStr,
      'backendId': scan['backendId'] ?? scanIdStr,
      'messageBody': messageBody,
      'message_body': messageBody,
      'message': messageBody,
      'scannedAt': scannedAt,
      'scanned_at': scannedAt,
      'time': scannedAt,
      'isScam': isScamBool,
      'is_scam': isScamBool,
      'userId': scan['userId'] ?? scan['user_id'],
      'user_id': scan['userId'] ?? scan['user_id'],
      'sender': scan['sender'] ?? scan['sender_number'] ?? scan['senderNumber'] ?? 'Unknown',
      'type': typeStr,
    };
  }

  // Session variables & Storage Keys
  static Map<String, dynamic>? currentUser;
  static String? token;

  static const String _keyToken = 'auth_token_v1';
  static const String _keyUser = 'auth_user_v1';
  static const String _keyUnverifiedIdentifiers = 'unverified_identifiers_v1';

  static final Set<String> _unverifiedIdentifiers = {};

  static final StreamController<bool> _sessionExpiredController =
      StreamController<bool>.broadcast();

  /// Emits `true` when the backend rejects an access token (HTTP 401), so the
  /// UI can bounce the user back to the login screen.
  static Stream<bool> get sessionExpiredStream =>
      _sessionExpiredController.stream;

  static Future<void> _handleUnauthorized(http.Response response) async {
    if (response.statusCode == 401) {
      await logout();
      _sessionExpiredController.add(true);
    }
  }

  static void markIdentifierUnverified(String identifier) {
    if (identifier.trim().isEmpty) return;
    final clean = identifier.trim().toLowerCase();
    _unverifiedIdentifiers.add(clean);
    _saveUnverifiedIdentifiers();
  }

  static void markIdentifierVerified(String identifier) {
    if (identifier.trim().isEmpty) return;
    final clean = identifier.trim().toLowerCase();
    _unverifiedIdentifiers.remove(clean);

    if (currentUser != null) {
      final email = (currentUser!['email'] ?? currentUser!['emailAddress'])?.toString().trim().toLowerCase();
      final phone = (currentUser!['phone_number'] ?? currentUser!['phoneNumber'] ?? currentUser!['phone'])?.toString().trim().toLowerCase();
      if (email != null && email.isNotEmpty) _unverifiedIdentifiers.remove(email);
      if (phone != null && phone.isNotEmpty) _unverifiedIdentifiers.remove(phone);
    }
    _saveUnverifiedIdentifiers();
  }

  static bool isIdentifierUnverified(String identifier) {
    if (identifier.trim().isEmpty) return false;
    final clean = identifier.trim().toLowerCase();
    return _unverifiedIdentifiers.contains(clean);
  }

  static Future<void> _saveUnverifiedIdentifiers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_keyUnverifiedIdentifiers, _unverifiedIdentifiers.toList());
    } catch (_) {}
  }

  static Future<void> _loadUnverifiedIdentifiers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyUnverifiedIdentifiers);
      if (list != null) {
        _unverifiedIdentifiers.addAll(list);
      }
    } catch (_) {}
  }

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
      await _loadUnverifiedIdentifiers();
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final savedToken = prefs.getString(_keyToken);
      final savedUserJson = prefs.getString(_keyUser);

      if (savedUserJson != null && savedUserJson.isNotEmpty) {
        token = (savedToken != null && savedToken.isNotEmpty)
            ? savedToken
            : 'auth_session_active';
        currentUser = jsonDecode(savedUserJson) as Map<String, dynamic>;
        return true;
      }
    } catch (e) {
      debugPrint("Load Session error: $e");
    }
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
    final urls = _requestUrls(path);
    debugPrint('[AuthService] POST primary: ${urls.first}');

    final response = await _sendWithFallback(urls, (url) async {
      return http.post(Uri.parse(url), headers: headers, body: encodedBody);
    });
    await _handleUnauthorized(response);
    return response;
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
    final urls = _requestUrls(path);
    debugPrint('[AuthService] GET primary: ${urls.first}');

    final response = await _sendWithFallback(urls, (url) async {
      return http.get(Uri.parse(url), headers: headers);
    });
    await _handleUnauthorized(response);
    return response;
  }

  /// Helper to send DELETE requests with the same host fallback as other calls.
  static Future<http.Response> _deleteRequest(String path) async {
    final headers = {
      'Content-Type': 'application/json',
      if (token != null && token!.trim().isNotEmpty) 'Authorization': formattedAuthorization,
    };
    final urls = _requestUrls(path);
    debugPrint('[AuthService] DELETE primary: ${urls.first}');

    final response = await _sendWithFallback(urls, (url) async {
      return http.delete(Uri.parse(url), headers: headers);
    });
    await _handleUnauthorized(response);
    return response;
  }

  /// Public generic request helpers (used by scan_service).
  static Future<http.Response> get(String path) => _getRequest(path);
  static Future<http.Response> post(String path, Map<String, dynamic> body) =>
      _postRequest(path, body);
  static Future<http.Response> delete(String path) => _deleteRequest(path);

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

      debugPrint("[Argus Scan Endpoint] POST ${_buildUrl('/api/scans')} | sender: $sender, source: $source");
      final response = await _postRequest('/api/scans', body);
      debugPrint("[Argus Scan Endpoint] Status: ${response.statusCode} | Response: ${response.body}");
      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final rawData = decoded['data'] is Map<String, dynamic>
            ? (decoded['data'] as Map<String, dynamic>)
            : decoded;
        final data = normalizeScan(rawData);

        final isScam = data['isScam'] == true;
        final label = data['label'] ?? (isScam ? 'scam' : 'safe');
        final confidence = (data['confidence'] as num?)?.toDouble() ?? 0.95;

        return {
          'success': true,
          'message': decoded['message'] ?? 'Scan submitted successfully',
          'data': data,
          'scanId': data['scanId'],
          'scan_id': data['scan_id'],
          'isScam': isScam,
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
      debugPrint("[Argus Scan Exception] $e");
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
          await get('/api/scans/fraud?page=$page&size=$size');
      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200) {
        final data = decoded['data'] is Map<String, dynamic>
            ? (decoded['data'] as Map<String, dynamic>)
            : <String, dynamic>{};
        final rawContent =
            data['content'] is List ? (data['content'] as List) : [];
        final content = rawContent
            .whereType<Map<String, dynamic>>()
            .map((item) => normalizeScan(item))
            .toList();

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
      debugPrint("[Argus Fraud Scans Exception] $e");
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
      final response1 = await delete(path1);
      print("[Argus Delete Fraud Record] Status: ${response1.statusCode} | Body: ${response1.body}");

      if (response1.statusCode == 200 || response1.statusCode == 204 || response1.statusCode == 404) {
        return {
          'success': true,
          'message': 'Record removed from the backend database.',
        };
      }

      final path2 = '/api/scans/fraud/${Uri.encodeComponent(scanId)}';
      final response2 = await delete(path2);
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
    markIdentifierUnverified(email);
    markIdentifierUnverified(phoneNumber);

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
          'is_verified': false,
        };

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

    if (currentUser != null && currentUser!.isNotEmpty) {
      currentUser!.forEach((k, v) {
        if (v != null && v.toString().trim().isNotEmpty) {
          userMap.putIfAbsent(k, () => v);
        }
      });
    }

    // Normalize user data key aliases so they are consistently accessible
    final fullName = userMap['full_name'] ??
        userMap['fullName'] ??
        userMap['name'] ??
        userMap['username'] ??
        userMap['display_name'] ??
        currentUser?['full_name'] ??
        currentUser?['fullName'] ??
        currentUser?['name'] ??
        '';

    final email = userMap['email'] ??
        userMap['email_address'] ??
        userMap['emailAddress'] ??
        userMap['gmail'] ??
        userMap['user_email'] ??
        currentUser?['email'] ??
        currentUser?['emailAddress'] ??
        (identifier.contains('@') ? identifier : '');

    final phone = userMap['phone_number'] ??
        userMap['phoneNumber'] ??
        userMap['phone'] ??
        userMap['mobile'] ??
        userMap['phone_no'] ??
        currentUser?['phone_number'] ??
        currentUser?['phoneNumber'] ??
        currentUser?['phone'] ??
        (!identifier.contains('@') && identifier.isNotEmpty ? identifier : '');

    final gender = userMap['gender'] ??
        userMap['sex'] ??
        currentUser?['gender'] ??
        currentUser?['sex'] ??
        '';

    final nameVal = fullName.toString().trim();
    final emailVal = email.toString().trim();
    final phoneVal = phone.toString().trim();
    final genderVal = gender.toString().trim();

    userMap['full_name'] = nameVal;
    userMap['fullName'] = nameVal;
    userMap['name'] = nameVal;

    userMap['email'] = emailVal;
    userMap['emailAddress'] = emailVal;
    userMap['gmail'] = emailVal;

    userMap['phone_number'] = phoneVal;
    userMap['phoneNumber'] = phoneVal;
    userMap['phone'] = phoneVal;

    userMap['gender'] = genderVal;
    userMap['sex'] = genderVal;

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

        final rawVerified = userData['is_verified'] ??
            userData['isVerified'] ??
            userData['verified'] ??
            decoded['is_verified'] ??
            decoded['isVerified'];

        final bool isExplicitlyVerified = rawVerified == true ||
            rawVerified == 1 ||
            rawVerified == 'true' ||
            rawVerified == '1';

        final bool isExplicitlyUnverified = rawVerified == false ||
            rawVerified == 0 ||
            rawVerified == 'false' ||
            rawVerified == '0' ||
            rawVerified == 'unverified';

        final bool isLocallyUnverified = isIdentifierUnverified(trimmed);
        final bool hasNoToken = tokenStr.trim().isEmpty || tokenStr == 'token_registered';

        final bool isUnverified = isExplicitlyUnverified ||
            isLocallyUnverified ||
            hasNoToken ||
            !isExplicitlyVerified;

        if (isUnverified) {
          return {
            'success': false,
            'message': 'Account is not verified. Please verify your OTP to log in.',
            'statusCode': 403,
            'isUnverified': true,
            'data': userData,
          };
        }

        markIdentifierVerified(trimmed);
        userData['is_verified'] = true;
        await saveSession(tokenStr, userData);

        return {
          'success': true,
          'message': 'Login successful',
          'data': userData,
          'token': tokenStr,
          'isVerified': true,
        };
      } else {
        final msg = (decoded['message'] ?? '').toString();
        final rawVerified = decoded['is_verified'] ?? decoded['verified'] ?? decoded['data']?['is_verified'];
        final isUnverified = isIdentifierUnverified(trimmed) ||
            rawVerified == false ||
            rawVerified == 0 ||
            rawVerified == 'false' ||
            msg.toLowerCase().contains('not verified') ||
            msg.toLowerCase().contains('verify your email') ||
            msg.toLowerCase().contains('otp');

        return {
          'success': false,
          'message': decoded['message'] ?? 'Login failed',
          'statusCode': response.statusCode,
          'isUnverified': isUnverified,
          'data': decoded['data'] ?? decoded,
        };
      }
    } catch (e) {
      debugPrint("[AuthService Login Exception] $e");
      return {
        'success': false,
        'message': 'Unable to connect to the backend server.',
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

  /// Verify reset / registration OTP code against remote server
  /// POST /api/auth/password-resets/verify & POST /api/auth/verify-login-otp
  static Future<Map<String, dynamic>> verifyResetCode({
    required String phoneNumber,
    required String verificationCode,
  }) async {
    final cleanIdentifier = phoneNumber.trim();
    final cleanCode = verificationCode.trim();

    // 1. Try POST /api/auth/password-resets/verify
    try {
      final response = await _postRequest('/api/auth/password-resets/verify', {
        'phone_number': cleanIdentifier,
        'email': cleanIdentifier,
        'verification_code': cleanCode,
      });

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        markIdentifierVerified(cleanIdentifier);
        return {
          'success': true,
          'message': decoded['message'] ?? 'Code verified successfully',
          'data': decoded['data'] ?? decoded,
        };
      }
    } catch (_) {}

    // 2. Try POST /api/auth/verify-login-otp
    try {
      final response = await _postRequest('/api/auth/verify-login-otp', {
        'email': cleanIdentifier,
        'phone_number': cleanIdentifier,
        'verificationCode': cleanCode,
        'verification_code': cleanCode,
      });

      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        markIdentifierVerified(cleanIdentifier);
        final data = _extractUserMap(decoded, cleanIdentifier);
        final tokenStr = decoded['token'] as String? ?? data['token'] as String? ?? '';
        if (tokenStr.isNotEmpty) {
          await saveSession(tokenStr, data);
        }
        return {
          'success': true,
          'message': decoded['message'] ?? 'Code verified successfully',
          'data': decoded['data'] ?? decoded,
        };
      }
    } catch (_) {}

    return {
      'success': false,
      'message': 'Invalid verification code. Please check the code and try again.',
    };
  }

  /// Verify the OTP issued after an unverified user attempts to log in.
  /// This endpoint both marks the account verified and returns a real JWT.
  static Future<Map<String, dynamic>> verifyLoginOtp({
    required String identifier,
    required String verificationCode,
  }) async {
    final cleanIdentifier = identifier.trim();
    try {
      final response = await _postRequest('/api/auth/verify-login-otp', {
        'email': cleanIdentifier,
        'verificationCode': verificationCode.trim(),
      });
      final decoded = _safeJsonDecode(response.body);

      if (response.statusCode != 200 && response.statusCode != 201) {
        return {
          'success': false,
          'message': decoded['message'] ?? 'Invalid or expired verification code.',
        };
      }

      final userData = _extractUserMap(decoded, cleanIdentifier);
      final tokenStr = (decoded['token'] ?? userData['token'] ?? '').toString();
      if (tokenStr.isEmpty) {
        return {
          'success': false,
          'message': 'Verification succeeded, but no login token was returned.',
        };
      }

      userData['is_verified'] = true;
      markIdentifierVerified(cleanIdentifier);
      await saveSession(tokenStr, userData);
      return {
        'success': true,
        'message': decoded['message'] ?? 'Account verified successfully.',
        'data': userData,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to the backend server.',
        'error': e,
      };
    }
  }

  /// Resend the OTP for an account that is blocked at login until verified.
  static Future<Map<String, dynamic>> resendLoginOtp({
    required String identifier,
  }) async {
    try {
      final response = await _postRequest('/api/auth/resend-login-otp', {
        'email': identifier.trim(),
      });
      final decoded = _safeJsonDecode(response.body);
      return {
        'success': response.statusCode == 200 || response.statusCode == 201,
        'message': decoded['message'] ??
            (response.statusCode == 200 ? 'Verification code resent.' : 'Failed to resend verification code.'),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Unable to connect to the backend server.',
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