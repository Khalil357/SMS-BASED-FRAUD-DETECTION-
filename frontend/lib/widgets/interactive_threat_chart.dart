import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_theme.dart';

class InteractiveThreatChart extends StatefulWidget {
  final List<Map<String, dynamic>> logs;

  const InteractiveThreatChart({super.key, required this.logs});

  @override
  State<InteractiveThreatChart> createState() => _InteractiveThreatChartState();
}

class _InteractiveThreatChartState extends State<InteractiveThreatChart> {
  int _selectedTimeframeDays = 7;
  int? _selectedDayIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Process daily stats
    final dailyStats = _calculateDailyStats(_selectedTimeframeDays);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Timeframe Selector & Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Threat Analysis Trends',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Row(
              children: [
                _buildTimeframeChip('7 Days', 7, isDark),
                const SizedBox(width: 6),
                _buildTimeframeChip('30 Days', 30, isDark),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Interactive Bar Chart Container
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDark : AppTheme.cardLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Chart Legend
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLegendItem('Safe', Colors.green, isDark),
                  const SizedBox(width: 16),
                  _buildLegendItem('Fraud', AppTheme.red, isDark),
                ],
              ),
              const SizedBox(height: 20),

              // Bars Canvas
              SizedBox(
                height: 180,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: dailyStats.length > 7 ? const BouncingScrollPhysics() : const NeverScrollableScrollPhysics(),
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 64,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: List.generate(dailyStats.length, (index) {
                        final stat = dailyStats[index];
                        final isSelected = _selectedDayIndex == index;

                        final total = stat['total'] as int;
                        final safeCount = stat['safe'] as int;
                        final fraudCount = stat['fraud'] as int;
                        final maxTotal = dailyStats.map((s) => s['total'] as int).fold(1, max);

                        final barHeightFactor = total == 0 ? 0.08 : (total / maxTotal).clamp(0.12, 1.0);
                        final barWidth = dailyStats.length > 14 ? 12.0 : (dailyStats.length > 7 ? 16.0 : (isSelected ? 22.0 : 16.0));

                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: dailyStats.length > 7 ? 4.0 : 2.0),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDayIndex = _selectedDayIndex == index ? null : index;
                              });
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                // Stacked Bar
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: barWidth,
                                  height: 140 * barHeightFactor,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(alpha: 0.2)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(8),
                                    border: isSelected
                                        ? Border.all(color: theme.colorScheme.primary, width: 2)
                                        : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: total == 0
                                        ? Container(
                                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                          )
                                        : Column(
                                            children: [
                                              if (fraudCount > 0)
                                                Expanded(
                                                  flex: fraudCount,
                                                  child: Container(color: AppTheme.red),
                                                ),
                                              if (safeCount > 0)
                                                Expanded(
                                                  flex: safeCount,
                                                  child: Container(color: Colors.green),
                                                ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Day Label
                                Text(
                                  stat['label'] as String,
                                  style: GoogleFonts.inter(
                                    fontSize: dailyStats.length > 14 ? 8 : 10,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : (isDark ? AppTheme.subtleDark : AppTheme.subtleLight),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Selected Day Interactive Tooltip Details Card
        if (_selectedDayIndex != null && _selectedDayIndex! < dailyStats.length) ...[
          const SizedBox(height: 12),
          _buildDayDetailCard(dailyStats[_selectedDayIndex!], theme, isDark),
        ],
      ],
    );
  }

  Widget _buildTimeframeChip(String label, int days, bool isDark) {
    final isSelected = _selectedTimeframeDays == days;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTimeframeDays = days;
          _selectedDayIndex = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : (isDark ? AppTheme.subtleDark : AppTheme.subtleLight),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
          ),
        ),
      ],
    );
  }

  Widget _buildDayDetailCard(Map<String, dynamic> stat, ThemeData theme, bool isDark) {
    final total = stat['total'] as int;
    final safe = stat['safe'] as int;
    final fraud = stat['fraud'] as int;
    final avgThreat = stat['avgThreat'] as double;

    final safePct = total == 0 ? 0.0 : (safe / total) * 100;
    final fraudPct = total == 0 ? 0.0 : (fraud / total) * 100;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Stats for ${stat['fullDate']}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.primary,
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  setState(() {
                    _selectedDayIndex = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDetailStatItem('Scanned', '$total', isDark),
              _buildDetailStatItem('Safe', '$safe (${safePct.toStringAsFixed(0)}%)', isDark, color: Colors.green),
              _buildDetailStatItem('Fraud', '$fraud (${fraudPct.toStringAsFixed(0)}%)', isDark, color: AppTheme.red),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Average Threat Index: ${(avgThreat * 100).toStringAsFixed(1)}%',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStatItem(String label, String value, bool isDark, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: color ?? (isDark ? Colors.white : Colors.black87),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: isDark ? AppTheme.subtleDark : AppTheme.subtleLight,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _calculateDailyStats(int days) {
    final now = DateTime.now();
    final List<Map<String, dynamic>> stats = [];

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStart = DateTime(date.year, date.month, date.day);
      final dateEnd = dateStart.add(const Duration(days: 1));

      final dayLogs = widget.logs.where((l) {
        try {
          final t = DateTime.parse(l['time'] as String);
          return t.isAfter(dateStart) && t.isBefore(dateEnd);
        } catch (_) {
          return false;
        }
      }).toList();

      final safeCount = dayLogs.where((l) => l['type'] == 'Safe').length;
      final fraudCount = dayLogs.where((l) => l['type'] == 'Fraud').length;

      double avgThreat = 0.0;
      if (dayLogs.isNotEmpty) {
        final totalThreatSum = dayLogs.fold(0.0, (sum, l) => sum + ((l['threat'] as num?)?.toDouble() ?? 0.0));
        avgThreat = totalThreatSum / dayLogs.length;
      }

      final dayName = _getDayLabel(date);
      final fullDate = '${date.day}/${date.month}/${date.year}';

      stats.add({
        'label': dayName,
        'fullDate': fullDate,
        'total': dayLogs.length,
        'safe': safeCount,
        'fraud': fraudCount,
        'avgThreat': avgThreat,
      });
    }

    return stats;
  }

  String _getDayLabel(DateTime dt) {
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[dt.weekday - 1];
  }
}
