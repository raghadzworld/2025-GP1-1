import 'package:flutter/material.dart';
import 'screens/main_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/add_edit_category_screen.dart';
import 'screens/stt_tts_screen.dart';

void main() {
  runApp(const NabeehApp());
}

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const home = '/home';
  static const main = '/main';
  
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
          return MaterialPageRoute(
            builder: (context) => AddEditCategoryScreen(category: args),
          );
        }
        
        // باقي المسارات
        switch (settings.name) {
          case AppRoutes.splash:
            return MaterialPageRoute(builder: (_) => const SplashScreen());
          case AppRoutes.login:
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          case AppRoutes.main:
            return MaterialPageRoute(builder: (_) => const MainScreen());
          case AppRoutes.categories:
            return MaterialPageRoute(builder: (_) => const CategoriesScreen());
          case AppRoutes.sttTts:
            return MaterialPageRoute(builder: (_) => const SttTtsScreen());
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) Navigator.pushReplacementNamed(context, AppRoutes.login);
    });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

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
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: const Icon(Icons.hearing_rounded, size: 52, color: Color(0xFF21277B)),
                  ),
                  const SizedBox(height: 24),
                  const Text('نبيه', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('مساعدك الذكي للتواصل', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15)),
                  const SizedBox(height: 48),
                  const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Login Screen ──────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true, _loading = false;

  void _login() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pushReplacementNamed(context, AppRoutes.main);
    }
  }

  @override
  void dispose() { _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 48),
                Center(
                  child: Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(color: const Color(0xFF21277B), borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.hearing_rounded, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(child: Text('مرحباً بك في نبيه', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF21277B)))),
                const Center(child: Text('سجّل دخولك للمتابعة', style: TextStyle(fontSize: 14, color: Color(0xFFA4ACB0)))),
                const SizedBox(height: 40),
                const Text('البريد الإلكتروني', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF21277B))),
                const SizedBox(height: 8),
                TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(hintText: 'example@nabeeh.com', prefixIcon: Icon(Icons.email_outlined))),
                const SizedBox(height: 20),
                const Text('كلمة المرور', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF21277B))),
                const SizedBox(height: 8),
                TextField(
                  controller: _passCtrl, obscureText: _obscure, textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: () {}, child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: Color(0xFF1773CF)))),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _login,
                  child: _loading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('تسجيل الدخول'),
                ),
                const SizedBox(height: 16),
                Row(children: [
                  const Expanded(child: Divider()),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('أو', style: TextStyle(color: Color(0xFFA4ACB0)))),
                  const Expanded(child: Divider()),
                ]),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Color(0xFF1773CF)),
                  ),
                  child: const Text('إنشاء حساب جديد', style: TextStyle(color: Color(0xFF1773CF), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
