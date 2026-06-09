import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  // Start with system theme; you can change to light/dark default if you like.
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  // Pass true to enable dark mode, false for light mode.
  void toggleTheme(bool isOn) {
    _themeMode = isOn ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
