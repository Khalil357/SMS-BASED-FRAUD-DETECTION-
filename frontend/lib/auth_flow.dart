import 'package:flutter/material.dart';

import 'screens/forgot_password_page.dart';
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/reset_password_page.dart';
import 'screens/sign_up_page.dart';
import 'screens/verification_page.dart';
import 'services/token_storage.dart';

enum AuthPage { login, signUp, forgotPassword, verification, resetPassword, home }

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
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await TokenStorage.read();
    if (!mounted) return;
    setState(() {
      _page = token != null ? AuthPage.home : AuthPage.login;
      _bootstrapping = false;
    });
  }

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

  void _logout() {
    setState(() => _page = AuthPage.login);
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
      AuthPage.home => HomePage(onLogout: _logout),
    };
    return Scaffold(body: SafeArea(child: page));
  }
}
