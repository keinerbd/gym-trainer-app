import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/exercise.dart';

/// Service that loads and manages the exercise dataset.
class ExerciseService {
  static final ExerciseService _instance = ExerciseService._();
  factory ExerciseService() => _instance;
  ExerciseService._();

  List<Exercise>? _exercises;
  bool _isLoaded = false;

  /// Whether the dataset has been loaded.
  bool get isLoaded => _isLoaded;

  /// All exercises.
  List<Exercise> get exercises {
    if (_exercises == null) return [];
    return List.unmodifiable(_exercises!);
  }

  /// Load the dataset from the bundled JSON asset.
  Future<void> load() async {
    if (_isLoaded) return;

    final jsonString =
        await rootBundle.loadString('assets/data/exercises.json');
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    _exercises = jsonList
        .map((e) => Exercise.fromJson(e as Map<String, dynamic>))
        .toList();

    _isLoaded = true;
  }

  /// Get all unique categories, sorted alphabetically.
  List<String> get categories {
    final cats = exercises.map((e) => e.category).toSet().toList();
    cats.sort();
    return cats;
  }

  /// Get all unique body parts, sorted alphabetically.
  List<String> get bodyParts {
    final parts = exercises.map((e) => e.bodyPart).toSet().toList();
    parts.sort();
    return parts;
  }

  /// Get all unique equipment types, sorted alphabetically.
  List<String> get equipmentList {
    final eq = exercises.map((e) => e.equipment).toSet().toList();
    eq.sort();
    return eq;
  }

  /// Get all unique target muscles, sorted alphabetically.
  List<String> get targetMuscles {
    final targets = exercises.map((e) => e.target).toSet().toList();
    targets.sort();
    return targets;
  }

  /// Search exercises by name, category, equipment, or target.
  List<Exercise> search(String query) {
    if (query.isEmpty) return exercises;
    final q = query.toLowerCase();
    return exercises.where((e) {
      return e.name.toLowerCase().contains(q) ||
          e.category.toLowerCase().contains(q) ||
          e.equipment.toLowerCase().contains(q) ||
          e.target.toLowerCase().contains(q) ||
          e.muscleGroup.toLowerCase().contains(q);
    }).toList();
  }

  /// Filter exercises by category, body part, equipment, and/or target.
  List<Exercise> filter({
    String? category,
    String? bodyPart,
    String? equipment,
    String? target,
  }) {
    var result = exercises;

    if (category != null && category.isNotEmpty) {
      result = result.where((e) => e.category == category).toList();
    }
    if (bodyPart != null && bodyPart.isNotEmpty) {
      result = result.where((e) => e.bodyPart == bodyPart).toList();
    }
    if (equipment != null && equipment.isNotEmpty) {
      result = result.where((e) => e.equipment == equipment).toList();
    }
    if (target != null && target.isNotEmpty) {
      result = result.where((e) => e.target == target).toList();
    }

    return result;
  }

  /// Get exercise count by category.
  Map<String, int> get categoryCounts {
    final counts = <String, int>{};
    for (final e in exercises) {
      counts[e.category] = (counts[e.category] ?? 0) + 1;
    }
    return counts;
  }

  /// Get exercise count by equipment.
  Map<String, int> get equipmentCounts {
    final counts = <String, int>{};
    for (final e in exercises) {
      counts[e.equipment] = (counts[e.equipment] ?? 0) + 1;
    }
    return counts;
  }

  /// Get exercises by IDs (for favorites).
  List<Exercise> getByIds(List<String> ids) {
    return exercises.where((e) => ids.contains(e.id)).toList();
  }

  /// Get a single exercise by ID.
  Exercise? getById(String id) {
    try {
      return exercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
