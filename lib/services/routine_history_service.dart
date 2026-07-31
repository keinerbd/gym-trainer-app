import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Registra el historial de rutinas generadas por semana.
/// Permite saber para cada día si hubo rutina asignada.
class RoutineHistoryService {
  static final RoutineHistoryService _instance = RoutineHistoryService._();
  factory RoutineHistoryService() => _instance;
  RoutineHistoryService._();

  static const _key = 'routine_history';
  List<RoutineHistoryEntry> _entries = [];
  bool _loaded = false;

  List<RoutineHistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _entries = list.map((e) => RoutineHistoryEntry.fromJson(e)).toList();
      } catch (_) {
        _entries = [];
      }
    }
    _loaded = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(_entries.map((e) => e.toJson()).toList()),
    );
  }

  /// Registra que se generó una rutina para una semana concreta.
  /// `weekStart` = lunes de esa semana.
  /// `daysWithExercises` = lista de nombres de días que tienen ejercicios.
  Future<void> registerRoutine({
    required DateTime weekStart,
    required List<String> daysWithExercises,
  }) async {
    await load();
    // Eliminar entrada previa de esa misma semana si existe
    _entries.removeWhere((e) =>
        _sameWeek(e.weekStart, weekStart));
    _entries.add(RoutineHistoryEntry(
      weekStart: weekStart,
      generatedAt: DateTime.now(),
      daysWithExercises: daysWithExercises,
    ));
    await _save();
  }

  /// Devuelve la entrada de historial que cubre una fecha dada.
  RoutineHistoryEntry? getEntryForDate(DateTime date) {
    for (final entry in _entries) {
      final weekEnd = entry.weekStart.add(const Duration(days: 6));
      if (!date.isBefore(entry.weekStart) && !date.isAfter(weekEnd)) {
        return entry;
      }
    }
    return null;
  }

  /// ¿El día de la semana [dayIndex] (0=lunes) tuvo ejercicios asignados
  /// en la semana que cubre [date]?
  bool dayHadRoutine(DateTime date) {
    final entry = getEntryForDate(date);
    if (entry == null) return false;
    final dayIdx = date.weekday - 1;
    if (dayIdx < 0 || dayIdx >= 7) return false;
    final dayName = _dayNames[dayIdx];
    return entry.daysWithExercises.contains(dayName);
  }

  /// ¿Existe registro para la semana que contiene [date]?
  bool hasRecordForDate(DateTime date) => getEntryForDate(date) != null;

  bool _sameWeek(DateTime a, DateTime b) {
    // Dos fechas están en la misma semana si comparten el mismo lunes
    final mondayA = a.subtract(Duration(days: a.weekday - 1));
    final mondayB = b.subtract(Duration(days: b.weekday - 1));
    return mondayA.year == mondayB.year &&
        mondayA.month == mondayB.month &&
        mondayA.day == mondayB.day;
  }

  static const _dayNames = [
    'lunes', 'martes', 'miércoles', 'jueves',
    'viernes', 'sábado', 'domingo',
  ];
}

/// Un registro de rutina generada para una semana.
class RoutineHistoryEntry {
  final DateTime weekStart; // Lunes de la semana
  final DateTime generatedAt;
  final List<String> daysWithExercises; // 'lunes', 'martes', etc.

  RoutineHistoryEntry({
    required this.weekStart,
    required this.generatedAt,
    required this.daysWithExercises,
  });

  Map<String, dynamic> toJson() => {
        'weekStart': weekStart.toIso8601String(),
        'generatedAt': generatedAt.toIso8601String(),
        'daysWithExercises': daysWithExercises,
      };

  factory RoutineHistoryEntry.fromJson(Map<String, dynamic> json) =>
      RoutineHistoryEntry(
        weekStart: DateTime.parse(json['weekStart']),
        generatedAt: DateTime.parse(json['generatedAt']),
        daysWithExercises: (json['daysWithExercises'] as List)
            .map((e) => e.toString())
            .toList(),
      );
}
