import 'package:flutter/material.dart';

import '../auth_flow.dart';
import '../widgets/auth_widgets.dart';

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key, required this.onNavigate});
  final Navigate onNavigate;

  @override
  Widget build(BuildContext context) => AuthScaffold(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(31, 25, 31, 24),
          child: Column(children: [
            const AuthTitle('Create an Account'),
            const AuthDescription(
                'Join Secure Signal to protect your communications.'),
            const SizedBox(height: 15),
            const AuthField(
                label: 'Full Name',
                hint: 'Enter your full name',
                icon: Icons.person_outline),
            const SizedBox(height: 11),
            const AuthField(
                label: 'Email Address',
                hint: 'Enter your email address',
                icon: Icons.mail_outline,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 11),
            const AuthField(
                label: 'Phone Number',
                hint: 'Enter your phone number',
                icon: Icons.phone_android_outlined,
                keyboardType: TextInputType.phone),
            const SizedBox(height: 11),
            const AuthField(
                label: 'Gender',
                hint: 'Select your gender',
                icon: Icons.group_outlined,
                isDropdown: true),
            const SizedBox(height: 11),
            const AuthField(
                label: 'Password',
                hint: 'Create a password',
                icon: Icons.lock_outline,
                obscureText: true),
            const SizedBox(height: 11),
            const AuthField(
                label: 'Confirm Password',
                hint: 'Confirm your password',
                icon: Icons.lock_reset_outlined,
                obscureText: true),
            const SizedBox(height: 14),
            const TermsCheckbox(),
            const SizedBox(height: 22),
            AppButton(label: 'Sign Up', onPressed: () {}),
            const SectionDivider(),
            AuthPrompt(
                prefix: 'Already have an account? ',
                link: 'Login',
                onTap: () => onNavigate(AuthPage.login)),
          ]),
        ),
      );
}
