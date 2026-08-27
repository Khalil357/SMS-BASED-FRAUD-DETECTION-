import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../auth_flow.dart';
import '../services/auth_service.dart';
import '../services/token_storage.dart';
import '../widgets/auth_widgets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onNavigate});
  final Navigate onNavigate;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _errorMessage = null);

    if (_phoneController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.login(
      phoneNumber: _phoneController.text,
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success'] == true) {
      final token = result['token']?.toString();
      if (token == null || token.isEmpty) {
        setState(() => _errorMessage = 'Login succeeded but no token returned');
        return;
      }
      await TokenStorage.save(token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(result['message']?.toString() ?? 'Login successful')),
      );
      widget.onNavigate(AuthPage.home);
    } else {
      setState(() => _errorMessage = result['message']?.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        showHeader: false,
        child: Container(
          decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: AppTheme.red, width: 4))),
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 28),
              child: Column(children: [
                const Icon(Icons.shield_outlined,
                    color: AppTheme.red, size: 42),
                const SizedBox(height: 12),
                const AuthTitle('Secure Signal'),
                const AuthDescription('Sign in to monitor and manage alerts.'),
                const SizedBox(height: 18),
                AuthFieldWithController(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'e.g. +27 82 123 4567',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 11),
                Row(children: [
                  const FieldLabel('Password'),
                  const Spacer(),
                  AuthLink('Forgot Password?',
                      onTap: () => widget.onNavigate(AuthPage.forgotPassword)),
                ]),
                const SizedBox(height: 5),
                AuthFieldWithController(
                    controller: _passwordController,
                    hint: 'Enter your password',
                    icon: Icons.lock_outline,
                    obscureText: true),
                const SizedBox(height: 21),
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
                    label: _isLoading ? 'Logging in...' : 'Login  →',
                    onPressed: _isLoading ? null : _handleLogin),
                const SectionDivider(),
                AuthPrompt(
                    prefix: 'New to Secure Signal? ',
                    link: 'Create an Account',
                    onTap: () => widget.onNavigate(AuthPage.signUp)),
              ]),
            ),
          ),
        ),
      );
}
