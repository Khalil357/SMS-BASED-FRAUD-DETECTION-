import 'package:flutter/material.dart';

import '../auth_flow.dart';
import '../services/auth_service.dart';
import '../widgets/auth_widgets.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key, required this.onNavigate});
  final Navigate onNavigate;

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _genderController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _genderController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    setState(() => _errorMessage = null);

    if (_nameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _genderController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    if (!_termsAccepted) {
      setState(() => _errorMessage = 'Please accept the terms and conditions');
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.signUp(
      fullName: _nameController.text,
      email: _emailController.text,
      phoneNumber: _phoneController.text,
      gender: _genderController.text,
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'])),
      );
      widget.onNavigate(AuthPage.login);
    } else {
      setState(() => _errorMessage = result['message']);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(31, 25, 31, 24),
          child: Column(children: [
            const AuthTitle('Create an Account'),
            const AuthDescription(
                'Join Secure Signal to protect your communications.'),
            const SizedBox(height: 15),
            AuthFieldWithController(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Enter your full name',
                icon: Icons.person_outline),
            const SizedBox(height: 11),
            AuthFieldWithController(
                controller: _emailController,
                label: 'Email Address',
                hint: 'Enter your email address',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 11),
            AuthFieldWithController(
                controller: _phoneController,
                label: 'Phone Number',
                hint: 'Enter your phone number',
                icon: Icons.phone_android_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 11),
            GenderDropdown(controller: _genderController),
            const SizedBox(height: 11),
            AuthFieldWithController(
                controller: _passwordController,
                label: 'Password',
                hint: 'Create a password',
                icon: Icons.lock_outline,
                obscureText: true),
            const SizedBox(height: 11),
            AuthFieldWithController(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                hint: 'Confirm your password',
                icon: Icons.lock_reset_outlined,
                obscureText: true),
            const SizedBox(height: 14),
            TermsCheckboxWithCallback(
              onChanged: (value) => setState(() => _termsAccepted = value),
            ),
            const SizedBox(height: 22),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                      color: Color(0xffd32f2f), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ),
            AppButton(
                label: _isLoading ? 'Signing up...' : 'Sign Up',
                onPressed: _isLoading ? null : _handleSignUp),
            const SectionDivider(),
            AuthPrompt(
                prefix: 'Already have an account? ',
                link: 'Login',
                onTap: () => widget.onNavigate(AuthPage.login)),
          ]),
        ),
      );
}
