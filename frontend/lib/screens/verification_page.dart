import 'dart:async';
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

  const VerificationPage({
    super.key,
    required this.onNavigate,
    required this.phoneNumber,
    this.isResetPasswordFlow = false,
  });

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  String _otpCode = '';
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  void _handleResend() async {
    if (_secondsRemaining == 0) {
      setState(() {
        _isLoading = true;
      });

      final result = await AuthService.resendCode(
        phoneNumber: widget.phoneNumber,
      );

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      if (result['success']) {
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'A new 6-digit verification code has been sent!'),
            backgroundColor: Colors.blue.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        String errorMessage = result['message'] ?? 'Failed to resend code';
        if (errorMessage.contains('YOUR_SERVER_URL_HERE') || errorMessage.contains('Unsupported scheme')) {
          errorMessage = 'Please configure your backend server URL in lib/services/auth_service.dart';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _handleVerify() async {
    if (_otpCode.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter the full 6-digit verification code.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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

      if (widget.isResetPasswordFlow) {
        widget.onNavigate(
          AuthPage.resetPassword,
          phoneNumber: widget.phoneNumber,
          isResetPasswordFlow: true,
        );
      } else {
        widget.onNavigate(AuthPage.login);
      }
    } else {
      String errorMessage = result['message'] ?? 'Invalid verification code';
      if (errorMessage.contains('YOUR_SERVER_URL_HERE') || errorMessage.contains('Unsupported scheme')) {
        errorMessage = 'Please configure your backend server URL in lib/services/auth_service.dart';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isResendEnabled = _secondsRemaining == 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => widget.onNavigate(AuthPage.login),
        ),
        title: const Text('Verify Number'),
      ),
      body: Stack(
        children: [
          // Background Gradient accent at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.15,
            child: Container(
              decoration: BoxDecoration(
                gradient: isDark
                    ? AppTheme.heroBgGradientDark
                    : AppTheme.heroBgGradientLight,
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    
                    // Message icon card
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
                          child: Icon(
                            Icons.sms_outlined,
                            size: 64,
                            color: theme.primaryColor,
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
                            'Verification Code',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: theme.textTheme.bodyMedium,
                                children: [
                                  const TextSpan(text: 'We sent a 6-digit verification code to\n'),
                                  TextSpan(
                                    text: widget.phoneNumber.isNotEmpty ? widget.phoneNumber : 'your phone number',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

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
                            // 6-digit OTP fields
                            OtpInputField(
                              length: 6,
                              onChanged: (code) {
                                setState(() {
                                  _otpCode = code;
                                });
                              },
                              onCompleted: (code) {
                                _otpCode = code;
                                _handleVerify();
                              },
                            ),
                            const SizedBox(height: 28),

                            // Countdown timer & Resend code Button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.timer_outlined,
                                  size: 16,
                                  color: isResendEnabled
                                      ? Colors.grey.shade400
                                      : theme.primaryColor,
                                ),
                                const SizedBox(width: 6),
                                if (_secondsRemaining > 0)
                                  Text(
                                    'Resend in ${_formatTime(_secondsRemaining)}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                else
                                  TextButton(
                                    onPressed: _handleResend,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Resend Code'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 32),

                            // Verify Button
                            CustomButton(
                              text: 'Verify',
                              isLoading: _isLoading,
                              onPressed: _handleVerify,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
