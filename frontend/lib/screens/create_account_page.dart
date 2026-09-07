import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../app_theme.dart';
import '../auth_flow.dart';
import '../services/auth_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/fade_slide_transition.dart';

class SignUpPage extends StatefulWidget {
  final Navigate onNavigate;
  final ValueChanged<String> onSignUpSuccess;

  const SignUpPage({
    super.key,
    required this.onNavigate,
    required this.onSignUpSuccess,
  });

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _selectedGender;
  bool _isLoading = false;
  bool _termsAccepted = false;
  String? _termsErrorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleSignUp() async {
    setState(() {
      _termsErrorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_termsAccepted) {
      setState(() {
        _termsErrorMessage = 'You must accept the terms and conditions';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await AuthService.signUp(
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      gender: _selectedGender ?? 'Other',
      password: _passwordController.text,
    );

    setState(() {
      _isLoading = false;
    });

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['message'] ?? 'Account created successfully!'),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      widget.onSignUpSuccess(_phoneController.text.trim());
    } else {
      final msg = (result['message'] ?? 'Registration failed').toString();
      final isAlreadyRegistered = result['statusCode'] == 409 ||
          msg.toLowerCase().contains('already registered') ||
          msg.toLowerCase().contains('already exists');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: isAlreadyRegistered
              ? SnackBarAction(
                  label: 'Verify / Login',
                  textColor: Colors.amber,
                  onPressed: () async {
                    final phone = _phoneController.text.trim();
                    if (phone.isNotEmpty) {
                      await AuthService.resendCode(phoneNumber: phone);
                      widget.onSignUpSuccess(phone);
                    } else {
                      widget.onNavigate(AuthPage.login);
                    }
                  },
                )
              : null,
        ),
      );
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
                    const SizedBox(height: 15),

                    // Logo Icon with entrance animation
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 50),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withOpacity(0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.primaryColor.withOpacity(0.15),
                              width: 2,
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/sms_fraud_inapp_icon.png',
                            width: 80,
                            height: 80,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 100),
                      child: Column(
                        children: [
                          Text(
                            'Create Account',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge?.copyWith(fontSize: 28),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Join Secure Signal to protect your messages from fraud',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Form Card
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 150),
                      child: Container(
                        padding: const EdgeInsets.all(22),
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
                            // Full Name Input
                            CustomTextField(
                              controller: _nameController,
                              labelText: 'Full Name',
                              hintText: 'e.g. John Doe',
                              prefixIcon: Icons.person_outline,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Email Input
                            CustomTextField(
                              controller: _emailController,
                              labelText: 'Email Address',
                              hintText: 'e.g. john@example.com',
                              prefixIcon: Icons.mail_outline,
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                                if (!emailRegExp.hasMatch(value.trim())) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Phone Input
                            CustomTextField(
                              controller: _phoneController,
                              labelText: 'Phone Number',
                              hintText: 'e.g. +27821234567',
                              prefixIcon: Icons.phone_android_outlined,
                              keyboardType: TextInputType.phone,
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
                            const SizedBox(height: 16),

                            // Gender Dropdown
                            DropdownButtonFormField<String>(
                              value: _selectedGender,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                              ),
                              dropdownColor: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                              decoration: InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                  child: Icon(
                                    Icons.face_outlined,
                                    size: 20,
                                    color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(minWidth: 52),
                              ),
                              items: ['Male', 'Female', 'Other'].map((g) {
                                return DropdownMenuItem<String>(
                                  value: g,
                                  child: Text(g),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedGender = val;
                                });
                              },
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return 'Please select your gender';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password Input
                            CustomTextField(
                              controller: _passwordController,
                              labelText: 'Password',
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_outline,
                              obscureText: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter a password';
                                }
                                final val = value.trim();
                                if (val.length < 8) {
                                  return 'Password must be at least 8 characters';
                                }
                                if (!RegExp(r'[A-Z]').hasMatch(val)) {
                                  return 'Include at least 1 uppercase letter (A-Z)';
                                }
                                if (!RegExp(r'[a-z]').hasMatch(val)) {
                                  return 'Include at least 1 lowercase letter (a-z)';
                                }
                                if (!RegExp(r'[0-9]').hasMatch(val)) {
                                  return 'Include at least 1 number (0-9)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Confirm Password Input
                            CustomTextField(
                              controller: _confirmPasswordController,
                              labelText: 'Confirm Password',
                              hintText: '••••••••',
                              prefixIcon: Icons.lock_reset_outlined,
                              obscureText: true,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _handleSignUp(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please confirm your password';
                                }
                                if (value != _passwordController.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Terms & Conditions Checkbox
                            Row(
                              children: [
                                Checkbox(
                                  value: _termsAccepted,
                                  onChanged: (val) {
                                    setState(() {
                                      _termsAccepted = val ?? false;
                                    });
                                  },
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _termsAccepted = !_termsAccepted;
                                      });
                                    },
                                    child: Text(
                                      'I accept the Terms & Conditions',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (_termsErrorMessage != null) ...[
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Text(
                                  _termsErrorMessage!,
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Register Button
                            CustomButton(
                              text: 'Create Account',
                              isLoading: _isLoading,
                              onPressed: _handleSignUp,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Back to Login Link
                    FadeSlideTransition(
                      delay: const Duration(milliseconds: 200),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: theme.textTheme.bodyMedium,
                          ),
                          TextButton(
                            onPressed: () {
                              widget.onNavigate(AuthPage.login);
                            },
                            child: const Text('Login'),
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
