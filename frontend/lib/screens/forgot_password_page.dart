import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../auth_flow.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key, required this.onNavigate});
  final Navigate onNavigate;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
    });

    if (_phoneController.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your phone number');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.requestPasswordReset(
      phoneNumber: _phoneController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      setState(() => _successMessage = result['message']);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          widget.onNavigate(AuthPage.verification);
        }
      });
    } else {
      setState(() => _errorMessage = result['message']);
    }
  }

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
          AuthFieldWithController(
              controller: _phoneController,
              label: 'Phone Number',
              hint: '+27 82 123 4567',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: AppTheme.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          if (_successMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _successMessage!,
                style: const TextStyle(color: Colors.green, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          AppButton(
              label: _isLoading ? 'Sending...' : 'Send Reset Code',
              onPressed: _isLoading ? null : _handleSendCode),
          const SizedBox(height: 25),
          AuthLink('←  Back to Login', onTap: () => widget.onNavigate(AuthPage.login)),
        ]))),
      );
}
