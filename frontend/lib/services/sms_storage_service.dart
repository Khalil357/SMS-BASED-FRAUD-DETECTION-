import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SmsStorageService {
  static const String _keyLogs = 'sms_logs_v1';
  static const String _keyFeedback = 'feedback_logs_v1';
  
  // Settings Keys
  static const String keyIngestionEnabled = 'settings_ingestion_enabled';
  static const String keyNotificationsEnabled = 'settings_notifications_enabled';
  static const String keyNotificationThreshold = 'settings_notification_threshold';

  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    try {
      await _prefs!.reload();
    } catch (_) {}
    return _prefs!;
  }

  /// Initialize default logs if storage is empty
  static Future<void> initializeWithMocksIfNeeded() async {
    final prefs = await _getPrefs();
    if (!prefs.containsKey(_keyLogs)) {
      final mockLogs = [
        {
          'id': 'mock_1',
          'sender': '+27821110000',
          'message': 'Congratulations! You have won a R5000 voucher from Woolworths. Click http://bit.ly/woolies-win to claim now!',
          'type': 'Fraud',
          'time': DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
          'threat': 0.95,
          'matchedReasons': [
            'Contains lottery/financial reward keywords (e.g. win, prize, voucher)',
            'Contains external hyperlink or link call-to-action'
          ],
          'hasFeedback': false,
          'userFeedback': null
        },
        {
          'id': 'mock_2',
          'sender': '+27832223333',
          'message': 'FNB Alert: A login attempt was made on your profile. If this was not you, please verify your details here: https://fnb-secure-login.info',
          'type': 'Fraud',
          'time': DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          'threat': 0.98,
          'matchedReasons': [
            'Account credential update/verification request',
            'Financial institution or login page reference',
            'Contains external hyperlink or link call-to-action'
          ],
          'hasFeedback': false,
          'userFeedback': null
        },
        {
          'id': 'mock_3',
          'sender': 'Absa Bank',
          'message': 'Your OTP is 492010. Do not share this code with anyone.',
          'type': 'Safe',
          'time': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
          'threat': 0.02,
          'matchedReasons': ['No suspicious patterns matched'],
          'hasFeedback': false,
          'userFeedback': null
        },
        {
          'id': 'mock_4',
          'sender': '+14150009999',
          'message': 'URGENT: Your parcel delivery is pending. Pay outstanding customs fee of \$1.50 immediately to avoid return: http://usps-tracking-fees.com',
          'type': 'Spam',
          'time': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'threat': 0.72,
          'matchedReasons': [
            'High urgency indicator ("urgent")',
            'Contains external hyperlink or link call-to-action'
          ],
          'hasFeedback': false,
          'userFeedback': null
        },
        {
          'id': 'mock_5',
          'sender': '+27829998888',
          'message': 'Hey, are we still meeting for coffee at 3pm today? Let me know.',
          'type': 'Safe',
          'time': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'threat': 0.00,
          'matchedReasons': ['No suspicious patterns matched'],
          'hasFeedback': false,
          'userFeedback': null
        },
      ];
      await saveLogs(mockLogs);
    }
  }

  /// Load all SMS logs
  static Future<List<Map<String, dynamic>>> getLogs() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(_keyLogs);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Overwrite logs list
  static Future<void> saveLogs(List<Map<String, dynamic>> logs) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyLogs, jsonEncode(logs));
  }

  /// Add a single log entry to the beginning of the list
  static Future<void> addLog(Map<String, dynamic> log) async {
    final logs = await getLogs();
    logs.insert(0, log);
    await saveLogs(logs);
  }

  /// Clear all logs
  static Future<void> clearLogs() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keyLogs);
  }

  /// Save Feedback and update the SMS log item classification
  static Future<void> submitFeedback({
    required String logId,
    required String feedbackType, // 'Safe', 'Spam', 'Fraud'
  }) async {
    final logs = await getLogs();
    final index = logs.indexWhere((element) => element['id'] == logId);
    
    if (index != -1) {
      final original = Map<String, dynamic>.from(logs[index]);
      final oldType = original['type'];
      original['hasFeedback'] = true;
      original['userFeedback'] = feedbackType;
      // Update classification in the logs page too to show user updated assessment
      original['type'] = feedbackType;
      
      logs[index] = original;
      await saveLogs(logs);

      // Create detailed feedback log entry for ML training
      final feedbackEntry = {
        'messageId': logId,
        'originalMessage': original['message'],
        'originalThreat': original['threat'],
        'originalClassification': oldType,
        'userFeedback': feedbackType,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _appendFeedbackLog(feedbackEntry);
    }
  }

  /// Append feedback log entry
  static Future<void> _appendFeedbackLog(Map<String, dynamic> entry) async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(_keyFeedback);
    List<Map<String, dynamic>> feedbackLogs = [];
    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        feedbackLogs = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      } catch (_) {}
    }
    feedbackLogs.insert(0, entry);
    await prefs.setString(_keyFeedback, jsonEncode(feedbackLogs));
  }

  /// Load all feedback logs (ready for Sprint 3 ML model ingestion)
  static Future<List<Map<String, dynamic>>> getFeedbackLogs() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(_keyFeedback);
    if (jsonStr == null) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return [];
    }
  }

  // --- SETTINGS MANAGEMENT ---

  static Future<bool> getBoolSetting(String key, bool defaultValue) async {
    final prefs = await _getPrefs();
    return prefs.getBool(key) ?? defaultValue;
  }

  static Future<void> saveBoolSetting(String key, bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(key, value);
  }

  static Future<double> getDoubleSetting(String key, double defaultValue) async {
    final prefs = await _getPrefs();
    return prefs.getDouble(key) ?? defaultValue;
  }

  static Future<void> saveDoubleSetting(String key, double value) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(key, value);
  }
}
