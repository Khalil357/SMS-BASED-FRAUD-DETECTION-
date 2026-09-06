import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sms_detection_service.dart';
import 'sms_storage_service.dart';
import 'notification_service.dart';
import 'scan_service.dart';

/// Top-level background message handler required by Telephony.
/// Marked with @pragma('vm:entry-point') so the Dart compiler doesn't tree-shake it.
@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final body = message.body ?? '';
  final sender = message.address ?? 'Unknown';

  if (body.isEmpty) return;

  // 1. Check if background SMS ingestion is enabled in settings
  final isIngestionEnabled = await SmsStorageService.getBoolSetting(
      SmsStorageService.keyIngestionEnabled, true);
  if (!isIngestionEnabled) return;

  final remoteResult = await ScanService.queryMessage(
    messageBody: body,
    sender: sender,
    source: 'INCOMING_SMS',
  );
  final remoteData = remoteResult['success'] == true
      ? remoteResult['data'] as Map<String, dynamic>?
      : null;
  final localResult = SmsDetectionService.analyze(
    message: body,
    sender: sender,
  );
  final verdict = remoteData?['verdict']?.toString();
  final confidence = (remoteData?['confidence'] as num?)?.toDouble();

  final logEntry = {
    'id': 'auto_${DateTime.now().millisecondsSinceEpoch}',
    'sender': sender,
    'message': body,
    'type': verdict == 'FRAUD'
        ? 'Fraud'
        : verdict == 'SAFE'
            ? 'Safe'
            : localResult.classification,
    'time': DateTime.now().toIso8601String(),
    'threat': confidence ?? localResult.threatLevel,
    'matchedReasons': localResult.matchedReasons,
    'hasFeedback': false,
    'userFeedback': null,
  };
  await SmsStorageService.addLog(logEntry);

  final isAlertEnabled = await SmsStorageService.getBoolSetting(
      SmsStorageService.keyNotificationsEnabled, true);
  final alertThreshold = await SmsStorageService.getDoubleSetting(
      SmsStorageService.keyNotificationThreshold, 0.80);

  final threatLevel = (logEntry['threat'] as num).toDouble();
  if (isAlertEnabled && threatLevel >= alertThreshold) {
    await NotificationService.init();
    await NotificationService.showThreatAlert(
      sender: sender,
      message: body,
      threatLevel: threatLevel,
    );
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

          final remoteResult = await ScanService.queryMessage(
            messageBody: body,
            sender: sender,
            source: 'INCOMING_SMS',
          );
          final remoteData = remoteResult['success'] == true
              ? remoteResult['data'] as Map<String, dynamic>?
              : null;
          final localResult = SmsDetectionService.analyze(
            message: body,
            sender: sender,
          );
          final verdict = remoteData?['verdict']?.toString();
          final confidence = (remoteData?['confidence'] as num?)?.toDouble();
          final logEntry = {
            'id': 'auto_${DateTime.now().millisecondsSinceEpoch}',
            'sender': sender,
            'message': body,
            'type': verdict == 'FRAUD'
                ? 'Fraud'
                : verdict == 'SAFE'
                    ? 'Safe'
                    : localResult.classification,
            'time': DateTime.now().toIso8601String(),
            'threat': confidence ?? localResult.threatLevel,
            'matchedReasons': localResult.matchedReasons,
            'hasFeedback': false,
            'userFeedback': null,
          };
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
        onBackgroundMessage: backgroundSmsHandler,
      );
      debugPrint("SMS Ingestion: Background & Foreground listeners registered.");
    } catch (e) {
      debugPrint("SMS Ingestion Error: $e");
    }
  }
}
