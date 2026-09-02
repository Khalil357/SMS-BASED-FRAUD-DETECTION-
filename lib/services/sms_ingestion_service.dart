import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sms_detection_service.dart';
import 'sms_storage_service.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final body = message.body ?? '';
  final sender = message.address ?? 'Unknown';

  if (body.isEmpty) return;

  // Run analysis
  final result = SmsDetectionService.analyze(message: body, sender: sender);

  // Prepare log entry
  final logEntry = {
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

  // Add to storage
  await SmsStorageService.addLog(logEntry);

  // Trigger notification if threshold exceeded
  final isNotificationsEnabled = await SmsStorageService.getBoolSetting(
      SmsStorageService.keyNotificationsEnabled, true);
  final notificationThreshold = await SmsStorageService.getDoubleSetting(
      SmsStorageService.keyNotificationThreshold, 0.80);

  if (isNotificationsEnabled && result.threatLevel >= notificationThreshold) {
    await NotificationService.initialize();
    await NotificationService.showThreatNotification(
      title: '🚨 High Threat SMS Detected',
      body: 'From $sender: ${result.classification} Risk (${(result.threatLevel * 100).toStringAsFixed(0)}% Threat Index)',
    );
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

        final logEntry = {
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

        await SmsStorageService.addLog(logEntry);
        _smsStreamController.add(logEntry);

        final isNotificationsEnabled = await SmsStorageService.getBoolSetting(
            SmsStorageService.keyNotificationsEnabled, true);
        final notificationThreshold = await SmsStorageService.getDoubleSetting(
            SmsStorageService.keyNotificationThreshold, 0.80);

        if (isNotificationsEnabled && result.threatLevel >= notificationThreshold) {
          await NotificationService.showThreatNotification(
            title: '🚨 High Threat SMS Detected',
            body: 'From $sender: ${result.classification} Risk (${(result.threatLevel * 100).toStringAsFixed(0)}% Threat Index)',
          );
        }
      },
      onBackgroundMessage: backgroundSmsHandler,
    );
  }
}
