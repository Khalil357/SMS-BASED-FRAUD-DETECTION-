import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'secure_signal_threats';
  static const String _channelName = 'Threat Alerts';
  static const String _channelDesc = 'Alerts regarding high threat phishing or scam SMS messages';

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle when user taps on notification
      },
    );

    final androidPlugin = _notificationsPlugin
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

  static Future<void> initialize() async {
    await init();
  }

  static Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
      try {
        if (await Permission.ignoreBatteryOptimizations.isDenied) {
          await Permission.ignoreBatteryOptimizations.request();
        }
      } catch (_) {}
      return await Permission.notification.isGranted;
    }
    return true;
  }

  static Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      return await Permission.notification.isGranted;
    }
    return true;
  }

  static Future<void> showThreatAlert({
    required String sender,
    required String message,
    required double threatLevel,
  }) async {
    try {
      await init(); // Self-initialize if running in background isolate

      final threatPercentage = (threatLevel * 100).toStringAsFixed(0);

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'Argus Threat Interceptor',
        playSound: true,
        enableVibration: true,
        styleInformation: BigTextStyleInformation(
          'Sender: $sender\nThreat Index: $threatPercentage%\n\nMessage:\n$message',
          contentTitle: '🚨 High Threat SMS Intercepted!',
          summaryText: 'Argus Security Shield',
        ),
      );

      final NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        '🚨 High Threat SMS Intercepted!',
        'From $sender (Threat Index: $threatPercentage%)',
        platformDetails,
      );
    } catch (_) {}
  }

  static Future<void> showThreatNotification({
    required String title,
    required String body,
  }) async {
    try {
      await init();

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      );

      const NotificationDetails platformDetails =
          NotificationDetails(android: androidDetails);

      await _notificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        platformDetails,
      );
    } catch (_) {}
  }
}
