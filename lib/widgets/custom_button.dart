import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

enum ButtonType { primary, secondary, ghost }

class CustomButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final bool isLoading;
  final IconData? icon;
  final double? width;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.isLoading = false,
    this.icon,
    this.width,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final primary = isDark ? AppTheme.primaryDark : AppTheme.primaryLight;

    Widget child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.isLoading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.type == ButtonType.primary
                    ? Colors.white
                    : primary,
              ),
            ),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18),
            const SizedBox(width: 8),
          ],
          Text(
            widget.text,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: widget.type == ButtonType.primary ? Colors.white : primary,
            ),
          ),
        ],
      ],
    );

    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => _pressController.forward() : null,
        onTapUp: isEnabled ? (_) => _pressController.reverse() : null,
        onTapCancel: () => _pressController.reverse(),
        onTap: isEnabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: widget.width ?? double.infinity,
          height: 54,
          decoration: _buildDecoration(isDark, isEnabled, primary),
          child: Center(child: child),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration(bool isDark, bool isEnabled, Color primary) {
    switch (widget.type) {
      case ButtonType.primary:
        return BoxDecoration(
          gradient: isEnabled
              ? AppTheme.primaryGradient
              : LinearGradient(
                  colors: [primary.withOpacity(0.5), primary.withOpacity(0.4)],
                ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: isEnabled ? AppTheme.buttonShadow : [],
        );
      case ButtonType.secondary:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled ? primary : primary.withOpacity(0.4),
            width: 1.5,
          ),
        );
      case ButtonType.ghost:
        return BoxDecoration(
          color: primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
        );
    }
  }
}
