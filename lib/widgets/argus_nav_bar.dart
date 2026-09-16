import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ArgusNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const ArgusNavBar({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  static const List<String> labels = ['Home', 'Scan', 'Blocked', 'Profile'];
  static const List<IconData> icons = [
    Icons.grid_view_outlined,
    Icons.shield_outlined,
    Icons.block,
    Icons.person_outline,
  ];
  static const List<IconData> activeIcons = [
    Icons.grid_view_rounded,
    Icons.shield,
    Icons.block,
    Icons.person,
  ];

  static const Color accent = Color(0xFFEF5350);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      height: 66,
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(33),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: List.generate(4, (i) {
          final active = i == currentIndex;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 28,
                    decoration: BoxDecoration(
                      color: active
                          ? accent.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      active ? activeIcons[i] : icons[i],
                      size: 20,
                      color: active ? accent : muted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    labels[i],
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                      color: active ? accent : muted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}