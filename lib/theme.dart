import 'package:flutter/material.dart';

class AppTheme {
  // ─── Font families (matching Django BIS webapp) ───
  static const String headlineFont = 'Rowsky';  // Custom font for "Welcome to bis"
  // Oswald via google_fonts for body/subheadline/buttons

  // ─── Purple accent colors (matching Django BIS theme) ───
  static const Color primaryPurple = Color(0xFFBB86FC);
  static const Color darkPurple = Color(0xFF8D33FA);
  static const Color gold = Color(0xFFFFD700);
  static const Color darkPurpleHover = Color(0xFF9966CC);

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryPurple,
    scaffoldBackgroundColor: Colors.black,
    colorScheme: const ColorScheme.dark(
      primary: primaryPurple,
      secondary: darkPurple,
      surface: Color(0xFF1a1a1a),
      error: Color(0xFFdc3545),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1a1a1a),
      foregroundColor: primaryPurple,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: Color(0xFF1a1a1a),
      elevation: 2,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return gold;
          return primaryPurple;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return Colors.black;
          return Colors.black;
        }),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
        textStyle: WidgetStateProperty.all(const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        )),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        )),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return gold;
          return primaryPurple;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return const BorderSide(color: gold);
          return const BorderSide(color: primaryPurple);
        }),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        )),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return gold;
          return null;
        }),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return gold;
          return primaryPurple;
        }),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF2a2a2a),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryPurple),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: primaryPurple.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryPurple, width: 2),
      ),
      labelStyle: TextStyle(color: primaryPurple.withValues(alpha: 0.8)),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: primaryPurple, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: primaryPurple, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
      bodySmall: TextStyle(color: Colors.white54),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.resolveWith((_) => const Color(0xFF2a2a2a)),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryPurple.withValues(alpha: 0.2);
        }
        if (states.contains(WidgetState.hovered)) {
          return primaryPurple.withValues(alpha: 0.15);
        }
        return null;
      }),
      headingTextStyle: const TextStyle(
        color: primaryPurple,
        fontWeight: FontWeight.bold,
      ),
      dataTextStyle: const TextStyle(color: Colors.white70),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primaryPurple;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(Colors.black),
      side: const BorderSide(color: primaryPurple),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryPurple,
      foregroundColor: Colors.black,
      hoverColor: gold,
      hoverElevation: 12,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF2a2a2a),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: primaryPurple.withValues(alpha: 0.3),
    iconTheme: const IconThemeData(color: primaryPurple),
  );

  // ─── Light theme colors (matching Django BIS light theme) ───
  static const Color lightPrimary = Color(0xFFEB3502);      // deep orange-red
  static const Color lightPrimaryLighter = Color(0xFFFF6719); // lighter orange
  static const Color lightPrimaryDarker = Color(0xFF9C3100); // darker orange
  static const Color lightAccent = Color(0xFF00ADB5);        // teal
  static const Color lightBg = Color(0xFFEDEBDE);            // warm light gray bg
  static const Color lightBgLight = Color(0xFFFFFEF8);       // card/surface bg
  static const Color lightBodyText = Color(0xFF521C0D);      // body text

  /// Returns the hover color for interactive text elements based on theme.
  static Color hoverColor(bool isDark) => isDark ? gold : lightAccent;
  /// Returns the button hover bg based on theme.
  static Color buttonHoverBg(bool isDark) => isDark ? darkPurpleHover : lightPrimaryDarker;

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: lightPrimary,
    scaffoldBackgroundColor: lightBg,
    colorScheme: const ColorScheme.light(
      primary: lightPrimary,
      secondary: lightPrimaryLighter,
      surface: lightBgLight,
      error: Color(0xFFdc3545),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: lightBgLight,
      foregroundColor: lightPrimary,
      elevation: 1,
    ),
    cardTheme: CardThemeData(
      color: lightBgLight,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: lightPrimary, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return lightAccent;
          return lightPrimary;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return Colors.white;
          return lightBgLight;
        }),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
        textStyle: WidgetStateProperty.all(const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        )),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        )),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return lightAccent;
          return lightPrimary;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return const BorderSide(color: lightAccent);
          return const BorderSide(color: lightPrimary);
        }),
        padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        )),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return lightAccent;
          return null;
        }),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered)) return lightAccent;
          return lightPrimary;
        }),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightBgLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: lightPrimary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: lightPrimary.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: lightPrimary, width: 2),
      ),
      labelStyle: TextStyle(color: lightPrimaryDarker.withValues(alpha: 0.8)),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: lightPrimary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: lightPrimary, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: lightPrimary, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: lightBodyText),
      bodyMedium: TextStyle(color: lightBodyText),
      bodySmall: TextStyle(color: lightPrimaryDarker),
    ),
    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.resolveWith((_) => lightPrimary),
      dataRowColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return lightPrimary.withValues(alpha: 0.15);
        }
        if (states.contains(WidgetState.hovered)) {
          return lightPrimary.withValues(alpha: 0.1);
        }
        return null;
      }),
      headingTextStyle: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
      dataTextStyle: const TextStyle(color: lightBodyText),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return lightPrimary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(lightBgLight),
      side: const BorderSide(color: lightPrimary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: lightPrimary,
      foregroundColor: lightBgLight,
      hoverColor: lightAccent,
      hoverElevation: 12,
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
    dividerColor: lightPrimary.withValues(alpha: 0.2),
    iconTheme: const IconThemeData(color: lightPrimary),
  );
}
