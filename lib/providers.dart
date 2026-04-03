import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }
}

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _username;
  bool _isAdmin = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  bool get isAdmin => _isAdmin;

  void login(String username, {bool isAdmin = false}) {
    _isAuthenticated = true;
    _username = username;
    _isAdmin = isAdmin;
    notifyListeners();
  }

  void logout() {
    _isAuthenticated = false;
    _username = null;
    _isAdmin = false;
    notifyListeners();
  }
}
