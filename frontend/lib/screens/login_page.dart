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
  final ValueChanged<String> onLoginOtpRequired;

  const LoginPage({
    super.key,
    required this.onNavigate,
    required this.onLoginOtpRequired,
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
              child: Text('Account Not Verified', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
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
                onPressed: () async {
                  Navigator.pop(context);
                  if (identifier.isNotEmpty) {
                    await AuthService.resendCode(phoneNumber: identifier);
                  }
                  if (mounted) {
                    if (widget.onUnverifiedAccount != null) {
                      widget.onUnverifiedAccount!(identifier);
                    } else {
                      widget.onNavigate(AuthPage.verification);
                    }
                  }
                },
                child: const FittedBox(fit: BoxFit.scaleDown, child: Text('Verify Account Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(height: 6),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ],
          ),
        ],
      ),
    );
  }

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() { _isLoading = true; });
      final result = await AuthService.login(identifier: _identifierController.text.trim(), password: _passwordController.text);

      if (mounted) {
        setState(() { _isLoading = false; });
        if (result['success'] == true) {
          widget.onNavigate(AuthPage.dashboard);
        } else {
          final msg = (result['message'] ?? '').toString();
          final isUnverified = msg.toLowerCase().contains('not verified') || msg.toLowerCase().contains('verify your email') || result['statusCode'] == 403;
          if (isUnverified) {
            final data = result['data'] is Map<String, dynamic> ? result['data'] as Map<String, dynamic> : null;
            final userEmail = data?['email'] ?? data?['user']?['email'] ?? _identifierController.text.trim();
            _showUnverifiedAccountDialog(userEmail);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'] ?? 'Login failed'), backgroundColor: Theme.of(context).colorScheme.error, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
          }
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
          Positioned(top: 0, left: 0, right: 0, height: MediaQuery.of(context).size.height * 0.32, child: Container(decoration: BoxDecoration(gradient: isDark ? AppTheme.heroBgGradientDark : AppTheme.heroBgGradientLight))),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Form(
                key: _formKey,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const SizedBox(height: 30),
                  FadeSlideTransition(delay: const Duration(milliseconds: 100), child: Center(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.08), shape: BoxShape.circle, border: Border.all(color: theme.primaryColor.withValues(alpha: 0.15), width: 2)), child: Image.asset('assets/images/sms_fraud_inapp_icon.png', width: 80, height: 80, fit: BoxFit.contain)))),
                  const SizedBox(height: 24),
                  FadeSlideTransition(delay: const Duration(milliseconds: 200), child: Column(children: [Text('Welcome Back!', textAlign: TextAlign.center, style: theme.textTheme.headlineLarge), const SizedBox(height: 8), Text('Secure your inbox and detect fraud SMS messages', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium)])),
                  const SizedBox(height: 36),
                  FadeSlideTransition(delay: const Duration(milliseconds: 300), child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: theme.cardTheme.color, borderRadius: BorderRadius.circular(24), border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1), boxShadow: AppTheme.cardShadow(isDark)), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    CustomTextField(controller: _identifierController, labelText: 'Phone or Email', hintText: 'e.g. user@email.com', prefixIcon: Icons.login_outlined, keyboardType: TextInputType.emailAddress, validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter phone or email' : null),
                    const SizedBox(height: 20),
                    CustomTextField(controller: _passwordController, labelText: 'Password', hintText: '••••••••', prefixIcon: Icons.lock_outline, obscureText: true, textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _handleLogin(), validator: (v) => (v == null || v.trim().isEmpty || v.length < 6) ? 'Enter valid password' : null),
                    const SizedBox(height: 10),
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => widget.onNavigate(AuthPage.forgotPassword), child: const Text('Forgot Password?'))),
                    const SizedBox(height: 28),
                    CustomButton(text: 'Login', isLoading: _isLoading, onPressed: _handleLogin),
                  ]))),
                  const SizedBox(height: 32),
                  FadeSlideTransition(delay: const Duration(milliseconds: 400), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Don't have an account? ", style: theme.textTheme.bodyMedium), TextButton(onPressed: () => widget.onNavigate(AuthPage.signUp), child: const Text('Create an account'))])),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
