import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../auth_flow.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage(
      {super.key,
      required this.onNavigate,
      required this.phoneNumber,
      required this.onVerified});
  final Navigate onNavigate;
  final String phoneNumber;
  final ValueChanged<String> onVerified;

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _handleVerify() async {
    setState(() => _errorMessage = null);

    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter a valid 6-digit code');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.verifyResetCode(
      phoneNumber: widget.phoneNumber,
      verificationCode: code,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
      widget.onVerified(code);
    } else {
      setState(() => _errorMessage = result['message']);
    }
  }

  Future<void> _handleResendCode() async {
    setState(() => _errorMessage = null);

    if (widget.phoneNumber.isEmpty) {
      setState(
          () => _errorMessage = 'Phone number not available. Please go back.');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.resendCode(phoneNumber: widget.phoneNumber);

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
    } else {
      setState(() => _errorMessage = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        child: Center(
            child: AuthCard(
                topAccent: true,
                child: Column(children: [
                  const Icon(Icons.mark_email_read_outlined,
                      color: AppTheme.red, size: 42),
                  const SizedBox(height: 11),
                  const AuthTitle('Verify Your Code'),
                  const AuthDescription(
                      "We've sent a 6-digit verification code\nto\n",
                      trailing: 'j.doe@example.com'),
                  const SizedBox(height: 17),
                  OtpFieldsWithControllers(controllers: _otpControllers),
                  const SizedBox(height: 27),
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
                      label: _isLoading ? 'Verifying...' : 'Verify',
                      onPressed: _isLoading ? null : _handleVerify),
                  const SizedBox(height: 19),
                  AuthPrompt(
                      prefix: "Didn't receive the code? ",
                      link: 'Resend Code',
                      onTap: _handleResendCode),
                ]))),
      );
}
