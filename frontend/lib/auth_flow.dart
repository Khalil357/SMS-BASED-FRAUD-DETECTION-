import 'package:flutter/material.dart';

import 'screens/forgot_password_page.dart';
import 'screens/login_page.dart';
import 'screens/reset_password_page.dart';
import 'screens/create_account_page.dart';
import 'screens/verification_page.dart';
import 'screens/dashboard_page.dart';

enum AuthPage { login, signUp, forgotPassword, verification, resetPassword, dashboard }

typedef Navigate = void Function(AuthPage page);

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});
  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  AuthPage _page = AuthPage.login;
  String? _resetPhoneNumber;
  String? _resetVerificationCode;

  void _goTo(AuthPage page) => setState(() => _page = page);

  void _beginPasswordReset(String phoneNumber) {
    setState(() {
      _resetPhoneNumber = phoneNumber;
      _resetVerificationCode = null;
      _page = AuthPage.verification;
    });
  }

  void _verifyPasswordReset(String verificationCode) {
    setState(() {
      _resetVerificationCode = verificationCode;
      _page = AuthPage.resetPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_page == AuthPage.dashboard) {
      return DashboardPage(onNavigate: _goTo);
    }

    final page = switch (_page) {
      AuthPage.login => LoginPage(onNavigate: _goTo),
      AuthPage.signUp => SignUpPage(onNavigate: _goTo),
      AuthPage.forgotPassword => ForgotPasswordPage(
          onNavigate: _goTo, onResetRequested: _beginPasswordReset),
      AuthPage.verification => VerificationPage(
          onNavigate: _goTo,
          phoneNumber: _resetPhoneNumber ?? '',
          onVerified: _verifyPasswordReset),
      AuthPage.resetPassword => ResetPasswordPage(
          onNavigate: _goTo,
          phoneNumber: _resetPhoneNumber ?? '',
          verificationCode: _resetVerificationCode ?? ''),
      AuthPage.dashboard => throw StateError('Handled above'),
    };
    return Scaffold(body: SafeArea(child: page));
  }
}