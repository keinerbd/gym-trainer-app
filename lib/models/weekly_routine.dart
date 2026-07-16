/// Una rutina semanal con ejercicios por día.
class WeeklyRoutine {
  final String id;
  final DateTime createdAt;
  final Map<String, List<RoutineExercise>> days; // 'monday', 'tuesday', etc.

  WeeklyRoutine({
    required this.id,
    required this.createdAt,
    required this.days,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toIso8601String(),
        'days': days.map((k, v) => MapEntry(k, v.map((e) => e.toJson()).toList())),
      };

  factory WeeklyRoutine.fromJson(Map<String, dynamic> json) {
    final daysRaw = json['days'] as Map<String, dynamic>;
    final days = <String, List<RoutineExercise>>{};
    daysRaw.forEach((k, v) {
      days[k] = (v as List).map((e) => RoutineExercise.fromJson(e)).toList();
    });
    return WeeklyRoutine(
      id: json['id'],
      createdAt: DateTime.parse(json['createdAt']),
      days: days,
    );
  }

  static const dayNames = [
    'lunes', 'martes', 'miércoles', 'jueves',
    'viernes', 'sábado', 'domingo',
  ];

  static const dayNamesEn = [
    'monday', 'tuesday', 'wednesday', 'thursday',
    'friday', 'saturday', 'sunday',
  ];

  /// Mapa de días: español -> inglés
  static const dayMap = {
    'lunes': 'monday', 'martes': 'tuesday', 'miércoles': 'wednesday',
    'jueves': 'thursday', 'viernes': 'friday', 'sábado': 'saturday',
    'domingo': 'sunday',
  };

  /// Calcula el día actual en español.
  static String get todayEs {
    final now = DateTime.now();
    final idx = now.weekday - 1; // 0 = lunes
    return dayNames[idx];
  }

  /// Ejercicios del día actual, o lista vacía si es día de descanso.
  List<RoutineExercise> get todayExercises {
    final today = todayEs;
    return days[today] ?? [];
  }

  /// Si el día de hoy es día de descanso (sin ejercicios asignados).
  bool get isRestDay => todayExercises.isEmpty;

  /// Devuelve una etiqueta del grupo muscular principal de un día
  /// basada en los ejercicios asignados. Ej: "Pierna", "Pecho", "Descanso".
  String dayLabel(String day) {
    final exs = days[day] ?? [];
    if (exs.isEmpty) return 'Descanso';

    // Buscar pistas en las notas (ej: "DÍA DE PIERNA")
    for (final ex in exs) {
      final n = (ex.notes ?? '').toLowerCase();
      if (n.contains('pierna')) return 'Pierna';
      if (n.contains('pecho') || n.contains('tríceps') || n.contains('push')) return 'Pecho/Tríceps';
      if (n.contains('espalda') || n.contains('bíceps') || n.contains('pull')) return 'Espalda/Bíceps';
      if (n.contains('hombro') || n.contains('deltoides')) return 'Hombro';
      if (n.contains('abdomen') || n.contains('core') || n.contains('abdominal')) return 'Abdomen/Core';
      if (n.contains('cardio')) return 'Cardio';
      if (n.contains('full body') || n.contains('cuerpo completo')) return 'Full Body';
      if (n.contains('brazo')) return 'Brazos';
      if (n.contains('glúteo') || n.contains('femoral')) return 'Pierna';
    }

    // Fallback: contar targets
    final targets = <String, int>{};
    for (final ex in exs) {
      // Nota: el target viene del ExerciseService
      targets[ex.name] = (targets[ex.name] ?? 0) + 1;
    }
    return '${exs.length} ejercicios';
  }

  /// Emoji/ícono para el grupo muscular del día.
  String dayEmoji(String day) {
    final label = dayLabel(day).toLowerCase();
    if (label.contains('pierna')) return '🦵';
    if (label.contains('pecho')) return '💪';
    if (label.contains('espalda')) return '🔙';
    if (label.contains('hombro')) return '🏋️';
    if (label.contains('abdomen') || label.contains('core')) return '🎯';
    if (label.contains('cardio')) return '🏃';
    if (label.contains('brazo')) return '💪';
    if (label.contains('full body')) return '🔥';
    return '📋';
  }
}

/// Un ejercicio dentro de una rutina.
class RoutineExercise {
  final String exerciseId;
  final String name;
  final int sets;
  final int reps;
  final int? durationSeconds;
  final String? notes;

  RoutineExercise({
    required this.exerciseId,
    required this.name,
    required this.sets,
    required this.reps,
    this.durationSeconds,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'exerciseId': exerciseId,
        'name': name,
        'sets': sets,
        'reps': reps,
        'durationSeconds': durationSeconds,
        'notes': notes,
      };

  factory RoutineExercise.fromJson(Map<String, dynamic> json) =>
      RoutineExercise(
        exerciseId: json['exerciseId'] ?? '',
        name: json['name'] ?? '',
        sets: json['sets'] ?? 3,
        reps: json['reps'] ?? 12,
        durationSeconds: json['durationSeconds'],
        notes: json['notes'],
      );
}
