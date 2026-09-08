import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SmsStorageService {
  static const String keySmsLogs = 'argus_sms_logs';
  static const String keyIngestionEnabled = 'settings_ingestion_enabled';
  static const String keyNotificationsEnabled = 'settings_notifications_enabled';
  static const String keyNotificationThreshold = 'settings_notification_threshold';

  /// Helper to get the SharedPreferences instance and force a disk reload
  /// to sync background process writes with the foreground memory cache.
  static Future<SharedPreferences> _getPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload(); // CRITICAL: force reload from disk to sync background writes
    } catch (_) {
      // SharedPreferences reload can fail in tests or mock environments, ignore safely
    }
    return prefs;
  }

  /// Retrieve all logged SMS records
  static Future<List<Map<String, dynamic>>> getLogs() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(keySmsLogs);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Add a single SMS record to the top of the logs list
  static Future<void> addLog(Map<String, dynamic> log) async {
    final prefs = await _getPrefs();
    final logs = await getLogs();
    
    // Check for duplicates to prevent recording the same message twice
    final exists = logs.any((l) => l['id'] == log['id'] || 
        (l['sender'] == log['sender'] && 
         l['message'] == log['message'] && 
         l['time'] == log['time']));
    if (exists) return;

    logs.insert(0, log);
    await prefs.setString(keySmsLogs, jsonEncode(logs));
  }

  /// Submit correction feedback for a logged SMS
  static Future<void> submitFeedback({required String logId, required String feedbackType}) async {
    final prefs = await _getPrefs();
    final logs = await getLogs();
    
    for (int i = 0; i < logs.length; i++) {
      if (logs[i]['id'] == logId) {
        logs[i]['hasFeedback'] = true;
        logs[i]['userFeedback'] = feedbackType; // 'Safe', 'Spam', or 'Fraud'
        // Also update type to match user correction
        logs[i]['type'] = feedbackType;
        break;
      }
    }
    await prefs.setString(keySmsLogs, jsonEncode(logs));
  }

  // Boolean settings
  static Future<bool> getBoolSetting(String key, bool defaultValue) async {
    final prefs = await _getPrefs();
    return prefs.getBool(key) ?? defaultValue;
  }

  static Future<void> saveBoolSetting(String key, bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(key, value);
  }

  // Double settings
  static Future<double> getDoubleSetting(String key, double defaultValue) async {
    final prefs = await _getPrefs();
    return prefs.getDouble(key) ?? defaultValue;
  }

  static Future<void> saveDoubleSetting(String key, double value) async {
    final prefs = await _getPrefs();
    await prefs.setDouble(key, value);
  }
}
