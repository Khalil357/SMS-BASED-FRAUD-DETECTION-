import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

// ─────────────────────────────────────────────────────────────
//  Terms & Conditions + Privacy Policy acceptance screen
// ─────────────────────────────────────────────────────────────

class TermsAndConditionsPage extends StatefulWidget {
  /// Whether this screen is opened during account creation (showing acceptance checkbox and accept button),
  /// or simply for re-reviewing from the profile tab (read-only mode).
  final bool isAcceptanceMode;

  /// Called when the user taps Accept (checkbox must be checked first).
  final VoidCallback? onAccepted;

  /// Called when the user taps the close ✕ icon.
  final VoidCallback? onClose;

  const TermsAndConditionsPage({
    super.key,
    this.isAcceptanceMode = false,
    this.onAccepted,
    this.onClose,
  });

  @override
  State<TermsAndConditionsPage> createState() => _TermsAndConditionsPageState();
}

class _TermsAndConditionsPageState extends State<TermsAndConditionsPage> {
  bool _accepted = false;

  // Independent scroll controllers for each document card.
  final ScrollController _termsScrollController = ScrollController();
  final ScrollController _privacyScrollController = ScrollController();

  @override
  void dispose() {
    _termsScrollController.dispose();
    _privacyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color accent =
        isDark ? AppTheme.primaryDark : AppTheme.primaryLight;
    final Color bg =
        isDark ? AppTheme.bgDark : AppTheme.bgLight;
    final Color cardBg =
        isDark ? AppTheme.cardDark : AppTheme.cardLight;
    final Color headingColor =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final Color bodyColor =
        isDark ? AppTheme.textBodyDark : AppTheme.textBodyLight;
    final Color subtleColor =
        isDark ? AppTheme.subtleDark : AppTheme.subtleLight;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 18.0, bottom: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Argus',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: -0.3,
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onClose ?? () => Navigator.of(context).pop(),
                      child: Icon(Icons.close, size: 22, color: subtleColor),
                    ),
                  ],
                ),
              ),

              // ── Terms & Conditions heading ────────────────────────
              Text(
                'Terms & Conditions',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: headingColor,
                ),
              ),
              const SizedBox(height: 8),

              // ── Terms card (Fills space) ─────────────────────────
              Expanded(
                flex: 1,
                child: _DocumentCard(
                  scrollController: _termsScrollController,
                  cardBg: cardBg,
                  bodyColor: bodyColor,
                  content: _kTermsContent,
                ),
              ),

              const SizedBox(height: 16),

              // ── Privacy Policy heading ────────────────────────────
              Text(
                'Privacy Policy',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: headingColor,
                ),
              ),
              const SizedBox(height: 8),

              // ── Privacy card (Fills space) ────────────────────────
              Expanded(
                flex: 1,
                child: _DocumentCard(
                  scrollController: _privacyScrollController,
                  cardBg: cardBg,
                  bodyColor: bodyColor,
                  content: _kPrivacyContent,
                ),
              ),

              // ── Acceptance controls (ONLY shown during Account Creation) ──
              if (widget.isAcceptanceMode) ...[
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _CoralCheckbox(
                      value: _accepted,
                      accent: accent,
                      onChanged: (val) {
                        setState(() => _accepted = val ?? false);
                      },
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'By clicking you are accepting the updated Argus\nTerms and Conditions and privacy Policy',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: bodyColor,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: _AcceptButton(
                    enabled: _accepted,
                    accent: accent,
                    onPressed: () {
                      widget.onAccepted?.call();
                      Navigator.of(context).pop(true);
                    },
                  ),
                ),
              ],

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Reusable scrollable document card
// ─────────────────────────────────────────────────────────────

class _DocumentCard extends StatelessWidget {
  final ScrollController scrollController;
  final Color cardBg;
  final Color bodyColor;
  final String content;

  const _DocumentCard({
    required this.scrollController,
    required this.cardBg,
    required this.bodyColor,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          child: Text(
            content,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              color: bodyColor,
              height: 1.55,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Coral-outlined checkbox with coral fill when checked
// ─────────────────────────────────────────────────────────────

class _CoralCheckbox extends StatelessWidget {
  final bool value;
  final Color accent;
  final ValueChanged<bool?> onChanged;

  const _CoralCheckbox({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: value ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: accent,
            width: 2,
          ),
        ),
        child: value
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Pill-shaped Accept button
// ─────────────────────────────────────────────────────────────

class _AcceptButton extends StatelessWidget {
  final bool enabled;
  final Color accent;
  final VoidCallback onPressed;

  const _AcceptButton({
    required this.enabled,
    required this.accent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = enabled ? accent : accent.withValues(alpha: 0.38);

    return GestureDetector(
      onTap: enabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 172,
        height: 34,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          'Accept',
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  Helper to push the page from anywhere
// ─────────────────────────────────────────────────────────────

Future<bool?> showTermsAndConditionsPage(
  BuildContext context, {
  bool isAcceptanceMode = false,
  VoidCallback? onAccepted,
}) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TermsAndConditionsPage(
        isAcceptanceMode: isAcceptanceMode,
        onAccepted: onAccepted,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  Document content strings
// ─────────────────────────────────────────────────────────────

const String _kTermsContent = '''TERMS AND CONDITIONS
Last Updated: 16th September, 2026

Welcome to Argus. By creating an account or using this App, you agree to these Terms. If you do not agree, please do not use the App.

1. Use of the App
Argus helps users identify potentially fraudulent SMS messages, showing a result with a fraud confidence level where applicable. It does not guarantee correct identification of every message.

2. Registration and Account
Registration requires your name and phone number. You must provide accurate information, use the App lawfully, and are responsible for your account's security and activity.

3. SMS Permission
The App may need SMS access permission to detect fraud. You may disable this in device settings, though some features may then stop working.

4. Fraud Detection
Results are an indication, not a guarantee. Use your own judgment before:
• Responding to a suspicious message
• Clicking links in a message
• Sharing personal or financial information
• Sending money
• Following instructions from an unknown sender

5. Reporting Suspected Fraud
You may report suspected fraud to the relevant telecom authority through the App. Submitted reports must be truthful; we do not guarantee any resulting action.

6. User Responsibilities
You agree to use the App lawfully and responsibly, give accurate registration details, keep your account secure, avoid misuse or unauthorized access, and review fraud warnings carefully.

7. Prohibited Activities
You must not access others accounts, bypass security, reverse-engineer or copy the App, distribute unlawful content, remove IP notices, interfere with operations, or otherwise break applicable laws.

8. Privacy
Our Privacy Policy explains how your information is collected, used, and protected. Using the App means you have read and understood it.

9. Accuracy and Reliability
We do not guarantee the App will always correctly identify fraudulent or legitimate messages, as fraud tactics evolve. You remain responsible for verifying suspicious communications before acting.

10. Availability of the App
We aim to keep the App available but do not guarantee uninterrupted, secure, or error-free service, especially during maintenance or technical issues.

11. Third-Party Services
The App may rely on third-party services; we are not responsible for their interruptions or changes.

12. Limitation of Liability
To the extent permitted by law, Argus is not liable for losses from incorrect or missed fraud detections, user actions taken in response to an SMS, financial transactions, or temporary unavailability. Argus assists but does not replace personal judgment.

13. Intellectual Property
All rights in the App -- technology, design, trademarks, and content -- remain ours. Using the App grants no ownership or license beyond what these Terms allow. Other IP use requires a separate Licensing Partner Agreement; contact feedback@argus.com for permission inquiries.

14. Suspension or Termination
We may suspend or terminate access immediately, without notice, for violations or misuse. You may stop using the App at any time.

15. Changes to These Terms
We may update these Terms and will provide notice of significant changes. Continued use after updates means you accept them.

16. Governing Law
These Terms are governed by Tanzania Personal Data Protection Act. We process personal information lawfully, fairly, and transparently, following data minimisation, accuracy, and confidentiality principles.

17. Contact Us
Questions or complaints about these Terms can be sent to feedback@argus.com.

App Name: Argus
Developer/Organization: Argus
Email: argus@co.tz''';

const String _kPrivacyContent = '''Privacy Policy

This Privacy Policy explains how Argus collects, uses, stores, protects, and handles information when you use our application.

By using the application, you acknowledge that you have read and understood this Privacy Policy.

1. Information We Collect
Depending on the features you use, we may collect or process the following information:

• SMS Messages
With your permission, the application access and read SMS messages on your device. This access is required to provide the application SMS-related features.

• Account Information
The application will collect information such as your name, email address, phone number, or other information you provide when creating your account.

• Usage Information
We will collect information about how you use the application, such as interactions with features, preferences, and technical information needed to operate and improve the application.

• Technical information
Information such as Phone brand and model, Operating system, Firmware version, Hardware capabilities, Language and locale, Battery state, Memory consumption, Time since last reboot and Location information.

2. How We Use Your Information
• Information collected through the application will be used to:
• Provide and operate the application features.
• Analyze SMS messages when you have granted the required permission.
• Display results and information within the application.
• Maintain and improve the application.
• Detect, prevent, and address misuse or security issues.
• Communicate with you when necessary regarding the application.

We will only use your information for legitimate purposes related to providing and improving the application services.

3. SMS Permission
The application will request permission before accessing SMS messages on your device. You have the right to deny this permission. You may also withdraw the permission at any time through your device settings.

If you deny or withdraw SMS permission, certain features that require access to SMS messages may not be available.

4. Storage of Information
Information processed by the application may be stored on your device and/or on our servers, depending on how the application features are implemented.

We retain information only for as long as reasonably necessary to provide our services, meet operational requirements, or comply with applicable legal obligations.

5. Sharing of Information
We do not sell your personal information.

We may share information only when necessary to provide the application services, protect the application and its users, comply with legal requirements, or with your consent where required.

Any third-party services used by the application may process information according to their own privacy policies.

6. Data Security
We take reasonable technical and organizational measures to protect information processed through the application against unauthorized access, loss, misuse, alteration, or disclosure. However, no electronic storage or transmission method can be guaranteed to be completely secure.

7. Your Rights and Choices
You have the right to:
• Deny or withdraw SMS access permission.
• Request information about the personal data we hold about you.
• Request correction of inaccurate information.
• Request deletion of your information where applicable.
• Stop using the application at any time.

The rights are applicable laws and legitimate operational or legal requirements.

8. For how long do you keep my data?
The duration of data.

Detailed information about location is kept no longer than 12 months after it has been collected.

9. Changes to This Privacy Policy
We may update this Privacy Policy from time to time.

When changes are made, the updated version will be made available within the application. The Last Updated date at the beginning of this policy will also be updated.

We encourage users to review this Privacy Policy periodically.

10. Contact Us
If you have questions, concerns, or requests regarding this Privacy Policy or the way your information is handled, please contact us at argus@co.tz.

By using the application, you acknowledge that you have read and understood this Privacy Policy.''';
