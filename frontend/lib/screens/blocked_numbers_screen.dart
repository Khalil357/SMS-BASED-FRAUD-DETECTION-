import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onBack,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 60),
                  Text(
                    'Blocked numbers',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
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
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Calls and messages from these numbers are kept out of sight. Unblock anytime.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Summary Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
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
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Currently blocked',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.5),
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
                    child: const Icon(Icons.verified_user_outlined, color: AppTheme.emerald, size: 24),
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
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
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
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.phone_outlined, color: AppTheme.red, size: 20),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['number'] ?? 'Unknown',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Blocked ${item['date'] ?? 'recently'} · ${item['reason'] ?? 'Scam SMS'}',
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withValues(alpha: 0.4),
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
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(color: AppTheme.red.withValues(alpha: 0.3)),
                                  ),
                                ),
                                child: const Text('Unblock', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                  Icon(Icons.lock_outline, color: Colors.white.withValues(alpha: 0.3), size: 14),
                  const SizedBox(width: 8),
                  Text(
                    'Your blocked list stays private on this device.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.3),
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
