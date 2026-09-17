import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';

class BlockedNumbersScreen extends StatelessWidget {
  final List<Map<String, String>> blockedNumbers;
  final Function(int) onUnblock;
  final VoidCallback onBack;

  const BlockedNumbersScreen({
    super.key,
    required this.blockedNumbers,
    required this.onUnblock,
    required this.onBack,
  });

  String _formatBlockDate(String isoDate) {
    if (isoDate.isEmpty) return 'recently';
    final date = DateTime.tryParse(isoDate);
    if (date == null) return isoDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(date.year, date.month, date.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.arrow_back,
                        color: theme.brightness == Brightness.dark ? Colors.white : AppTheme.textBodyLight,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Argus',
                          style: GoogleFonts.inter(
                            color: theme.colorScheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Blocked numbers',
                          style: GoogleFonts.inter(
                            color: theme.brightness == Brightness.dark ? Colors.white : AppTheme.textBodyLight,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your block list',
                    style: GoogleFonts.inter(
                      color: theme.brightness == Brightness.dark ? Colors.white : AppTheme.textBodyLight,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Calls and messages from these numbers are kept out of sight. Unblock anytime.',
                    style: GoogleFonts.inter(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.5)
                          : AppTheme.subtleLight.withValues(alpha: 0.7),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                    : AppTheme.cardLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppTheme.borderLight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${blockedNumbers.length} numbers',
                          style: GoogleFonts.inter(
                            color: theme.brightness == Brightness.dark ? Colors.white : AppTheme.textBodyLight,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Currently blocked',
                          style: GoogleFonts.inter(
                            color: theme.brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.5)
                                : AppTheme.subtleLight,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_user_outlined,
                      color: AppTheme.emerald,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Expanded(
              child: blockedNumbers.isEmpty
                  ? Center(
                      child: Text(
                        'No numbers blocked yet',
                        style: GoogleFonts.inter(
                          color: theme.brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.5)
                              : AppTheme.subtleLight,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: blockedNumbers.length,
                      itemBuilder: (context, index) {
                        final item = blockedNumbers[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.dark
                                ? const Color(0xFF1E293B)
                                : AppTheme.cardLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: theme.brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : AppTheme.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.phone_outlined,
                                  color: AppTheme.red,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['number'] ?? 'Unknown',
                                      style: GoogleFonts.inter(
                                        color: theme.brightness == Brightness.dark
                                            ? Colors.white
                                            : AppTheme.textBodyLight,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Blocked ${_formatBlockDate(item['date'] ?? '')} · ${(item['reason'] ?? '').isEmpty ? 'User blocked' : item['reason']}',
                                      style: GoogleFonts.inter(
                                        color: theme.brightness == Brightness.dark
                                            ? Colors.white.withValues(alpha: 0.4)
                                            : AppTheme.subtleLight.withValues(alpha: 0.7),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () => onUnblock(index),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppTheme.red,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: AppTheme.red.withValues(alpha: 0.3),
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Unblock',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white.withValues(alpha: 0.3)
                        : AppTheme.subtleLight.withValues(alpha: 0.5),
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Your blocked list stays private on this device.',
                    style: GoogleFonts.inter(
                      color: theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.3)
                          : AppTheme.subtleLight.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}