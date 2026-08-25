import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../auth_flow.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage(
      {super.key,
        required this.onNavigate,
        required this.phoneNumber,
        required this.verificationCode});
  final Navigate onNavigate;
  final String phoneNumber;
  final String verificationCode;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleResetPassword() async {
    setState(() => _errorMessage = null);

    if (_newPasswordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    if (_newPasswordController.text.length < 8) {
      setState(
              () => _errorMessage = 'Password must be at least 8 characters long');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.resetPassword(
      phoneNumber: widget.phoneNumber,
      verificationCode: widget.verificationCode,
      newPassword: _newPasswordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
      widget.onNavigate(AuthPage.login);
    } else {
      setState(() => _errorMessage = result['message']);
    }
  }

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
              AuthFieldWithController(
                  controller: _newPasswordController,
                  label: 'New Password',
                  hint: 'Enter new password',
                  obscureText: true),
              const SizedBox(height: 11),
              AuthFieldWithController(
                  controller: _confirmPasswordController,
                  label: 'Confirm New Password',
                  hint: 'Confirm new password',
                  obscureText: true),
              const SizedBox(height: 22),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppTheme.red, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              AppButton(
                  label: _isLoading ? 'Resetting...' : '◉  Reset Password',
                  onPressed: _isLoading ? null : _handleResetPassword),
              const SizedBox(height: 24),
              AuthLink('Cancel',
                  onTap: () => widget.onNavigate(AuthPage.login), muted: true),
            ]))),
  );
}