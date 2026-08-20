import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../auth_flow.dart';
import '../widgets/auth_widgets.dart';

class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key, required this.onNavigate});
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) => AuthScaffold(
        child: Center(
            child: AuthCard(
                topAccent: true,
                child: Column(children: [
                  const Icon(Icons.mark_email_read_outlined,
                      color: AppTheme.red, size: 42),
                  const SizedBox(height: 11),
                  const AuthTitle('Verify Your Code'),
                  const AuthDescription(
                      "We've sent a 6-digit verification code\nto\n",
                      trailing: 'j.doe@example.com'),
                  const SizedBox(height: 17),
                  const OtpFields(),
                  const SizedBox(height: 27),
                  AppButton(
                      label: 'Verify',
                      onPressed: () => onNavigate(AuthPage.resetPassword)),
                  const SizedBox(height: 19),
                  AuthPrompt(
                      prefix: "Didn't receive the code? ",
                      link: 'Resend Code',
                      onTap: () {}),
                ]))),
      );
}
