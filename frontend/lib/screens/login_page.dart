import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../auth_flow.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/fade_slide_transition.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  final Navigate onNavigate;
  final ValueChanged<String>? onUnverifiedAccount;

  const LoginPage({
    super.key,
    required this.onNavigate,
    this.onUnverifiedAccount,
  });

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

  void _showUnverifiedAccountDialog(String identifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.mark_email_unread_outlined, color: AppTheme.red),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Account Not Verified',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            'Your account has been created but is not verified yet. Would you like to receive a verification code to complete setup?',
            style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  if (mounted) {
                    if (widget.onUnverifiedAccount != null) {
                      widget.onUnverifiedAccount!(identifier);
                    } else {
                      widget.onNavigate(AuthPage.verification);
                    }
                  }
                },
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Verify Account Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final result = await AuthService.login(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Login successful!'),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          widget.onNavigate(AuthPage.dashboard);
        } else {
          final isUnverified = result['isUnverified'] == true;

          if (isUnverified) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Account not verified. Please enter your verification code.'),
                backgroundColor: Colors.orange.shade800,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
            final identifier = _identifierController.text.trim();
            if (widget.onUnverifiedAccount != null) {
              widget.onUnverifiedAccount!(identifier);
            } else {
              widget.onNavigate(AuthPage.verification);
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['message'] ?? 'Login failed. Please check your credentials.'),
                backgroundColor: Theme.of(context).colorScheme.error,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.cyberCard : AppTheme.cardLight;
    final borderColor = isDark ? AppTheme.cyberBorder : AppTheme.borderLight;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Gradient accent at the top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.35,
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
                    const SizedBox(height: 20),

                    // Logo Icon with entrance animation
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 100),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? AppTheme.cyberCard : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? AppTheme.cyberRed.withOpacity(0.4) : theme.colorScheme.primary.withOpacity(0.3),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (isDark ? AppTheme.cyberRed : theme.colorScheme.primary).withOpacity(0.15),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/sms_fraud_inapp_icon.png',
                            width: 72,
                            height: 72,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.shield_outlined,
                              size: 64,
                              color: isDark ? AppTheme.cyberRed : theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Cyber Sentinel Pill & Titles
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 200),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.cyberGreen.withOpacity(0.12) : theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark ? AppTheme.cyberGreen.withOpacity(0.3) : theme.colorScheme.primary.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.security_rounded,
                                  size: 13,
                                  color: isDark ? AppTheme.cyberGreen : theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'ARGUS • SMS FRAUD SHIELD',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: isDark ? AppTheme.cyberGreen : theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Welcome Back',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Sign in to protect your inbox & detect fraudulent SMS messages',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppTheme.cyberTextMuted : AppTheme.subtleLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Login Card Containing Inputs
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: borderColor,
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
                              hintText: 'e.g. +255754234567 or user@gmail.com',
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
                            const SizedBox(height: 18),

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
                                child: Text(
                                  'Forgot Password?',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Login Button
                            CustomButton(
                              text: 'Sign In to Argus',
                              isLoading: _isLoading,
                              onPressed: _handleLogin,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Create Account text
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 400),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account? ",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? AppTheme.cyberTextMuted : AppTheme.subtleLight,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              widget.onNavigate(AuthPage.signUp);
                            },
                            child: Text(
                              'Create an account',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTheme.cyberCyan : theme.colorScheme.primary,
                              ),
                            ),
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