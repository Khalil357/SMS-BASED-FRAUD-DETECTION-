import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../auth_flow.dart';
import '../widgets/auth_widgets.dart';

class ResetPasswordPage extends StatelessWidget {
  const ResetPasswordPage({super.key, required this.onNavigate});
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) => AuthScaffold(
        showHeader: false,
        child: Center(
            child: AuthCard(
                child: Column(children: [
          Container(
            width: 57,
            height: 57,
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xff3a3030)
                  : const Color(0xfffdeeee),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset_outlined,
                color: AppTheme.red, size: 34),
          ),
          const SizedBox(height: 14),
          const AuthTitle('Reset Password'),
          const AuthDescription(
              'Create a new, strong password to\nsecure your account.'),
          const PasswordRequirements(),
          const SizedBox(height: 17),
          const AuthField(
              label: 'New Password',
              hint: 'Enter new password',
              obscureText: true),
          const SizedBox(height: 11),
          const AuthField(
              label: 'Confirm New Password',
              hint: 'Confirm new password',
              obscureText: true),
          const SizedBox(height: 22),
          AppButton(label: '◉  Reset Password', onPressed: () {}),
          const SizedBox(height: 24),
          AuthLink('Cancel',
              onTap: () => onNavigate(AuthPage.login), muted: true),
        ]))),
      );
}
