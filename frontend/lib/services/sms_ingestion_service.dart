import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sms_detection_service.dart';
import 'sms_storage_service.dart';
import 'notification_service.dart';
import 'auth_service.dart';

/// Top-level background message handler required by Telephony.
/// Marked with @pragma('vm:entry-point') so the Dart compiler doesn't tree-shake it.
@pragma('vm:entry-point')
Future<void> handleBackgroundSms(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final body = message.body ?? '';
  final sender = message.address ?? 'Unknown';

  if (body.isEmpty) return;

  try {
    // 0. Ensure session token is loaded in background isolate
    await AuthService.loadSession();

    // 1. Perform rule-based threat analysis
    final result = SmsDetectionService.analyze(message: body, sender: sender);

    // 2. Persist the log entry locally
    final logEntry = <String, dynamic>{
      'id': 'auto_${DateTime.now().millisecondsSinceEpoch}',
      'sender': sender,
      'message': body,
      'type': result.classification,
      'time': DateTime.now().toIso8601String(),
      'threat': result.threatLevel,
      'matchedReasons': List<String>.from(result.matchedReasons),
      'hasFeedback': false,
      'userFeedback': null,
    };

    // 3. Submit scan to Backend API (POST /api/scans)
    try {
      final backendResult = await AuthService.submitScan(
        sender: sender,
        messageBody: body,
        source: 'AUTO_LISTENER',
      );
      if (backendResult['success'] == true && backendResult['isScam'] != null) {
        final isScam = backendResult['isScam'] == true || backendResult['is_scam'] == true;
        final conf = (backendResult['confidence'] as num?)?.toDouble() ?? result.threatLevel;
        final type = isScam ? 'Fraud' : (result.classification == 'Spam' ? 'Spam' : 'Safe');
        final threatLevel = (type == 'Safe') ? (1.0 - conf).clamp(0.0, 1.0) : conf.clamp(0.0, 1.0);

        logEntry['type'] = type;
        logEntry['threat'] = threatLevel;
        if (backendResult['label'] != null) {
          final confPct = (conf * 100).toStringAsFixed(1);
          final threatPct = (threatLevel * 100).toStringAsFixed(1);
          (logEntry['matchedReasons'] as List).add('Backend ML Model: ${backendResult['label']} ($confPct% confidence, $threatPct% threat index)');
        }
      }
    } catch (_) {}

    // 4. Add to local log storage
    await SmsStorageService.addLog(logEntry);

    // 5. Trigger alert notification for Fraud / Spam / Threat Index >= 0.50
    final threatLevel = (logEntry['threat'] as num).toDouble();
    if (logEntry['type'] == 'Fraud' || logEntry['type'] == 'Spam' || threatLevel >= 0.50) {
      await NotificationService.showThreatAlert(
        sender: sender,
        message: body,
        threatLevel: threatLevel,
      );
    }
  } catch (e) {
    debugPrint("Background SMS Handler Exception: $e");
  }
}

class SmsIngestionService {
  static final Telephony _telephony = Telephony.instance;
  
  // Stream to notify UI components of newly ingested foreground messages
  static final StreamController<Map<String, dynamic>> _smsStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  
  static Stream<Map<String, dynamic>> get smsStream => _smsStreamController.stream;

  /// Request SMS read and receive permissions (Android Only)
  static Future<bool> requestSmsPermission() async {
    if (!Platform.isAndroid) return false;
    
    // We request RECEIVE_SMS and READ_SMS
    final statusReceive = await Permission.sms.status;
    if (statusReceive.isDenied) {
      final result = await Permission.sms.request();
      return result.isGranted;
    }
    return statusReceive.isGranted;
  }

  /// Check if SMS permissions are granted
  static Future<bool> hasSmsPermission() async {
    if (!Platform.isAndroid) return false;
    return await Permission.sms.isGranted;
  }

  /// Initialize and start the Telephony SMS Listener
  static Future<void> startListening() async {
    if (!Platform.isAndroid) {
      debugPrint("SMS Ingestion: Not supported on this platform (Android Only).");
      return;
    }

    final hasPerm = await hasSmsPermission();
    if (!hasPerm) {
      debugPrint("SMS Ingestion: Cannot start listening, permission not granted.");
      return;
    }

    // Register listener
    try {
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          debugPrint("Foreground SMS received: ${message.body}");
          
          final body = message.body ?? '';
          final sender = message.address ?? 'Unknown';

          if (body.isEmpty) return;

          // Check if ingestion enabled
          final isIngestionEnabled = await SmsStorageService.getBoolSetting(
              SmsStorageService.keyIngestionEnabled, true);
          if (!isIngestionEnabled) return;

          // Analyze
          final result = SmsDetectionService.analyze(message: body, sender: sender);

          // Save
          final logEntry = {
            'id': 'auto_${DateTime.now().millisecondsSinceEpoch}',
            'sender': sender,
            'message': body,
            'type': result.classification,
            'time': DateTime.now().toIso8601String(),
            'threat': result.threatLevel,
            'matchedReasons': result.matchedReasons,
            'hasFeedback': false,
            'userFeedback': null,
          };
          // Submit scan to Backend API (POST /api/scans)
          try {
            final backendResult = await AuthService.submitScan(
              sender: sender,
              messageBody: body,
              source: 'AUTO_LISTENER',
            );
            if (backendResult['success'] == true && backendResult['isScam'] != null) {
              final isScam = backendResult['isScam'] == true || backendResult['is_scam'] == true;
              final conf = (backendResult['confidence'] as num?)?.toDouble() ?? result.threatLevel;
              final type = isScam ? 'Fraud' : (result.classification == 'Spam' ? 'Spam' : 'Safe');
              final threatLevel = (type == 'Safe') ? (1.0 - conf).clamp(0.0, 1.0) : conf.clamp(0.0, 1.0);

              logEntry['type'] = type;
              logEntry['threat'] = threatLevel;
              if (backendResult['label'] != null) {
                final confPct = (conf * 100).toStringAsFixed(1);
                final threatPct = (threatLevel * 100).toStringAsFixed(1);
                (logEntry['matchedReasons'] as List).add('Backend ML Model: ${backendResult['label']} ($confPct% confidence, $threatPct% threat index)');
              }
            }
          } catch (_) {}

          await SmsStorageService.addLog(logEntry);

          // Add to stream to notify foreground UI immediately
          _smsStreamController.add(logEntry);

          // Check alert threshold
          final isAlertEnabled = await SmsStorageService.getBoolSetting(
              SmsStorageService.keyNotificationsEnabled, true);
          final alertThreshold = await SmsStorageService.getDoubleSetting(
              SmsStorageService.keyNotificationThreshold, 0.80);

          final threatLevel = (logEntry['threat'] as num).toDouble();
          if (isAlertEnabled && threatLevel >= alertThreshold) {
            await NotificationService.showThreatAlert(
              sender: sender,
              message: body,
              threatLevel: threatLevel,
            );
          }
        },
        onBackgroundMessage: handleBackgroundSms,
      );
      debugPrint("SMS Ingestion: Background & Foreground listeners registered.");
    } catch (e) {
      debugPrint("SMS Ingestion Error: $e");
    }
  }
}
