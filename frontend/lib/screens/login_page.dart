import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../auth_flow.dart';
import '../widgets/auth_widgets.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.onNavigate});
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) => AuthScaffold(
        showHeader: false,
        child: Container(
          decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppTheme.red, width: 4))),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 28),
              child: Column(children: [
                const Icon(Icons.shield_outlined,
                    color: AppTheme.red, size: 42),
                const SizedBox(height: 12),
                const AuthTitle('Secure Signal'),
                const AuthDescription('Sign in to monitor and manage alerts.'),
                const SizedBox(height: 18),
                const AuthField(
                    label: 'Phone Number',
                    hint: 'e.g. +27 82 123 4567',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 11),
                Row(children: [
                  const FieldLabel('Password'),
                  const Spacer(),
                  AuthLink('Forgot Password?',
                      onTap: () => onNavigate(AuthPage.forgotPassword)),
                ]),
                const SizedBox(height: 5),
                const AuthField(
                    hint: 'Enter your password',
                    icon: Icons.lock_outline,
                    obscureText: true),
                const SizedBox(height: 21),
                AppButton(label: 'Login  →', onPressed: () {}),
                const SectionDivider(),
                AuthPrompt(
                    prefix: 'New to Secure Signal? ',
                    link: 'Create an Account',
                    onTap: () => onNavigate(AuthPage.signUp)),
              ]),
            ),
          ),
        ),
      );
}
