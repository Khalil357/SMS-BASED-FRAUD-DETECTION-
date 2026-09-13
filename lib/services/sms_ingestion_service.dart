import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sms_detection_service.dart';
import 'sms_storage_service.dart';
import 'notification_service.dart';
import 'auth_service.dart';

@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final body = message.body ?? '';
  final sender = message.address ?? 'Unknown';

  if (body.isEmpty) return;

  try {
    // Run local analysis as baseline
    final result = SmsDetectionService.analyze(message: body, sender: sender);

    // Prepare log entry
    final logEntry = <String, dynamic>{
      'id': 'auto_${DateTime.now().millisecondsSinceEpoch}_${message.id ?? 0}',
      'sender': sender,
      'message': body,
      'type': result.classification,
      'time': DateTime.now().toIso8601String(),
      'threat': result.threatLevel,
      'matchedReasons': List<String>.from(result.matchedReasons),
      'hasFeedback': false,
      'userFeedback': null,
    };

    // Submit scan payload to Backend API (POST /api/scans)
    try {
      final backendResult = await AuthService.submitScan(
        sender: sender,
        messageBody: body,
        source: 'AUTO_LISTENER',
      );
      if (backendResult['success'] == true && backendResult['isScam'] != null) {
        final isScam = backendResult['isScam'] == true;
        final conf = (backendResult['confidence'] as num?)?.toDouble() ?? result.threatLevel;
        logEntry['type'] = isScam ? 'Fraud' : (result.classification == 'Spam' ? 'Spam' : 'Safe');
        logEntry['threat'] = conf;
        if (backendResult['label'] != null) {
          (logEntry['matchedReasons'] as List).add('Backend ML Model: ${backendResult['label']} (${(conf * 100).toStringAsFixed(1)}% confidence)');
        }
      }
    } catch (_) {}

    // Add to storage
    await SmsStorageService.addLog(logEntry);

    // Always trigger notification for Fraud / Spam / Threat Index >= 0.50
    final threatLevel = (logEntry['threat'] as num).toDouble();
    if (logEntry['type'] == 'Fraud' || logEntry['type'] == 'Spam' || threatLevel >= 0.50) {
      await NotificationService.initialize();
      await NotificationService.showThreatNotification(
        title: '🚨 High Threat SMS Detected',
        body: 'From $sender: ${logEntry['type']} Risk (${(threatLevel * 100).toStringAsFixed(0)}% Threat Index)',
      );
    }
  } catch (e) {
    debugPrint("Background SMS Handler Error: $e");
  }
}

class SmsIngestionService {
  static final Telephony _telephony = Telephony.instance;
  static final StreamController<Map<String, dynamic>> _smsStreamController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get smsStream => _smsStreamController.stream;

  static Future<bool> hasSmsPermission() async {
    return await Permission.sms.isGranted;
  }

  static Future<bool> requestSmsPermission() async {
    final status = await Permission.sms.request();
    return status.isGranted;
  }

  static Future<void> startListening() async {
    final hasPerm = await hasSmsPermission();
    if (!hasPerm) return;

    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        final body = message.body ?? '';
        final sender = message.address ?? 'Unknown';

        if (body.isEmpty) return;

        final result = SmsDetectionService.analyze(message: body, sender: sender);

        final logEntry = <String, dynamic>{
          'id': 'auto_${DateTime.now().millisecondsSinceEpoch}_${message.id ?? 0}',
          'sender': sender,
          'message': body,
          'type': result.classification,
          'time': DateTime.now().toIso8601String(),
          'threat': result.threatLevel,
          'matchedReasons': result.matchedReasons,
          'hasFeedback': false,
          'userFeedback': null,
        };

        // Submit scan payload to Backend API (POST /api/scans)
        try {
          final backendResult = await AuthService.submitScan(
            sender: sender,
            messageBody: body,
            source: 'AUTO_LISTENER',
          );
          if (backendResult['success'] == true && backendResult['isScam'] != null) {
            final isScam = backendResult['isScam'] == true;
            final conf = (backendResult['confidence'] as num?)?.toDouble() ?? result.threatLevel;
            logEntry['type'] = isScam ? 'Fraud' : (result.classification == 'Spam' ? 'Spam' : 'Safe');
            logEntry['threat'] = conf;
            if (backendResult['label'] != null) {
              (logEntry['matchedReasons'] as List).add('Backend ML Model: ${backendResult['label']} (${(conf * 100).toStringAsFixed(1)}% confidence)');
            }
          }
        } catch (_) {}

        await SmsStorageService.addLog(logEntry);
        _smsStreamController.add(logEntry);

        final isNotificationsEnabled = await SmsStorageService.getBoolSetting(
            SmsStorageService.keyNotificationsEnabled, true);
        final notificationThreshold = await SmsStorageService.getDoubleSetting(
            SmsStorageService.keyNotificationThreshold, 0.80);

        final threatLevel = (logEntry['threat'] as num).toDouble();
        if (isNotificationsEnabled && threatLevel >= notificationThreshold) {
          await NotificationService.showThreatNotification(
            title: '🚨 High Threat SMS Detected',
            body: 'From $sender: ${logEntry['type']} Risk (${(threatLevel * 100).toStringAsFixed(0)}% Threat Index)',
          );
        }
      },
      onBackgroundMessage: backgroundSmsHandler,
    );
  }
}
