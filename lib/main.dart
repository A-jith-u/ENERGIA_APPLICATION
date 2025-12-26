import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:energia/home_page.dart';
import 'package:energia/role_selection_page.dart';
import 'package:energia/student_login.dart';
import 'package:energia/dashboard_page.dart';
import 'package:energia/coordinator_login.dart';
import 'package:energia/coordinator_dashboard.dart';
import 'package:energia/registration_page.dart';
import 'package:energia/admin_login.dart';
import 'package:energia/admin_dashboard.dart';
import 'package:energia/onboarding_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Always show onboarding on every app launch
  runApp(const MyApp(onboardingComplete: false));
}

class MyApp extends StatelessWidget {
  final bool onboardingComplete;
  const MyApp({super.key, required this.onboardingComplete});

  @override
  Widget build(BuildContext context) {
    final baseColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF005BBB), // institutional blue
      brightness: Brightness.light,
    );

    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF005BBB),
      brightness: Brightness.dark,
    );

    // Safe theme configuration with fallback
    TextTheme? safeTextTheme;
    try {
      safeTextTheme = GoogleFonts.poppinsTextTheme();
    } catch (e) {
      // Use system font if Google Fonts fails
      safeTextTheme = null;
    }

    final lightTheme = ThemeData(
      colorScheme: baseColorScheme,
      useMaterial3: true,
      textTheme: safeTextTheme,
      fontFamily: safeTextTheme == null ? 'Roboto' : null,
      scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: baseColorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade700),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: baseColorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
        titleTextStyle: safeTextTheme != null 
          ? GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            )
          : const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              fontFamily: 'Roboto',
            ),
      ),
      cardTheme: CardThemeData(
        elevation: 6,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );

    final darkTheme = ThemeData(
      colorScheme: darkColorScheme.copyWith(
        surface: const Color(0xFF0F1824),
        surfaceContainerHighest: const Color(0xFF1E2A38),
        surfaceContainerLow: const Color(0xFF162230),
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF0C141D),
      textTheme: (safeTextTheme != null 
          ? GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)
          : ThemeData.dark().textTheme).apply(
        fontFamily: safeTextTheme == null ? 'Roboto' : null,
        bodyColor: Colors.grey.shade200,
        displayColor: Colors.grey.shade100,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF162230),
        elevation: 4,
        shadowColor: Colors.black54,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E2A38),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.blueGrey.shade600),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.blueGrey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: darkColorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.blueGrey.shade300),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkColorScheme.primary,
          foregroundColor: darkColorScheme.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF162230),
        foregroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF162230),
        indicatorColor: darkColorScheme.primary.withOpacity(.25),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade200),
        ),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Campus Portal',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system, // Or ThemeMode.light, ThemeMode.dark
      initialRoute: onboardingComplete ? '/home' : '/onboarding',
      routes: {
        '/onboarding': (context) => const OnboardingPage(),
        '/home': (context) => const HomePage(),
        '/': (context) => const HomePage(),
        '/role_selection': (context) => const RoleSelectionPage(),
        '/student_login': (context) => const StudentLoginPage(),
        '/coordinator_login': (context) => const CoordinatorLoginPage(),
        '/admin_login': (context) => const AdminLoginPage(),
        '/register': (context) => const RegistrationPage(),
        '/dashboard': (context) => const DashboardPage(),
        '/coordinator_dashboard': (context) => const CoordinatorDashboardPage(),
        '/admin_dashboard': (context) => const AdminDashboardPage(),
      },
    );
  }
}
