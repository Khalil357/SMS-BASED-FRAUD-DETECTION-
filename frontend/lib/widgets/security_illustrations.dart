import 'dart:math';
import 'package:flutter/material.dart';
import '../app_theme.dart';

/// Active Security Shield Custom Painter Illustration
class ShieldActiveIllustration extends StatelessWidget {
  final double size;
  const ShieldActiveIllustration({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShieldPainter(
          primaryColor: primaryColor,
          accentColor: AppTheme.emerald,
          isDark: isDark,
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final Color primaryColor;
  final Color accentColor;
  final bool isDark;

  _ShieldPainter({
    required this.primaryColor,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final width = size.width;
    final height = size.height;

    // 1. Background Radar Circles
    final radarPaint = Paint()
      ..color = (isDark ? primaryColor.withOpacity(0.12) : primaryColor.withOpacity(0.08))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, width * 0.45, radarPaint);
    canvas.drawCircle(center, width * 0.35, radarPaint);

    // 2. Shield Glow
    final glowPaint = Paint()
      ..color = accentColor.withOpacity(isDark ? 0.25 : 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);

    final shieldPath = Path()
      ..moveTo(width * 0.5, height * 0.12)
      ..cubicTo(width * 0.75, height * 0.12, width * 0.85, height * 0.22, width * 0.85, height * 0.40)
      ..cubicTo(width * 0.85, height * 0.70, width * 0.5, height * 0.88, width * 0.5, height * 0.88)
      ..cubicTo(width * 0.5, height * 0.88, width * 0.15, height * 0.70, width * 0.15, height * 0.40)
      ..cubicTo(width * 0.15, height * 0.22, width * 0.25, height * 0.12, width * 0.5, height * 0.12)
      ..close();

    canvas.drawPath(shieldPath, glowPaint);

    // 3. Shield Gradient Fill
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor,
        primaryColor.withBlue(min(255, primaryColor.blue + 30)),
        accentColor,
      ],
    );

    final shieldFillPaint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, width, height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(shieldPath, shieldFillPaint);

    // 4. Shield Border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(shieldPath, borderPaint);

    // 5. Center Checkmark Icon
    final checkPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width * 0.06;

    final checkPath = Path()
      ..moveTo(width * 0.38, height * 0.48)
      ..lineTo(width * 0.47, height * 0.57)
      ..lineTo(width * 0.63, height * 0.39);

    canvas.drawPath(checkPath, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Phishing Threat Warning Custom Painter Illustration
class PhishingWarningIllustration extends StatelessWidget {
  final double size;
  const PhishingWarningIllustration({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PhishingWarningPainter(isDark: isDark),
      ),
    );
  }
}

class _PhishingWarningPainter extends CustomPainter {
  final bool isDark;

  _PhishingWarningPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Background Warning Circle
    final bgPaint = Paint()
      ..color = AppTheme.red.withOpacity(isDark ? 0.2 : 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(width / 2, height / 2), width * 0.45, bgPaint);

    // Warning Triangle
    final triPath = Path()
      ..moveTo(width * 0.5, height * 0.15)
      ..lineTo(width * 0.85, height * 0.78)
      ..lineTo(width * 0.15, height * 0.78)
      ..close();

    final triPaint = Paint()
      ..color = AppTheme.red
      ..style = PaintingStyle.fill;
    canvas.drawPath(triPath, triPaint);

    // Exclamation Mark inside Triangle
    final markPaint = Paint()
      ..color = Colors.white
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width * 0.05;

    canvas.drawLine(
      Offset(width * 0.5, height * 0.35),
      Offset(width * 0.5, height * 0.56),
      markPaint,
    );

    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(width * 0.5, height * 0.67), width * 0.035, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Safety Brain & Awareness Illustration
class SafetyBrainIllustration extends StatelessWidget {
  final double size;
  const SafetyBrainIllustration({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SafetyBrainPainter(primaryColor: primaryColor, isDark: isDark),
      ),
    );
  }
}

class _SafetyBrainPainter extends CustomPainter {
  final Color primaryColor;
  final bool isDark;

  _SafetyBrainPainter({required this.primaryColor, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final center = Offset(width / 2, height / 2);

    // Outer Light Ring
    final ringPaint = Paint()
      ..color = primaryColor.withOpacity(isDark ? 0.2 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, width * 0.42, ringPaint);

    // Inner Bulb / Shield Graphic
    final bulbPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, width * 0.28, bulbPaint);

    // Light Rays
    final rayPaint = Paint()
      ..color = AppTheme.amber
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.5;

    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * pi / 180;
      final start = Offset(center.dx + cos(angle) * width * 0.32, center.dy + sin(angle) * height * 0.32);
      final end = Offset(center.dx + cos(angle) * width * 0.40, center.dy + sin(angle) * height * 0.40);
      canvas.drawLine(start, end, rayPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Quiz Victory Star Badge Illustration
class QuizVictoryIllustration extends StatelessWidget {
  final double size;
  const QuizVictoryIllustration({super.key, this.size = 110});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _QuizVictoryPainter(),
      ),
    );
  }
}

class _QuizVictoryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final center = Offset(width / 2, height / 2);

    // Gold Hexagon/Circle Badge
    final badgePaint = Paint()
      ..color = AppTheme.amber
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, width * 0.42, badgePaint);

    // Inner Ring
    final innerRing = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, width * 0.36, innerRing);

    // Star in Center
    final starPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final starPath = _createStarPath(center, width * 0.24, width * 0.12, 5);
    canvas.drawPath(starPath, starPaint);
  }

  Path _createStarPath(Offset center, double outerRadius, double innerRadius, int points) {
    final path = Path();
    final step = pi / points;
    double angle = -pi / 2;

    for (int i = 0; i < 2 * points; i++) {
      final r = i % 2 == 0 ? outerRadius : innerRadius;
      final x = center.dx + cos(angle) * r;
      final y = center.dy + sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      angle += step;
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
