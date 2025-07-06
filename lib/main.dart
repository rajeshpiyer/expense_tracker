import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'services/currency_service.dart';
import 'services/expense_limit_service.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'services/json_import_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize auth service
  final authService = AuthService();
  await authService.initialize();

  // Auto-import initial data if user is logged in and is target user
  if (authService.isSignedIn && authService.currentUser?.email == 'prajeshiyer@gmail.com') {
    final jsonImportService = JsonImportService();
    try {
      bool imported = await jsonImportService.importInitialDataIfNeeded(
        authService.currentUser!.email,
      );
      if (imported) {
        print('Initial data imported successfully');
      }
    } catch (e) {
      print('Initial data import failed: $e');
    }
  }

  runApp(const FinanceFlowApp());
}

class FinanceFlowApp extends StatelessWidget {
  const FinanceFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => CurrencyService()),
        ChangeNotifierProvider(create: (context) => ExpenseLimitService()),
      ],
      child: MaterialApp(
      title: 'FinanceFlow',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700), // Professional yellow
          secondary: Color(0xFFFFD700),
          surface: Color(0xFF121212), // Almost black background
          onPrimary: Color(0xFF000000), // Black text on yellow
          onSecondary: Color(0xFF000000),
          onSurface: Color(0xFFFFFFFF), // White text
          error: Color(0xFFFF5252),
          onError: Color(0xFFFFFFFF),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Color(0xFFFFFFFF),
          titleTextStyle: TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 4,
          color: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1A1A1A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF444444)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF444444)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFFFD700), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFFFFFFFF)),
          hintStyle: const TextStyle(color: Color(0xFF888888)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700),
            foregroundColor: const Color(0xFF000000),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFFFFFFF)),
          bodyMedium: TextStyle(color: Color(0xFFFFFFFF)),
          bodySmall: TextStyle(color: Color(0xFFFFFFFF)),
          headlineLarge: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: Color(0xFFFFFFFF), fontWeight: FontWeight.w500),
          labelLarge: TextStyle(color: Color(0xFFFFFFFF)),
          labelMedium: TextStyle(color: Color(0xFFFFFFFF)),
          labelSmall: TextStyle(color: Color(0xFFFFFFFF)),
        ),
        iconTheme: const IconThemeData(
          color: Color(0xFFFFD700),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFFD700),
          foregroundColor: Color(0xFF000000),
        ),
      ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/main': (context) => const MainNavigation(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
