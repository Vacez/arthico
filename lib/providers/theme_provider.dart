import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  // --- Dark Theme Colors ---
  static const darkBg = Color(0xFF0F172A);
  static const darkCard = Color(0xFF1E293B);
  static const darkInputBg = Color(0xFF0F172A);
  static const darkAccent = Color(0xFF818CF8);
  static const darkTextPrimary = Colors.white;
  static const darkTextSecondary = Colors.white60;
  static const darkTextMuted = Colors.white38;
  static const darkBorder = Colors.white12;

  // --- Light Theme Colors ---
  static const lightBg = Color(0xFFF1F5F9);
  static const lightCard = Colors.white;
  static const lightInputBg = Color(0xFFF8FAFC);
  static const lightAccent = Color(0xFF6366F1);
  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF475569);
  static const lightTextMuted = Color(0xFF94A3B8);
  static const lightBorder = Color(0xFFE2E8F0);

  // Convenience getters
  Color get bg => isDark ? darkBg : lightBg;
  Color get card => isDark ? darkCard : lightCard;
  Color get inputBg => isDark ? darkInputBg : lightInputBg;
  Color get accent => isDark ? darkAccent : lightAccent;
  Color get textPrimary => isDark ? darkTextPrimary : lightTextPrimary;
  Color get textSecondary => isDark ? darkTextSecondary : lightTextSecondary;
  Color get textMuted => isDark ? darkTextMuted : lightTextMuted;
  Color get border => isDark ? darkBorder : lightBorder;
  Color get navBg => isDark ? darkCard : Colors.white;
  Color get navBorder => isDark ? Colors.white10 : const Color(0xFFE2E8F0);

  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.blue,
    useMaterial3: true,
    scaffoldBackgroundColor: darkBg,
    cardColor: darkCard,
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF6366F1),
      secondary: Color(0xFF818CF8),
      surface: darkCard,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.blue,
    useMaterial3: true,
    scaffoldBackgroundColor: lightBg,
    cardColor: lightCard,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF6366F1),
      secondary: Color(0xFF818CF8),
      surface: Colors.white,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
