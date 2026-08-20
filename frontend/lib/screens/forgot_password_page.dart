import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../auth_flow.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordPage extends StatelessWidget {
  const ForgotPasswordPage({super.key, required this.onNavigate});
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) => AuthScaffold(
        child: Center(
            child: AuthCard(
                child: Column(children: [
          const Icon(Icons.lock_reset_outlined, color: AppTheme.red, size: 43),
          const SizedBox(height: 11),
          const AuthTitle('Forgot Password'),
          const AuthDescription(
              'Enter your phone number to receive a reset code.'),
          const SizedBox(height: 18),
          const AuthField(
              label: 'Phone Number',
              hint: '+27 82 123 4567',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
          AppButton(
              label: 'Send Reset Code',
              onPressed: () => onNavigate(AuthPage.verification)),
          const SizedBox(height: 25),
          AuthLink('←  Back to Login', onTap: () => onNavigate(AuthPage.login)),
        ]))),
      );
}
