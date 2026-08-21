import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../auth_flow.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/fade_slide_transition.dart';

class ResetPasswordPage extends StatefulWidget {
<<<<<<< HEAD
  final Navigate onNavigate;
  final String phoneNumber;

  const ResetPasswordPage({
    super.key,
    required this.onNavigate,
    required this.phoneNumber,
  });
=======
  const ResetPasswordPage(
      {super.key,
      required this.onNavigate,
      required this.phoneNumber,
      required this.verificationCode});
  final Navigate onNavigate;
  final String phoneNumber;
  final String verificationCode;
>>>>>>> a491ebabbb63969eb2eb01b7e027539fe98d7a81

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
<<<<<<< HEAD
=======
  String? _errorMessage;
>>>>>>> a491ebabbb63969eb2eb01b7e027539fe98d7a81

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

<<<<<<< HEAD
      // Using dummy code since the verification code was verified on the previous page
      final result = await AuthService.resetPassword(
        phoneNumber: widget.phoneNumber.isNotEmpty ? widget.phoneNumber : 'dummy_number',
        verificationCode: '123456', 
        newPassword: _passwordController.text,
=======
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
>>>>>>> a491ebabbb63969eb2eb01b7e027539fe98d7a81
      );

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Password reset successfully!'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );

        widget.onNavigate(AuthPage.login);
      } else {
        String errorMessage = result['message'] ?? 'Failed to reset password';
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
        title: const Text('Reset Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => widget.onNavigate(AuthPage.login),
        ),
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
                      const SizedBox(height: 20),
                      
                      // Secure lock icon with entrance animation
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
                              Icons.lock_open_outlined,
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
                              'New Password',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 10),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Create a strong, unique password to secure your account. Password must be at least 8 characters long.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Inputs Card Container
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
                              // New Password Field
                              CustomTextField(
                                controller: _passwordController,
                                labelText: 'New Password',
                                hintText: '••••••••',
                                prefixIcon: Icons.lock_outline,
                                obscureText: true,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter a new password';
                                  }
                                  if (value.trim().length < 8) {
                                    return 'Password must be at least 8 characters';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Confirm Password Field
                              CustomTextField(
                                controller: _confirmPasswordController,
                                labelText: 'Confirm Password',
                                hintText: '••••••••',
                                prefixIcon: Icons.lock_reset_outlined,
                                obscureText: true,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _handleSubmit(),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),

                              // Submit Button
                              CustomButton(
                                text: 'Submit',
                                isLoading: _isLoading,
                                onPressed: _handleSubmit,
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
