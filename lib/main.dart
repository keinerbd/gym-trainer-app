import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'services/exercise_service.dart';
import 'services/supabase_service.dart';
import 'services/groq_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/reset_password_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final exerciseService = ExerciseService();
  await exerciseService.load();

  final supabase = SupabaseService();
  bool supabaseReady = false;

  if (AppConfig.supabaseUrl.isNotEmpty && AppConfig.supabaseAnonKey.isNotEmpty) {
    try {
      await supabase.initialize();
      supabaseReady = true;

      final jsonString =
          await rootBundle.loadString('assets/data/exercises.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      await supabase.seedExercises(jsonList.cast<Map<String, dynamic>>());
    } catch (e) {
      debugPrint('Supabase init: $e');
    }
  }

  final groqService = GroqService();
  if (AppConfig.groqApiKey.isNotEmpty) {
    groqService.setApiKey(AppConfig.groqApiKey);
  }

  runApp(GymApp(supabaseReady: supabaseReady));
}

class GymApp extends StatefulWidget {
  final bool supabaseReady;
  const GymApp({super.key, required this.supabaseReady});

  @override
  State<GymApp> createState() => _GymAppState();
}

class _GymAppState extends State<GymApp> {
  late final Stream<AuthState> _authStream;
  bool _isRecovery = false;

  @override
  void initState() {
    super.initState();
    // Detectar el flujo de recuperación de contraseña:
    // cuando el usuario llega desde el email de reset, Supabase emite
    // el evento `recovery` y mostramos la pantalla de nueva contraseña.
    if (widget.supabaseReady) {
      _authStream = SupabaseService().authStateChanges;
      _authStream.listen((data) {
        if (data.event == AuthChangeEvent.passwordRecovery) {
          if (mounted) setState(() => _isRecovery = true);
        } else if (data.event == AuthChangeEvent.signedOut) {
          if (mounted) setState(() => _isRecovery = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Trainer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.glassTheme,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (!widget.supabaseReady) return const HomeScreen();
    if (_isRecovery) return const ResetPasswordScreen();
    final supabase = SupabaseService();
    return supabase.isLoggedIn ? const HomeScreen() : const AuthScreen();
  }
}
