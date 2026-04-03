import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'theme.dart';
import 'providers.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const BisApp(),
    ),
  );
}

class BisApp extends StatelessWidget {
  const BisApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'BIS - BUS Information System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
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
