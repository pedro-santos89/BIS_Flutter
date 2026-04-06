import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'theme.dart';
import 'providers.dart';
import 'l10n.dart';
import 'screens/home_screen.dart';
import 'screens/register_screen.dart';
import 'screens/login_screen.dart';
import 'screens/admin_screen.dart';
import 'screens/member_list_screen.dart';
import 'screens/daily_member_list_screen.dart';
import 'screens/report_screen.dart';
import 'screens/custom_table_list_screen.dart';
import 'screens/custom_table_design_screen.dart';
import 'screens/custom_table_data_screen.dart';
import 'screens/user_management_screen.dart';

/// Entry point for the BIS (BUS Information System) Flutter app.
/// Initializes sqflite FFI for desktop platforms (Windows, Linux, macOS),
/// sets up Provider-based state management, and launches the app.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Desktop platforms require FFI-based sqflite instead of the mobile plugin.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  runApp(
    // MultiProvider makes ThemeProvider and AuthProvider available
    // to all widgets in the tree via context.watch/context.read.
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const BisApp(),
    ),
  );
}

/// Root widget of the application.
/// Configures theming, localization, text scaling, and all named routes.
class BisApp extends StatelessWidget {
  const BisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'BIS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      locale: themeProvider.locale,
      supportedLocales: const [
        Locale('en'),
        Locale('pt'),
      ],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // The builder wraps the entire app with a MediaQuery override
      // to apply the user's chosen text scale factor globally.
      builder: (context, child) {
        final scale = themeProvider.textScale;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
          ),
          child: child!,
        );
      },
      // ─── Route definitions ───
      // Public routes: /, /register, /register-daily, /login, success pages.
      // Admin routes: /admin/*, all require authentication.
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/register': (context) => const RegisterScreen(),
        '/register-daily': (context) => const RegisterDailyScreen(),
        '/registration-success': (context) => const RegistrationSuccessScreen(),
        '/daily-registration-success': (context) => const DailyRegistrationSuccessScreen(),
        '/login': (context) => const LoginScreen(),
        '/admin': (context) => const AdminScreen(),
        '/admin/members': (context) => const MemberListScreen(),
        '/admin/members/add': (context) => const MemberEditScreen(),
        '/admin/members/edit': (context) => const MemberEditScreen(),
        '/admin/daily-members': (context) => const DailyMemberListScreen(),
        '/admin/daily-members/add': (context) => const DailyMemberEditScreen(),
        '/admin/daily-members/edit': (context) => const DailyMemberEditScreen(),
        '/admin/report': (context) => const ReportScreen(),
        '/admin/custom-tables': (context) => const CustomTableListScreen(),
        '/admin/custom-tables/design': (context) => const CustomTableDesignScreen(),
        '/admin/custom-tables/data': (context) => const CustomTableDataScreen(),
        '/admin/users': (context) => const UserManagementScreen(),
      },
    );
  }
}
