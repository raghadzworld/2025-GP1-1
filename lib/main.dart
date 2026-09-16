import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/main_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/add_edit_category_screen.dart';
import 'features/categories/data/services/category_service.dart';
import 'features/categories/data/models/category_model.dart';
import 'screens/stt_tts_screen.dart';
import 'screens/intro_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'services/listening_background_service.dart';
import 'services/reminder_alarm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const NabeehApp());
  // نهيّئ خدمة الاستماع الخلفية بعد أول رسمة للواجهة، مو قبلها — لو تعلّقت
  // هذي الخطوة لأي سبب (مثلاً حالة خدمة تالفة بعد تعطّل سابق بنظام أندرويد)،
  // ما نبي المستخدم يعلق على شاشة بيضاء بدون أي واجهة للأبد بانتظارها.
  unawaited(
    initializeBackgroundService().timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint(
        'initializeBackgroundService: timed out — continuing without it',
      ),
    ),
  );
  // نفس فكرة الخدمة الخلفية أعلاه: ما نوقف أول رسمة للواجهة بانتظار هذي —
  // لو المستخدمة رفضت صلاحية "الإنذار الدقيق" أو تعلّقت لأي سبب، التطبيق
  // يفتح عادي وتضل التذكيرات (وأي جدولة سابقة محفوظة) تشتغل بمجرد ما
  // تنضبط الصلاحية لاحقًا.
  unawaited(
    ReminderAlarmService.initialize().timeout(
      const Duration(seconds: 10),
      onTimeout: () => debugPrint(
        'ReminderAlarmService.initialize: timed out — continuing without it',
      ),
    ),
  );
}

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const main = '/main';
  static const intro = '/intro';
  static const welcome = '/welcome';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  // مسارات شاشاتكِ الجديدة
  static const categories = '/categories';
  static const addCategory = '/add-category';
  static const sttTts = '/stt-tts';
}

class NabeehApp extends StatelessWidget {
  const NabeehApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nabeeh - نبيه',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: (settings) {
        // مسار إضافة/تعديل الفئة (يحتاج arguments)
        if (settings.name == AppRoutes.addCategory) {
          final args = settings.arguments as Map<String, dynamic>?;
          final category = args?['category'] as CategoryModel?;
          final service = args?['service'] as CategoryService?;
          return MaterialPageRoute(
            builder: (context) =>
                AddEditCategoryScreen(category: category, service: service),
          );
        }

        // باقي المسارات
        switch (settings.name) {
          case AppRoutes.splash:
            return MaterialPageRoute(builder: (_) => const AppRoot());
          case AppRoutes.intro:
            return MaterialPageRoute(builder: (_) => const IntroScreen());
          case AppRoutes.welcome:
            return MaterialPageRoute(builder: (_) => const WelcomeScreen());
          case AppRoutes.signup:
            return MaterialPageRoute(builder: (_) => const SignupScreen());
          case AppRoutes.login:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case AppRoutes.main:
            return MaterialPageRoute(
              settings: settings,
              builder: (_) => const MainScreen(),
            );
          case AppRoutes.categories:
            return MaterialPageRoute(builder: (_) => const CategoriesScreen());
          case AppRoutes.sttTts:
            return MaterialPageRoute(builder: (_) => const SttTtsScreen());
          case AppRoutes.forgotPassword:
            return MaterialPageRoute(
              builder: (_) => const ForgotPasswordScreen(),
            );
          default:
            return MaterialPageRoute(builder: (_) => const AppRoot());
        }
      },
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'IBMPlexSansArabic',
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1773CF),
        secondary: Color(0xFF21277B),
        surface: Color(0xFFFFFFFF),
        error: Color(0xFFFF3B30),
      ),
      scaffoldBackgroundColor: Colors.white,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1773CF),
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1773CF), width: 2),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
    );
  }
}

// ── جذر التطبيق: يقرر بصمت إذا نروح لـ MainScreen أو IntroScreen ───────────────
// بدون أي شاشة سبلاش تظهر للمستخدمة أول ما تفتح التطبيق.
class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  Future<bool> _isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    final user = FirebaseAuth.instance.currentUser;
    return rememberMe && user != null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isLoggedIn(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(backgroundColor: Color(0xFF1a1760));
        }
        return snapshot.data! ? const MainScreen() : const IntroScreen();
      },
    );
  }
}
