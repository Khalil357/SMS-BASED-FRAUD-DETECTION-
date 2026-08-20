import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../auth_flow.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/fade_slide_transition.dart';

class ForgotPasswordPage extends StatefulWidget {
  final Navigate onNavigate;

  const ForgotPasswordPage({super.key, required this.onNavigate});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _handleSendCode() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final result = await AuthService.requestPasswordReset(
        phoneNumber: _phoneController.text.trim(),
      );

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Reset code sent successfully!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        widget.onNavigate(
          AuthPage.verification,
          phoneNumber: _phoneController.text.trim(),
          isResetPasswordFlow: true,
        );
      } else {
        String errorMessage = result['message'] ?? 'Failed to send reset code';
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => widget.onNavigate(AuthPage.login),
        ),
        title: const Text('Forgot Password'),
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),
                      
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
                            child: Icon(
                              Icons.lock_reset_outlined,
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
                              'Recover Account',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Enter your phone number. We will send you a 6-digit verification code to reset your password.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Forgot Card Containing Inputs
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
                              // Phone input field
                              CustomTextField(
                                controller: _phoneController,
                                labelText: 'Phone Number',
                                hintText: 'e.g. +1234567890',
                                prefixIcon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleSendCode(),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  if (value.trim().length < 9) {
                                    return 'Please enter a valid phone number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 28),

                              // Send Code Button
                              CustomButton(
                                text: 'Send Reset Code',
                                isLoading: _isLoading,
                                onPressed: _handleSendCode,
                              ),
                              const SizedBox(height: 16),

                              // Back to Login Button (Outlined/Secondary)
                              CustomButton(
                                text: 'Back to Login',
                                type: ButtonType.secondary,
                                onPressed: () {
                                  widget.onNavigate(AuthPage.login);
                                },
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
          ),
        ],
      ),
    );
  }
}
