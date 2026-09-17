import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class OtpInputField extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;

  const OtpInputField({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String val) {
    setState(() {}); // Instant re-render so typed digits appear immediately
    widget.onChanged(val);

    if (val.length == widget.length && widget.onCompleted != null) {
      // Schedule completion callback after frame renders so UI doesn't freeze during typing
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.text.length == widget.length) {
          widget.onCompleted!(val);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Hidden input field capturing soft-keyboard typing, backspaces, and pastes
        Positioned(
          left: 0,
          top: 0,
          width: 1,
          height: 1,
          child: Opacity(
            opacity: 0.0,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              autofocus: true,
              showCursor: false,
              enableInteractiveSelection: true,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
              ),
              onChanged: _onTextChanged,
            ),
          ),
        ),

        // Visual OTP Boxes
        GestureDetector(
          onTap: () {
            if (!_focusNode.hasFocus) {
              _focusNode.requestFocus();
            }
          },
          behavior: HitTestBehavior.opaque,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.length, (index) {
                final text = _controller.text;
                final char = index < text.length ? text[index] : '';
                final isBoxFocused = _focusNode.hasFocus &&
                    (index == text.length || (index == widget.length - 1 && text.length == widget.length));

return Container(
                   margin: const EdgeInsets.symmetric(horizontal: 5),
                   width: 45,
                   height: 55,
                   decoration: BoxDecoration(
                     borderRadius: BorderRadius.circular(16),
                     color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
                     border: Border.all(
                       color: isBoxFocused
                           ? theme.primaryColor
                           : (isDark
                               ? const Color(0xFF334155)
                               : const Color(0xFFE2E8F0)),
                       width: isBoxFocused ? 2.5 : 1.5,
                     ),
                     boxShadow: isBoxFocused
                         ? [
                             BoxShadow(
                               color: theme.primaryColor.withValues(alpha: 0.15),
                               blurRadius: 16,
                               offset: const Offset(0, 4),
                             )
                           ]
                         : [],
                   ),
                   alignment: Alignment.center,
                   child: Text(
                     char,
                     style: GoogleFonts.inter(
                       fontSize: 20,
                       fontWeight: FontWeight.bold,
                       color: theme.colorScheme.primary,
                     ),
                   ),
                 );
              }),
            ),
          ),
        ),
      ],
    );
  }
}
