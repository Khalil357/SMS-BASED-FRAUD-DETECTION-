import 'package:flutter/material.dart';
import 'services/sms_storage_service.dart';
import 'services/notification_service.dart';
import 'services/sms_ingestion_service.dart';

import 'app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize storage mocks if empty
  await SmsStorageService.initializeWithMocksIfNeeded();
  
  // Initialize local notifications
  await NotificationService.init();
  
  // Start SMS listener if permission has been granted
  final hasPerm = await SmsIngestionService.hasSmsPermission();
  if (hasPerm) {
    await SmsIngestionService.startListening();
  }
  
  runApp(const SecureSignalApp());
}

class SecureSignalApp extends StatefulWidget {
  const SecureSignalApp({super.key});

  @override
  State<SecureSignalApp> createState() => SecureSignalAppState();

  static SecureSignalAppState of(BuildContext context) =>
      context.findAncestorStateOfType<SecureSignalAppState>()!;
}

class SecureSignalAppState extends State<SecureSignalApp> {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Argus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: _themeMode,
      home: const SplashScreen(),
    );
  }
}
