import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../auth_flow.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/otp_input_field.dart';
import '../widgets/fade_slide_transition.dart';

class VerificationPage extends StatefulWidget {
  final Navigate onNavigate;
  final String phoneNumber;
  final bool isResetPasswordFlow;
  final ValueChanged<String> onVerified;

  const VerificationPage({
    super.key,
    required this.onNavigate,
    required this.phoneNumber,
    this.isResetPasswordFlow = true,
    required this.onVerified,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  String _otpCode = '';
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleVerify() async {
    setState(() {
      _errorMessage = null;
    });

    if (_otpCode.length != 6) {
      setState(() {
        _errorMessage = 'Please enter the complete 6-digit code';
      });
      return;
    }

    if (widget.isResetPasswordFlow) {
      // For reset password flow, we skip verifying at this step to prevent
      // invalidating the OTP before confirming the password change.
      widget.onVerified(_otpCode);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.verifyResetCode(
      phoneNumber: widget.phoneNumber,
      verificationCode: _otpCode,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Code verified successfully!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      widget.onVerified(_otpCode);
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Invalid verification code';
      });
    }
  }

  Future<void> _handleResendCode() async {
    setState(() {
      _errorMessage = null;
    });

    if (widget.phoneNumber.isEmpty) {
      setState(() {
        _errorMessage = 'Phone number is missing. Please go back.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.resendCode(phoneNumber: widget.phoneNumber);

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Verification code resent successfully!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } else {
      setState(() {
        _errorMessage = result['message'] ?? 'Failed to resend code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient accent at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.32,
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppTheme.heroBgGradientDark
                    : AppTheme.heroBgGradientLight,
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Logo Icon with entrance animation
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 100),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withOpacity(0.08),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.primaryColor.withOpacity(0.15),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Titles
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 200),
                    child: Column(
                      children: [
                        Text(
                          'Verify Code',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "We've sent a 6-digit verification code to ${widget.phoneNumber}",
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),

                  // Verification Card
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        boxShadow: AppTheme.cardShadow(isDark),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // OTP Input Fields
                          OtpInputField(
                            length: 6,
                            onChanged: (code) {
                              _otpCode = code;
                            },
                            onCompleted: (code) {
                              _otpCode = code;
                              _handleVerify();
                            },
                          ),
                          
                          if (_errorMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // Verify Button
                          CustomButton(
                            text: 'Verify Code',
                            isLoading: _isLoading,
                            onPressed: _handleVerify,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Resend Code Link
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 400),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          "Didn't receive the code? ",
                          style: theme.textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: _isLoading ? null : _handleResendCode,
                          child: const Text('Resend Code'),
                        ),
                      ],
                    ),
                  ),

                  // Back to Login Link for escape hatch navigation
                  FadeSlideTransition(
                    delay: const Duration(milliseconds: 450),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(Icons.arrow_back, size: 16, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: () {
                            widget.onNavigate(AuthPage.login);
                          },
                          child: const Text('Back to Login'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}