import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'secure_signal_threats';
  static const String _channelName = 'Threat Alerts';
  static const String _channelDesc = 'Alerts for high-risk phishing or scam SMS messages.';

  /// Initialize notifications
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Optional: handle notification tap (e.g. navigate to logs)
      },
    );

    // Create high importance channel for Android 8.0+
    final androidPlugin = _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  /// Request runtime permission for notifications (Android 13+)
  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        final result = await Permission.notification.request();
        return result.isGranted;
      }
      return status.isGranted;
    }
    return true;
  }

  /// Check permission status
  static Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    }
    return true;
  }

  /// Show alert notification for high threat SMS
  static Future<void> showThreatAlert({
    required String sender,
    required String message,
    required double threatLevel,
  }) async {
    final hasPerm = await hasPermission();
    if (!hasPerm) {
      // Attempt to request if not yet asked
      final granted = await requestPermission();
      if (!granted) return;
    }

    final threatPercentage = (threatLevel * 100).toStringAsFixed(0);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      styleInformation: BigTextStyleInformation(
        'Sender: $sender\nThreat Index: $threatPercentage%\n\nMessage:\n$message',
        contentTitle: '🚨 High Threat SMS Detected!',
        summaryText: 'Security Alert',
      ),
    );

    final NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidDetails,
    );

    await _localNotificationsPlugin.show(
      // Unique notification id based on timestamp hash
      DateTime.now().millisecondsSinceEpoch.hashCode,
      '🚨 High Threat SMS Detected!',
      'Sender: $sender (Threat Index: $threatPercentage%)',
      platformChannelSpecifics,
    );
  }
}
