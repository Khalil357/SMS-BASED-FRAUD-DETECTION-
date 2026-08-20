import 'package:flutter/material.dart';

import '../app_theme.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.showHeader = true});
  final Widget child;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final content = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 490),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (Theme.of(context).brightness == Brightness.light)
                const BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 12,
                    offset: Offset(0, 3))
            ],
          ),
          child: Column(children: [
            if (showHeader) const BrandHeader(),
            Expanded(child: child),
            const AppFooter()
          ]),
        ),
      );
      return Center(
          child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 10, vertical: constraints.maxHeight > 700 ? 24 : 6),
        child: SizedBox(height: constraints.maxHeight, child: content),
      ));
    });
  }
}

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});
  @override
  Widget build(BuildContext context) => Container(
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor))),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shield_outlined, color: AppTheme.red, size: 22),
          SizedBox(width: 8),
          Text('Secure Signal',
              style: TextStyle(
                  color: AppTheme.red,
                  fontWeight: FontWeight.w800,
                  fontSize: 19)),
        ]),
      );
}

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});
  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      decoration: BoxDecoration(
          border:
              Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      child: Column(children: [
        Text('© 2024 Secure Signal. All rights reserved.',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: muted)),
        const SizedBox(height: 10),
        const Wrap(
            alignment: WrapAlignment.center,
            spacing: 18,
            runSpacing: 4,
            children: [
              FooterLink('Privacy Policy'),
              FooterLink('Terms of Service'),
              FooterLink('Help Center')
            ]),
      ]),
    );
  }
}

class FooterLink extends StatelessWidget {
  const FooterLink(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) => Text(label,
      style: TextStyle(
          fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant));
}

class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child, this.topAccent = false});
  final Widget child;
  final bool topAccent;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(17, 21, 17, 18),
          decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(8)),
          child: Column(children: [
            if (topAccent)
              const Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                      height: 3,
                      width: double.infinity,
                      child: ColoredBox(color: AppTheme.red))),
            if (topAccent) const SizedBox(height: 15),
            child,
          ]),
        ),
      );
}

class AuthTitle extends StatelessWidget {
  const AuthTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      style: const TextStyle(
          fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -.5));
}

class AuthDescription extends StatelessWidget {
  const AuthDescription(this.text, {super.key, this.trailing});
  final String text;
  final String? trailing;
  @override
  Widget build(BuildContext context) => RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
            style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            children: [
              TextSpan(text: text),
              if (trailing != null)
                TextSpan(
                    text: trailing,
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface)),
            ]),
      );
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700));
}

class AuthField extends StatefulWidget {
  const AuthField(
      {super.key,
      this.label,
      required this.hint,
      this.icon,
      this.obscureText = false,
      this.isDropdown = false,
      this.keyboardType});
  final String? label;
  final String hint;
  final IconData? icon;
  final bool obscureText;
  final bool isDropdown;
  final TextInputType? keyboardType;
  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _obscured = true;
  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(3),
        borderSide: BorderSide(color: Theme.of(context).dividerColor));
    final decoration = InputDecoration(
      hintText: widget.hint,
      hintStyle: TextStyle(
          fontSize: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
      prefixIcon: widget.icon == null
          ? null
          : Icon(widget.icon,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 21),
      suffixIcon: widget.obscureText
          ? IconButton(
              icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20),
              onPressed: () => setState(() => _obscured = !_obscured))
          : widget.isDropdown
              ? const Icon(Icons.keyboard_arrow_down)
              : null,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      border: border,
      enabledBorder: border,
      focusedBorder:
          border.copyWith(borderSide: const BorderSide(color: AppTheme.red)),
    );
    final field = widget.isDropdown
        ? DropdownButtonFormField<String>(
            decoration: decoration,
            items: const [
              DropdownMenuItem(value: '', child: Text('Select your gender')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Male', child: Text('Male'))
            ],
            onChanged: (_) {})
        : TextFormField(
            decoration: decoration,
            obscureText: widget.obscureText && _obscured,
            keyboardType: widget.keyboardType);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.label != null)
        Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: FieldLabel(widget.label!)),
      field
    ]);
  }
}

class AppButton extends StatelessWidget {
  const AppButton({super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      height: 43,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.red,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        child: Text(label),
      ));
}

class AuthLink extends StatelessWidget {
  const AuthLink(this.text,
      {super.key, required this.onTap, this.muted = false});
  final String text;
  final VoidCallback onTap;
  final bool muted;
  @override
  Widget build(BuildContext context) => GestureDetector(
      onTap: onTap,
      child: Text(text,
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muted
                  ? Theme.of(context).colorScheme.onSurfaceVariant
                  : AppTheme.red)));
}

class AuthPrompt extends StatelessWidget {
  const AuthPrompt(
      {super.key,
      required this.prefix,
      required this.link,
      required this.onTap});
  final String prefix;
  final String link;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
        children: [
          TextSpan(text: prefix),
          WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: AuthLink(link, onTap: onTap))
        ],
      ));
}

class SectionDivider extends StatelessWidget {
  const SectionDivider({super.key});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 25),
      child: Divider(color: Theme.of(context).dividerColor, height: 1));
}

class TermsCheckbox extends StatefulWidget {
  const TermsCheckbox({super.key});
  @override
  State<TermsCheckbox> createState() => _TermsCheckboxState();
}

class _TermsCheckboxState extends State<TermsCheckbox> {
  bool selected = false;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 20,
            height: 20,
            child: Checkbox(
                value: selected,
                activeColor: AppTheme.red,
                onChanged: (value) =>
                    setState(() => selected = value ?? false))),
        const SizedBox(width: 5),
        Expanded(
            child: RichText(
                text: TextSpan(
                    style: TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    children: const [
              TextSpan(text: 'I agree to the '),
              TextSpan(
                  text: 'Terms of Service',
                  style: TextStyle(
                      color: AppTheme.red, fontWeight: FontWeight.w600)),
              TextSpan(text: ' and '),
              TextSpan(
                  text: 'Privacy Policy.',
                  style: TextStyle(
                      color: AppTheme.red, fontWeight: FontWeight.w600)),
            ]))),
      ]);
}

class OtpFields extends StatelessWidget {
  const OtpFields({super.key});
  @override
  Widget build(BuildContext context) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(
          6,
          (index) => SizedBox(
                width: 38,
                height: 50,
                child: TextField(
                    maxLength: 1,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 20),
                    decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.zero))),
              )));
}

class PasswordRequirements extends StatelessWidget {
  const PasswordRequirements({super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 5),
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 8),
        decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xff303030)
                : const Color(0xfffafafa),
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PASSWORD REQUIREMENTS',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xffffc0b9)
                      : const Color(0xff6b3b38))),
          const SizedBox(height: 4),
          const Text(
              '•  At least 8 characters long\n•  Contains a number and a symbol\n•  Does not match your previous 3\n   passwords',
              style: TextStyle(fontSize: 12, height: 1.45)),
        ]),
      );
}
