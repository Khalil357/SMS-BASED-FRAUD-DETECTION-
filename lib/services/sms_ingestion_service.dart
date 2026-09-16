import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sms_detection_service.dart';
import 'sms_storage_service.dart';
import 'notification_service.dart';
import 'auth_service.dart';
import 'argus_scanner.dart';

@pragma('vm:entry-point')
Future<void> handleBackgroundSms(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();

  final body = message.body ?? '';
  final sender = message.address ?? 'Unknown';

  if (body.isEmpty) return;

  if (await SmsStorageService.isNumberBlocked(sender)) {
    return;
  }

  try {
    final argus = ArgusScanner();

    final result = await argus.scanSms(
      sender: sender,
      message: body,
      source: 'AUTO_LISTENER',
    );

    await SmsStorageService.addLog(result.toLogEntry());

    await argus.takeAction(result);
  } catch (e) {
    debugPrint("Background SMS Handler Error: $e");

    final body = message.body ?? '';
    final sender = message.address ?? 'Unknown';
    if (body.isEmpty) return;
    try {
      final result = SmsDetectionService.analyze(message: body, sender: sender);

      final logEntry = <String, dynamic>{
        'id': 'auto_${DateTime.now().millisecondsSinceEpoch}_${message.id ?? 0}',
        'sender': sender,
        'message': body,
        'type': result.classification,
        'time': DateTime.now().toIso8601String(),
        'threat': result.threatLevel,
        'matchedReasons': List<String>.from(result.matchedReasons),
        'isScanned': true,
        'hasFeedback': false,
        'userFeedback': null,
      };

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

      final threatLevel = (logEntry['threat'] as num).toDouble();
      if (logEntry['type'] == 'Fraud' || logEntry['type'] == 'Spam' || threatLevel >= 0.50) {
        await NotificationService.showThreatAlert(
          sender: sender,
          message: body,
          threatLevel: threatLevel,
        );
      }
    } catch (_) {}
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

        if (await SmsStorageService.isNumberBlocked(sender)) {
          return;
        }

        try {
          final argus = ArgusScanner();

          final result = await argus.scanSms(
            sender: sender,
            message: body,
            source: 'AUTO_LISTENER',
          );

          final logEntry = result.toLogEntry();

          await SmsStorageService.addLog(logEntry);
          _smsStreamController.add(logEntry);

          await argus.takeAction(result);
        } catch (e) {
          debugPrint("SMS Ingestion Error: $e");

          final result = SmsDetectionService.analyze(message: body, sender: sender);

          final logEntry = <String, dynamic>{
            'id': 'auto_${DateTime.now().millisecondsSinceEpoch}_${message.id ?? 0}',
            'sender': sender,
            'message': body,
            'type': result.classification,
            'time': DateTime.now().toIso8601String(),
            'threat': result.threatLevel,
            'matchedReasons': result.matchedReasons,
            'isScanned': true,
            'hasFeedback': false,
            'userFeedback': null,
          };

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
        }
      },
      onBackgroundMessage: handleBackgroundSms,
    );
  }
}
