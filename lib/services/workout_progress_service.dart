import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda qué ejercicios ha completado el usuario por día.
/// El progreso se persiste localmente y se reinicia cada día.
class WorkoutProgressService {
  static final WorkoutProgressService _instance = WorkoutProgressService._();
  factory WorkoutProgressService() => _instance;
  WorkoutProgressService._();

  static const _key = 'workout_progress';
  Map<String, Set<String>> _byDate = {};
  bool _loaded = false;

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Carga el progreso guardado (una sola vez).
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _byDate = decoded.map((k, v) =>
            MapEntry(k, (v as List).cast<String>().toSet()));
      } catch (_) {
        _byDate = {};
      }
    }
    _loaded = true;
  }

  /// ¿El ejercicio está completado hoy?
  bool isCompleted(DateTime date, String exerciseId) =>
      _byDate[_dateKey(date)]?.contains(exerciseId) ?? false;

  /// Cuántos ejercicios de la lista están completados en esa fecha.
  int completedCount(DateTime date, List<String> ids) {
    final done = _byDate[_dateKey(date)] ?? {};
    return ids.where(done.contains).length;
  }

  /// Alterna el estado completado/no completado de un ejercicio.
  Future<void> toggle(DateTime date, String exerciseId) async {
    final key = _dateKey(date);
    _byDate.putIfAbsent(key, () => {});
    if (!_byDate[key]!.remove(exerciseId)) {
      _byDate[key]!.add(exerciseId);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_byDate.map((k, v) => MapEntry(k, v.toList()))));
  }

  /// Limpia el progreso de una fecha concreta (para pruebas o reinicio).
  Future<void> clearDay(DateTime date) async {
    _byDate.remove(_dateKey(date));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(_byDate.map((k, v) => MapEntry(k, v.toList()))));
  }
}
