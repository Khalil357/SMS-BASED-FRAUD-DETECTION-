import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const red = Color(0xffe60000);
  static const darkSurface = Color(0xff121212);
  static const darkCanvas = Color(0xff202020);

  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
        seedColor: red,
        brightness: brightness,
        primary: red,
        surface: isDark ? darkSurface : Colors.white);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? darkCanvas : const Color(0xfff4f4f4),
      fontFamily: 'Inter',
      textTheme: ThemeData(brightness: brightness).textTheme.apply(
            fontFamily: 'Inter',
            bodyColor:
                isDark ? const Color(0xfff0eeee) : const Color(0xff202124),
            displayColor:
                isDark ? const Color(0xfff0eeee) : const Color(0xff202124),
          ),
    );
  }
}
