import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../app_theme.dart';
import '../auth_flow.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/fade_slide_transition.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  final Navigate onNavigate;

  const LoginPage({super.key, required this.onNavigate});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final result = await AuthService.login(
        phoneNumber: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Login successful!'),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          widget.onNavigate(AuthPage.dashboard);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Login failed'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
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
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 30),

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
                            Icons.shield_outlined,
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
                            'Welcome Back!',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Secure your inbox and detect fraud SMS messages',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Login Card Containing Inputs
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
                            // Identifier input field (Phone or Email)
                            CustomTextField(
                              controller: _identifierController,
                              labelText: 'Phone Number or Email',
                              hintText: 'e.g. +27821234567 or user@email.com',
                              prefixIcon: Icons.login_outlined,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your phone number or email';
                                }
                                final val = value.trim();
                                if (val.contains('@')) {
                                  final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                  if (!emailRegExp.hasMatch(val)) {
                                    return 'Please enter a valid email';
                                  }
                                } else {
                                  if (val.length < 9) {
                                    return 'Please enter a valid phone number';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password input field
                            CustomTextField(
                              controller: _passwordController,
                              labelText: 'Password',
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleLogin(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your password';
                                }
                                if (value.trim().length < 6) {
                                  return 'Password must be at least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),

                            // Forgot Password Button
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  widget.onNavigate(AuthPage.forgotPassword);
                                },
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: const Text('Forgot Password?'),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Login Button
                            CustomButton(
                              text: 'Login',
                              isLoading: _isLoading,
                              onPressed: _handleLogin,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Create Account text
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 400),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: theme.textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () {
                              widget.onNavigate(AuthPage.signUp);
                            },
                            child: const Text('Create an account'),
                          ),
                        ],
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