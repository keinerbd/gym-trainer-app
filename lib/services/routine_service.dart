import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weekly_routine.dart';
import '../models/user_profile.dart';

/// Gestiona el almacenamiento de rutinas, perfil y API key.
/// Las claves son por usuario cuando hay sesión activa.
class RoutineService {
  static final RoutineService _instance = RoutineService._();
  factory RoutineService() => _instance;
  RoutineService._();

  static const _routineSuffix = '_routine';
  static const _profileSuffix = '_profile';
  static const _apiKeyKey = 'groq_api_key';

  WeeklyRoutine? _currentRoutine;
  UserProfile? _profile;
  String? _apiKey;
  String? _currentUserId;
  bool _loaded = false;

  WeeklyRoutine? get currentRoutine => _currentRoutine;
  UserProfile? get profile => _profile;
  String? get apiKey => _apiKey;
  bool get isLoaded => _loaded;
  bool get hasProfile => _profile != null;
  bool get hasRoutine => _currentRoutine != null;
  bool get hasApiKey => _apiKey != null && _apiKey!.isNotEmpty;

  /// Vincula las claves al usuario actual. Usar tras login/logout.
  void setCurrentUser(String? userId) {
    _currentUserId = userId;
    _loaded = false; // forzar recarga con nuevas claves
  }

  String get _routineKey => _currentUserId != null
      ? '${_currentUserId!}$_routineSuffix'
      : 'default$_routineSuffix';

  String get _profileKey => _currentUserId != null
      ? '${_currentUserId!}$_profileSuffix'
      : 'default$_profileSuffix';

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();

    final routineJson = prefs.getString(_routineKey);
    if (routineJson != null) {
      _currentRoutine = WeeklyRoutine.fromJson(jsonDecode(routineJson));
    }

    final profileJson = prefs.getString(_profileKey);
    if (profileJson != null) {
      _profile = UserProfile.fromJson(jsonDecode(profileJson));
    }

    _apiKey = prefs.getString(_apiKeyKey);
    _loaded = true;
  }

  Future<void> saveRoutine(WeeklyRoutine routine) async {
    _currentRoutine = routine;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_routineKey, jsonEncode(routine.toJson()));
  }

  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
  }

  Future<void> saveApiKey(String key) async {
    _apiKey = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiKeyKey, key);
  }

  Future<void> clearRoutine() async {
    _currentRoutine = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_routineKey);
  }

  /// Obtiene el nombre del día actual en español.
  String get todayLabel {
    final now = DateTime.now();
    const days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return days[now.weekday - 1];
  }

  /// Ejercicios para el día actual.
  List<RoutineExercise> get todayExercises {
    if (_currentRoutine == null) return [];
    final today = WeeklyRoutine.todayEs;
    return _currentRoutine!.days[today] ?? [];
  }

  /// Días restantes de la semana con ejercicios.
  List<String> get remainingWorkoutDays {
    if (_currentRoutine == null) return [];
    final now = DateTime.now();
    final todayIdx = now.weekday - 1; // 0=lunes
    final result = <String>[];
    for (int i = todayIdx; i < 7; i++) {
      final day = WeeklyRoutine.dayNames[i];
      final exercises = _currentRoutine!.days[day] ?? [];
      if (exercises.isNotEmpty) result.add(day);
    }
    return result;
  }
}
