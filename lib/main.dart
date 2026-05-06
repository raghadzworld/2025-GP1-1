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
import 'screens/welcome_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/login_screen.dart';
import 'screens/forgot_password_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const NabeehApp());
}

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const main = '/main';
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
            return MaterialPageRoute(builder: (_) => const SplashScreen());
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
            return MaterialPageRoute(builder: (_) => const SplashScreen());
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

// ── Splash Screen ─────────────────────────────────────────────────────────────
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade, _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 1200), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;
      final user = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      if (rememberMe && user != null) {
        Navigator.pushReplacementNamed(context, AppRoutes.main);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.welcome);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF21277B), Color(0xFF1773CF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.hearing_rounded,
                      size: 52,
                      color: Color(0xFF21277B),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'نبيه',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'مساعدك الذكي للتواصل',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
