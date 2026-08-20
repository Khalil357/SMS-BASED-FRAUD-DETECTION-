import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'auth_flow.dart';

void main() => runApp(const SecureSignalApp());

class SecureSignalApp extends StatelessWidget {
  const SecureSignalApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Secure Signal',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        home: const AuthFlow(),
      );
}
