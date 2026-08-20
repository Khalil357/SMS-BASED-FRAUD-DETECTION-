import 'package:flutter/material.dart';

import 'screens/forgot_password_page.dart';
import 'screens/login_page.dart';
import 'screens/reset_password_page.dart';
import 'screens/sign_up_page.dart';
import 'screens/verification_page.dart';

enum AuthPage { login, signUp, forgotPassword, verification, resetPassword }

typedef Navigate = void Function(AuthPage page);

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});
  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  AuthPage _page = AuthPage.login;
  void _goTo(AuthPage page) => setState(() => _page = page);

  @override
  Widget build(BuildContext context) {
    final page = switch (_page) {
      AuthPage.login => LoginPage(onNavigate: _goTo),
      AuthPage.signUp => SignUpPage(onNavigate: _goTo),
      AuthPage.forgotPassword => ForgotPasswordPage(onNavigate: _goTo),
      AuthPage.verification => VerificationPage(onNavigate: _goTo),
      AuthPage.resetPassword => ResetPasswordPage(onNavigate: _goTo),
    };
    return Scaffold(body: SafeArea(child: page));
  }
}
