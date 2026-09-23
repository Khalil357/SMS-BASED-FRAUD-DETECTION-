import 'package:flutter/material.dart';

import 'services/auth_service.dart';
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
  bool _isResetPasswordFlow = true;
  bool _isLoginVerificationFlow = false;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _checkSavedSession();
  }

  Future<void> _checkSavedSession() async {
    final hasSession = await AuthService.loadSession();
    if (mounted) {
      setState(() {
        if (hasSession) {
          _page = AuthPage.dashboard;
        }
        _isCheckingSession = false;
      });
    }
  }

  void _goTo(AuthPage page) => setState(() => _page = page);

  void _beginPasswordReset(String phoneNumber) {
    setState(() {
      _resetPhoneNumber = phoneNumber;
      _resetVerificationCode = null;
      _isResetPasswordFlow = true;
      _isLoginVerificationFlow = false;
      _page = AuthPage.verification;
    });
  }

  void _beginSignUpVerification(String phoneNumber) {
    setState(() {
      _resetPhoneNumber = phoneNumber;
      _resetVerificationCode = null;
      _isResetPasswordFlow = false;
      _isLoginVerificationFlow = false;
      _page = AuthPage.verification;
    });
  }

  void _beginLoginVerification(String identifier) {
    setState(() {
      _resetPhoneNumber = identifier;
      _resetVerificationCode = null;
      _isResetPasswordFlow = false;
      _isLoginVerificationFlow = true;
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
    if (_isCheckingSession) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_page == AuthPage.dashboard) {
      return DashboardPage(onNavigate: _goTo);
    }

    final page = switch (_page) {
      AuthPage.login => LoginPage(
          onNavigate: _goTo,
          onUnverifiedAccount: _beginLoginVerification,
        ),
      AuthPage.signUp => SignUpPage(
          onNavigate: _goTo,
          onSignUpSuccess: _beginSignUpVerification,
        ),
      AuthPage.forgotPassword => ForgotPasswordPage(
          onNavigate: _goTo, onResetRequested: _beginPasswordReset),
      AuthPage.verification => VerificationPage(
          onNavigate: _goTo,
          phoneNumber: _resetPhoneNumber ?? '',
          isResetPasswordFlow: _isResetPasswordFlow,
          isLoginVerificationFlow: _isLoginVerificationFlow,
          onVerified: (code) async {
            if (_isResetPasswordFlow) {
              _verifyPasswordReset(code);
            } else if (_isLoginVerificationFlow) {
              _goTo(AuthPage.dashboard);
            } else {
              // Registration verification does not issue a JWT. Require a real
              // login instead of creating a placeholder authenticated session.
              _goTo(AuthPage.login);
            }
          },
        ),
      AuthPage.resetPassword => ResetPasswordPage(
          onNavigate: _goTo,
          phoneNumber: _resetPhoneNumber ?? '',
          verificationCode: _resetVerificationCode ?? ''),
      AuthPage.dashboard => throw StateError('Handled above'),
    };
    return Scaffold(body: SafeArea(child: page));
  }
}
