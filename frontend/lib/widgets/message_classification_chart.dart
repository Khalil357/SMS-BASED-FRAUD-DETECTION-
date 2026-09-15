import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class MessageClassificationChart extends StatefulWidget {
  final List<Map<String, dynamic>> logs;

  const MessageClassificationChart({super.key, required this.logs});

  @override
  State<MessageClassificationChart> createState() => _MessageClassificationChartState();
}

class _MessageClassificationChartState extends State<MessageClassificationChart>
    with SingleTickerProviderStateMixin {
  int? _selectedIndex;
  late AnimationController _animController;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _anim = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }

  @override
  void didUpdateWidget(covariant MessageClassificationChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.logs.length != widget.logs.length) {
      _animController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  List<_ClassificationSlice> _computeSlices() {
    if (widget.logs.isEmpty) return [];

    int safeCount = 0;
    int spamCount = 0;
    int fraudCount = 0;

    for (final log in widget.logs) {
      final type = (log['type'] as String? ?? 'Safe').trim();
      final msg = (log['message'] as String? ?? '').toLowerCase();

      if (type == 'Safe') {
        safeCount++;
      } else if (type == 'Spam' || msg.contains('discount') || msg.contains('offer') || msg.contains('sale') || msg.contains('promo')) {
        spamCount++;
      } else {
        fraudCount++;
      }
    }

    final total = widget.logs.length;
    final List<_ClassificationSlice> slices = [];

    // Safe Messages Slice
    if (safeCount > 0) {
      slices.add(_ClassificationSlice(
        label: 'Safe Messages',
        count: safeCount,
        percentage: (safeCount / total) * 100,
        color: AppTheme.cyberGreen,
        icon: Icons.shield_rounded,
      ));
    }

    // Fraud & Phishing Messages Slice
    if (fraudCount > 0) {
      slices.add(_ClassificationSlice(
        label: 'Fraud & Phishing',
        count: fraudCount,
        percentage: (fraudCount / total) * 100,
        color: AppTheme.cyberRed,
        icon: Icons.gpp_bad_rounded,
      ));
    }

    // Spam & Promotional Messages Slice
    if (spamCount > 0) {
      slices.add(_ClassificationSlice(
        label: 'Spam & Promos',
        count: spamCount,
        percentage: (spamCount / total) * 100,
        color: AppTheme.cyberCyan,
        icon: Icons.mark_email_unread_rounded,
      ));
    }

    return slices;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final slices = _computeSlices();
    final totalCount = widget.logs.length;

    final cardBg = isDark ? AppTheme.cyberCard : AppTheme.cardLight;
    final borderColor = isDark ? AppTheme.cyberBorder : AppTheme.borderLight;
    final textPrimary = isDark ? AppTheme.cyberTextPrimary : AppTheme.textBodyLight;
    final textMuted = isDark ? AppTheme.cyberTextMuted : AppTheme.subtleLight;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MESSAGE CLASSIFICATION',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.cyberCyan,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Threat Distribution',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.cyberCyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cyberCyan.withOpacity(0.3)),
                ),
                child: Text(
                  '$totalCount Analyzed',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.cyberCyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          if (slices.isEmpty)
            _buildEmptyState(isDark, textMuted)
          else ...[
            // Donut Chart & Highlight Center Display
            AnimatedBuilder(
              animation: _anim,
              builder: (context, child) {
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final chartSize = min(170.0, constraints.maxWidth * 0.45);
                    final selectedSlice = _selectedIndex != null && _selectedIndex! < slices.length
                        ? slices[_selectedIndex!]
                        : null;

                    return Row(
                      children: [
                        // Interactive CustomPainter Donut
                        GestureDetector(
                          onTapDown: (details) {
                            _handleTap(details.localPosition, chartSize, slices);
                          },
                          child: SizedBox(
                            width: chartSize,
                            height: chartSize,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: Size(chartSize, chartSize),
                                  painter: _DonutChartPainter(
                                    slices: slices,
                                    selectedIndex: _selectedIndex,
                                    progress: _anim.value,
                                    isDark: isDark,
                                  ),
                                ),
                                // Inner Donut Hole Display
                                Container(
                                  width: chartSize * 0.58,
                                  height: chartSize * 0.58,
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.3),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        selectedSlice != null
                                            ? '${selectedSlice.percentage.toStringAsFixed(0)}%'
                                            : '${slices.first.percentage.toStringAsFixed(0)}%',
                                        style: GoogleFonts.inter(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          color: selectedSlice?.color ?? slices.first.color,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        selectedSlice != null
                                            ? selectedSlice.label.split(' ').first
                                            : slices.first.label.split(' ').first,
                                        style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: textMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Legend / Detailed Breakdown Slices List
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: List.generate(slices.length, (idx) {
                              final slice = slices[idx];
                              final isSelected = _selectedIndex == idx;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedIndex = _selectedIndex == idx ? null : idx;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? slice.color.withOpacity(0.15)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(10),
                                      border: isSelected
                                          ? Border.all(color: slice.color.withOpacity(0.4), width: 1)
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: slice.color,
                                            shape: BoxShape.circle,
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: slice.color.withOpacity(0.6),
                                                      blurRadius: 6,
                                                      spreadRadius: 1,
                                                    ),
                                                  ]
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            slice.label,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                              color: isSelected ? slice.color : textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          '${slice.count}',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  void _handleTap(Offset localPos, double size, List<_ClassificationSlice> slices) {
    final center = Offset(size / 2, size / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final radius = sqrt(dx * dx + dy * dy);

    final outerR = size / 2;
    final innerR = outerR * 0.58;

    if (radius < innerR || radius > outerR) {
      return; // Tapped outside donut ring
    }

    var angle = atan2(dy, dx);
    if (angle < 0) angle += 2 * pi;

    // Slices start at -pi / 2 (top)
    var relativeAngle = (angle + pi / 2) % (2 * pi);

    double currentAngle = 0;
    for (int i = 0; i < slices.length; i++) {
      final sweepAngle = (slices[i].percentage / 100) * 2 * pi;
      if (relativeAngle >= currentAngle && relativeAngle <= currentAngle + sweepAngle) {
        setState(() {
          _selectedIndex = _selectedIndex == i ? null : i;
        });
        break;
      }
      currentAngle += sweepAngle;
    }
  }

  Widget _buildEmptyState(bool isDark, Color textMuted) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(
            Icons.pie_chart_outline_rounded,
            size: 40,
            color: textMuted.withOpacity(0.5),
          ),
          const SizedBox(height: 8),
          Text(
            'No Classification Data Available',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan messages to see real-time threat distribution.',
            style: GoogleFonts.inter(
              fontSize: 11,
              color: textMuted.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ClassificationSlice {
  final String label;
  final int count;
  final double percentage;
  final Color color;
  final IconData icon;

  _ClassificationSlice({
    required this.label,
    required this.count,
    required this.percentage,
    required this.color,
    required this.icon,
  });
}

class _DonutChartPainter extends CustomPainter {
  final List<_ClassificationSlice> slices;
  final int? selectedIndex;
  final double progress;
  final bool isDark;

  _DonutChartPainter({
    required this.slices,
    required this.selectedIndex,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;
    final strokeWidth = outerRadius * 0.38;
    final drawRadius = outerRadius - strokeWidth / 2;

    double startAngle = -pi / 2; // Start from 12 o'clock

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    for (int i = 0; i < slices.length; i++) {
      final slice = slices[i];
      final sweepAngle = (slice.percentage / 100) * 2 * pi * progress;

      final isSelected = selectedIndex == i;
      final currentStroke = isSelected ? strokeWidth * 1.12 : strokeWidth;

      paint.color = slice.color;
      paint.strokeWidth = currentStroke;

      if (isSelected) {
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = currentStroke + 4
          ..color = slice.color.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: drawRadius),
          startAngle,
          sweepAngle,
          false,
          glowPaint,
        );
      }

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: drawRadius),
        startAngle + (sweepAngle > 0.05 ? 0.02 : 0),
        max(0.01, sweepAngle - (slices.length > 1 ? 0.04 : 0)),
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.progress != progress ||
        oldDelegate.slices != slices;
  }
}
