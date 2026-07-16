import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'config.dart';
import 'services/exercise_service.dart';
import 'services/supabase_service.dart';
import 'services/groq_service.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
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

class GymApp extends StatelessWidget {
  final bool supabaseReady;
  const GymApp({super.key, required this.supabaseReady});

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
    if (!supabaseReady) return const HomeScreen();
    final supabase = SupabaseService();
    return supabase.isLoggedIn ? const HomeScreen() : const AuthScreen();
  }
}
