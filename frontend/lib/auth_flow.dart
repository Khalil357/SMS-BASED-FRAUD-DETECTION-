import 'package:flutter/material.dart';

import 'screens/forgot_password_page.dart';
import 'screens/login_page.dart';
import 'screens/reset_password_page.dart';
import 'screens/sign_up_page.dart';
import 'screens/verification_page.dart';

enum AuthPage { login, signUp, forgotPassword, verification, resetPassword }

typedef Navigate = void Function(AuthPage page, {String? phoneNumber, bool? isResetPasswordFlow});

class AuthFlow extends StatefulWidget {
  const AuthFlow({super.key});
  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  AuthPage _page = AuthPage.login;
  String _phoneNumber = '';
  bool _isResetPasswordFlow = false;

  void _goTo(AuthPage page, {String? phoneNumber, bool? isResetPasswordFlow}) {
    setState(() {
      _page = page;
      if (phoneNumber != null) _phoneNumber = phoneNumber;
      if (isResetPasswordFlow != null) _isResetPasswordFlow = isResetPasswordFlow;
    });
  }

  @override
  Widget build(BuildContext context) {
    final page = switch (_page) {
      AuthPage.login => LoginPage(onNavigate: _goTo),
      AuthPage.signUp => SignUpPage(onNavigate: _goTo),
      AuthPage.forgotPassword => ForgotPasswordPage(onNavigate: _goTo),
      AuthPage.verification => VerificationPage(
          onNavigate: _goTo,
          phoneNumber: _phoneNumber,
          isResetPasswordFlow: _isResetPasswordFlow,
        ),
      AuthPage.resetPassword => ResetPasswordPage(
          onNavigate: _goTo,
          phoneNumber: _phoneNumber,
        ),
    };
    return Scaffold(body: SafeArea(child: page));
  }
}
