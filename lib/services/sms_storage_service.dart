import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SmsStorageService {
  static const String keySmsLogs = 'argus_sms_logs';
  static const String keyIngestionEnabled = 'settings_ingestion_enabled';
  static const String keyNotificationsEnabled = 'settings_notifications_enabled';
  static const String keyNotificationThreshold = 'settings_notification_threshold';
  static const String keyIsScanned = 'is_scanned';
  static const String keyScannedAt = 'scanned_at';
  static const String keySource = 'source';
  static const String keyIsTrainedModel = 'is_trained_model';
  static const String keyScanVerdict = 'scan_verdict';
  static const String keyBlockedNumbers = 'argus_blocked_numbers';

  static Future<SharedPreferences> _getPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.reload();
    } catch (_) {
    }
    return prefs;
  }

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

  static Future<void> addLog(Map<String, dynamic> log) async {
    final prefs = await _getPrefs();
    final logs = await getLogs();

    final exists = logs.any((l) => l['id'] == log['id'] ||
        (l['sender'] == log['sender'] &&
            l['message'] == log['message'] &&
            l['time'] == log['time']));
    if (exists) return;

    logs.insert(0, log);
    await prefs.setString(keySmsLogs, jsonEncode(logs));
  }

  static Future<void> submitFeedback({required String logId, required String feedbackType}) async {
    final prefs = await _getPrefs();
    final logs = await getLogs();

    for (int i = 0; i < logs.length; i++) {
      if (logs[i]['id'] == logId) {
        logs[i]['hasFeedback'] = true;
        logs[i]['userFeedback'] = feedbackType;
        logs[i]['type'] = feedbackType;
        break;
      }
    }
    await prefs.setString(keySmsLogs, jsonEncode(logs));
  }

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

  static String normalizeNumber(String number) {
    String digits = number.replaceAll(RegExp(r'[\s\-()]+'), '');
    if (!digits.startsWith('+')) {
      digits = '+$digits';
    }
    return digits;
  }

  static Future<List<String>> getBlockedNumbers() async {
    final entries = await getBlockedNumberEntries();
    return entries.map((e) => e['number'] ?? '').where((n) => n.isNotEmpty).toList();
  }

  static Future<List<Map<String, String>>> getBlockedNumberEntries() async {
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(keyBlockedNumbers);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      final entries = <Map<String, String>>[];
      for (final item in decoded) {
        if (item is Map) {
          final number = normalizeNumber((item['number'] ?? '').toString());
          if (number.length < 8) continue;
          entries.add({
            'number': number,
            'reason': (item['reason'] ?? '').toString(),
            'date': (item['date'] ?? '').toString(),
          });
        } else {
          final number = normalizeNumber(item.toString());
          if (number.length < 8) continue;
          entries.add({'number': number, 'reason': '', 'date': ''});
        }
      }
      return entries;
    } catch (_) {
      return [];
    }
  }

  static Future<void> addBlockedNumber(String phoneNumber, {String? reason}) async {
    final normalized = normalizeNumber(phoneNumber);
    final entries = await getBlockedNumberEntries();
    if (entries.any((e) => e['number'] == normalized)) return;
    entries.insert(0, {
      'number': normalized,
      'reason': reason ?? 'User blocked',
      'date': DateTime.now().toIso8601String().split('T').first,
    });
    final prefs = await _getPrefs();
    await prefs.setString(keyBlockedNumbers, jsonEncode(entries));
  }

  static Future<void> removeBlockedNumber(String phoneNumber) async {
    final normalized = normalizeNumber(phoneNumber);
    final entries = await getBlockedNumberEntries();
    entries.removeWhere((e) => e['number'] == normalized);
    final prefs = await _getPrefs();
    await prefs.setString(keyBlockedNumbers, jsonEncode(entries));
  }

  static Future<bool> isNumberBlocked(String phoneNumber) async {
    final normalized = normalizeNumber(phoneNumber);
    final blocked = await getBlockedNumbers();
    return blocked.contains(normalized);
  }
}
