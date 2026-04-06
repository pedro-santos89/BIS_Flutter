import 'package:flutter/material.dart';

/// Manages app-wide UI preferences: theme mode, text scaling, and locale.
/// Consumed via Provider throughout the widget tree.
class ThemeProvider extends ChangeNotifier {
  /// The default text scale factor. 1.4 maps to "100%" in the UI.
  /// All text scaling is relative to this base value.
  static const double _baseScale = 1.4;

  /// Current theme mode (dark or light). Defaults to dark.
  ThemeMode _themeMode = ThemeMode.dark;

  /// Current text scale factor applied via MediaQuery. Defaults to [_baseScale].
  double _textScale = _baseScale;

  /// Current app locale for translations. Defaults to Portuguese ('pt').
  Locale _locale = const Locale('pt');

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  double get textScale => _textScale;

  /// Returns text scale as a percentage relative to [_baseScale].
  /// e.g. _baseScale=1.4 → 100%, 1.54 → 110%, 1.0 → 71%.
  int get textScalePercent => ((_textScale / _baseScale) * 100).round();
  Locale get locale => _locale;

  /// Toggles between Portuguese ('pt') and English ('en').
  void toggleLocale() {
    _locale = _locale.languageCode == 'pt' ? const Locale('en') : const Locale('pt');
    notifyListeners();
  }

  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    _themeMode = mode;
    notifyListeners();
  }

  /// Increases text scale by 0.1 up to a maximum of 2.0.
  void increaseTextScale() {
    if (_textScale < 2.0) {
      _textScale += 0.1;
      notifyListeners();
    }
  }

  /// Decreases text scale by 0.1 down to a minimum of 1.0.
  void decreaseTextScale() {
    if (_textScale > 1.0) {
      _textScale -= 0.1;
      notifyListeners();
    }
  }

  /// Resets text scale back to [_baseScale] (100%).
  void resetTextScale() {
    _textScale = _baseScale;
    notifyListeners();
  }
}

/// Manages authentication state for the current user session.
/// Not persisted — resets when the app restarts.
class AuthProvider extends ChangeNotifier {
  /// Whether any user is currently logged in.
  bool _isAuthenticated = false;

  /// The username of the logged-in user, or null if not authenticated.
  String? _username;

  /// Whether the logged-in user has admin privileges.
  bool _isAdmin = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  bool get isAdmin => _isAdmin;

  /// Sets the user as authenticated. Called after successful login.
  /// [isAdmin] controls access to admin-only features (user management, etc.).
  void login(String username, {bool isAdmin = false}) {
    _isAuthenticated = true;
    _username = username;
    _isAdmin = isAdmin;
    notifyListeners();
  }

  /// Clears authentication state. Navigating away from admin is handled by the UI.
  void logout() {
    _isAuthenticated = false;
    _username = null;
    _isAdmin = false;
    notifyListeners();
  }
}
