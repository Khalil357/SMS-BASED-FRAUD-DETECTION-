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
<<<<<<< HEAD
  String _phoneNumber = '';
  bool _isResetPasswordFlow = false;

  void _goTo(AuthPage page, {String? phoneNumber, bool? isResetPasswordFlow}) {
    setState(() {
      _page = page;
      if (phoneNumber != null) _phoneNumber = phoneNumber;
      if (isResetPasswordFlow != null) _isResetPasswordFlow = isResetPasswordFlow;
    });
  }
=======
  String? _resetPhoneNumber;
  String? _resetVerificationCode;

  void _goTo(AuthPage page) => setState(() => _page = page);
>>>>>>> a491ebabbb63969eb2eb01b7e027539fe98d7a81

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
    final page = switch (_page) {
      AuthPage.login => LoginPage(onNavigate: _goTo),
      AuthPage.signUp => SignUpPage(onNavigate: _goTo),
<<<<<<< HEAD
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
=======
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
>>>>>>> a491ebabbb63969eb2eb01b7e027539fe98d7a81
    };
    return Scaffold(body: SafeArea(child: page));
  }
}
