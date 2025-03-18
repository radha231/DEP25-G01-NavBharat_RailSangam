import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;
  double _textScaleFactor = 1.0;
  double get textScaleFactor => _textScaleFactor;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  // Load theme preference from SharedPreferences
  _loadThemeFromPrefs() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    notifyListeners();
  }

  // Toggle theme and save to SharedPreferences
  void toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }
  void setTextScaleFactor(double factor) {
    _textScaleFactor = factor;
    notifyListeners();
  }

  // Get the current theme
  ThemeData get currentTheme => _isDarkMode
      ? ThemeData.dark().copyWith(
    primaryColor: Colors.black,
    scaffoldBackgroundColor: Colors.black,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.black,
    ),
    colorScheme: ColorScheme.dark(
      primary: Colors.white,
      secondary: Colors.white.withOpacity(0.7),
    ),
  )
      : ThemeData.light().copyWith(
    primaryColor: Colors.white,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
    ),
    colorScheme: ColorScheme.light(
      primary: Colors.black,
      secondary: Colors.black.withOpacity(0.7),
    ),
  );
}