import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../models/user_profile.dart';
import '../models/weekly_routine.dart';

/// Servicio central de Supabase: Auth, DB, y RAG.
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  bool _initialized = false;

  /// Inicializa Supabase. Debe llamarse antes de usar cualquier método.
  Future<void> initialize() async {
    if (_initialized) return;

    final url = AppConfig.supabaseUrl.trim();
    final anonKey = AppConfig.supabaseAnonKey.trim();

    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception(
        'Configura Supabase en lib/config.dart:\n'
        '  supabaseUrl y supabaseAnonKey',
      );
    }

    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
    _initialized = true;
  }

  bool get isInitialized => _initialized;

  // ══════════════════════════════════════════════════
  // ── AUTH ─────────────────────────────────────────
  // ══════════════════════════════════════════════════

  User? get currentUser => client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  String? get userId => currentUser?.id;

  Future<void> signUp(String email, String password) async {
    await client.auth.signUp(email: email, password: password);
  }

  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  /// Envía un email de recuperación de contraseña.
  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email);
  }

  /// Actualiza la contraseña del usuario (usar tras el flujo de recuperación).
  Future<void> updatePassword(String newPassword) async {
    await client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Stream<AuthState> get authStateChanges => client.auth.onAuthStateChange;

  // ══════════════════════════════════════════════════
  // ── PERFIL ───────────────────────────────────────
  // ══════════════════════════════════════════════════

  Future<UserProfile?> getProfile() async {
    final uid = userId;
    if (uid == null) return null;

    final data = await client
        .from('profiles')
        .select()
        .eq('id', uid)
        .maybeSingle();

    if (data == null) return null;
    return UserProfile(
      gender: data['gender'] ?? 'male',
      age: data['age'] ?? 25,
      weightKg: (data['weight_kg'] ?? 70).toDouble(),
      heightCm: (data['height_cm'] ?? 170).toDouble(),
      fitnessLevel: data['fitness_level'] ?? 'beginner',
      goal: data['goal'] ?? 'general',
    );
  }

  Future<void> saveProfile(UserProfile profile) async {
    final uid = userId;
    if (uid == null) throw Exception('No autenticado.');

    await client.from('profiles').upsert({
      'id': uid,
      'gender': profile.gender,
      'age': profile.age,
      'weight_kg': profile.weightKg,
      'height_cm': profile.heightCm,
      'fitness_level': profile.fitnessLevel,
      'goal': profile.goal,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  // ══════════════════════════════════════════════════
  // ── RUTINAS ──────────────────────────────────────
  // ══════════════════════════════════════════════════

  Future<WeeklyRoutine?> getCurrentRoutine() async {
    final uid = userId;
    if (uid == null) return null;

    final data = await client
        .from('routines')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (data == null) return null;

    final daysRaw = data['days'] as Map<String, dynamic>;
    final days = <String, List<RoutineExercise>>{};
    for (final day in WeeklyRoutine.dayNames) {
      final list = daysRaw[day] as List? ?? [];
      days[day] = list.map((e) => RoutineExercise.fromJson(e)).toList();
    }

    return WeeklyRoutine(
      id: data['id'],
      createdAt: DateTime.parse(data['created_at']),
      days: days,
    );
  }

  Future<void> saveRoutine(WeeklyRoutine routine) async {
    final uid = userId;
    if (uid == null) throw Exception('No autenticado.');

    // Eliminar rutinas antiguas (solo mantener la actual)
    await client.from('routines').delete().eq('user_id', uid);

    // Insertar nueva
    final daysJson = <String, dynamic>{};
    routine.days.forEach((k, v) {
      daysJson[k] = v.map((e) => e.toJson()).toList();
    });

    await client.from('routines').insert({
      'user_id': uid,
      'days': daysJson,
      'created_at': routine.createdAt.toIso8601String(),
    });
  }

  // ══════════════════════════════════════════════════
  // ── FAVORITOS ────────────────────────────────────
  // ══════════════════════════════════════════════════

  Future<List<String>> getFavorites() async {
    final uid = userId;
    if (uid == null) return [];

    final data = await client
        .from('favorites')
        .select('exercise_id')
        .eq('user_id', uid);

    return data.map<String>((r) => r['exercise_id'] as String).toList();
  }

  Future<void> toggleFavorite(String exerciseId, bool isFavorite) async {
    final uid = userId;
    if (uid == null) throw Exception('No autenticado.');

    if (isFavorite) {
      await client.from('favorites').delete().eq('user_id', uid).eq('exercise_id', exerciseId);
    } else {
      await client.from('favorites').insert({
        'user_id': uid,
        'exercise_id': exerciseId,
      });
    }
  }

  // ══════════════════════════════════════════════════
  // ── RAG: Búsqueda inteligente de ejercicios ──────
  // ══════════════════════════════════════════════════

/// 🧠 RAG Vectorial: Busca ejercicios semánticamente relevantes usando
  /// embeddings + pgvector. Si no hay embeddings, cae en búsqueda por categoría.
  ///
  /// El query embedding se genera mediante Supabase Edge Function
  /// o mediante la API de Groq (modo texto como fallback).
  Future<List<Map<String, String>>> ragSearchExercises({
    required UserProfile profile,
    int limit = 50,
  }) async {
    // Construir query textual basado en el perfil
    final queryText = _buildRagQuery(profile);
    final targetCategories = _goalToCategories(profile.goal);
    final preferredEquipment = _goalToEquipment(profile.goal, profile.fitnessLevel);

    // ── Intentar búsqueda vectorial primero ─────
    try {
      final embedding = await _getQueryEmbedding(queryText);
      if (embedding != null) {
        final data = await client.rpc('search_exercises', params: {
          'query_embedding': embedding,
          'match_limit': limit,
          'p_category': preferredEquipment.isNotEmpty ? null : targetCategories.firstOrNull,
          'p_equipment': preferredEquipment.isNotEmpty ? preferredEquipment : null,
        });

        if (data.isNotEmpty) {
          return data.map<Map<String, String>>((row) => {
            'id': row['id']?.toString() ?? '',
            'name': row['name']?.toString() ?? '',
            'category': row['category']?.toString() ?? '',
            'equipment': row['equipment']?.toString() ?? '',
            'target': row['target']?.toString() ?? '',
            'similarity': row['similarity']?.toString() ?? '0',
          }).toList();
        }
      }
    } catch (_) {
      // Vectorial no disponible → fallback a categorías
    }

    // ── Fallback: búsqueda por categoría ─────────
    final results = <Map<String, String>>[];
    final seen = <String>{};

    for (final cat in targetCategories) {
      final data = await client
          .from('exercises')
          .select('id, name, category, equipment, target')
          .eq('category', cat)
          .limit((limit / targetCategories.length).ceil());

      for (final row in data) {
        final id = row['id']?.toString() ?? '';
        if (seen.add(id)) {
          results.add({
            'id': id,
            'name': row['name']?.toString() ?? '',
            'category': row['category']?.toString() ?? '',
            'equipment': row['equipment']?.toString() ?? '',
            'target': row['target']?.toString() ?? '',
          });
        }
      }
    }

    return results;
  }

  /// Construye un texto de búsqueda en español basado en el perfil.
  String _buildRagQuery(UserProfile profile) {
    return 'ejercicios para ${profile.goalLabel.toLowerCase()} '
        'nivel ${profile.levelLabel.toLowerCase()} '
        '${profile.genderLabel.toLowerCase()} '
        '${profile.age} años '
        '${profile.weightKg.toInt()} kg';
  }

  /// Obtiene el embedding de un texto usando Groq API (o servicio externo).
  /// Retorna null si no está disponible (fallback a categorías).
  Future<List<double>?> _getQueryEmbedding(String text) async {
    try {
      // Usar la misma API de Groq pero con un modelo que soporte embeddings
      // Groq actualmente no tiene endpoint de embeddings, así que usamos
      // Supabase Edge Function o un servicio externo.
      // Por ahora retornamos null → usa fallback por categorías.
      // Cuando implementes la Edge Function, reemplaza esto.
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Mapea el objetivo del usuario a categorías de ejercicios relevantes.
  List<String> _goalToCategories(String goal) {
    switch (goal) {
      case 'lose_weight':
        return ['cardio', 'waist', 'upper legs', 'lower legs'];
      case 'build_muscle':
        return ['chest', 'back', 'shoulders', 'upper arms', 'upper legs'];
      case 'tone':
        return ['waist', 'upper legs', 'lower legs', 'upper arms', 'back'];
      case 'strength':
        return ['chest', 'back', 'upper legs', 'shoulders', 'upper arms'];
      default:
        return ['chest', 'back', 'waist', 'upper arms', 'upper legs', 'shoulders'];
    }
  }

  /// Equipo preferido según objetivo y nivel.
  String _goalToEquipment(String goal, String level) {
    if (level == 'beginner') return 'body weight';
    if (goal == 'strength') return 'barbell';
    return ''; // Sin preferencia - usa todos
  }

  // ══════════════════════════════════════════════════
  // ── SEED: Subir ejercicios a Supabase ────────────
  // ══════════════════════════════════════════════════

  /// Sube los ejercicios del JSON local a Supabase (solo una vez).
  Future<void> seedExercises(List<Map<String, dynamic>> exercises) async {
    // Verificar si ya hay ejercicios (ignorar error si es primera vez)
    try {
      final existing = await client.from('exercises').select('id').limit(1);
      if (existing.isNotEmpty) return;
    } catch (_) {
      // Tabla no existe aún, continuar
    }

    // Insertar en lotes de 100
    for (var i = 0; i < exercises.length; i += 100) {
      final batch = exercises.skip(i).take(100).map((e) => {
            'id': e['id']?.toString(),
            'name': e['name']?.toString(),
            'category': e['category']?.toString(),
            'body_part': e['body_part']?.toString(),
            'equipment': e['equipment']?.toString(),
            'instructions_es': _extractSpanishInstructions(e),
            'muscle_group': e['muscle_group']?.toString(),
            'secondary_muscles': e['secondary_muscles'],
            'target': e['target']?.toString(),
            'image': e['image']?.toString(),
            'gif_url': e['gif_url']?.toString(),
            'media_id': e['media_id']?.toString(),
            'attribution': e['attribution']?.toString(),
            'created_at': e['created_at']?.toString(),
          }).toList();

      await client.from('exercises').insert(batch);
    }
  }

  /// Extrae solo las instrucciones en español del JSON.
  String _extractSpanishInstructions(Map<String, dynamic> e) {
    final instr = e['instructions'];
    if (instr is Map) {
      return (instr['es'] ?? instr['en'] ?? '').toString();
    }
    if (instr is List && instr.isNotEmpty) {
      return instr.join(' ');
    }
    return '';
  }
}
