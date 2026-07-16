/// Perfil del usuario para el entrenador personal.
class UserProfile {
  String gender; // 'male', 'female', 'other'
  int age;
  double weightKg;
  double heightCm;
  String fitnessLevel; // 'beginner', 'intermediate', 'advanced'
  String goal; // 'lose_weight', 'build_muscle', 'tone', 'strength', 'general'

  UserProfile({
    this.gender = 'male',
    this.age = 25,
    this.weightKg = 70,
    this.heightCm = 170,
    this.fitnessLevel = 'beginner',
    this.goal = 'general',
  });

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'age': age,
        'weightKg': weightKg,
        'heightCm': heightCm,
        'fitnessLevel': fitnessLevel,
        'goal': goal,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        gender: json['gender'] ?? 'male',
        age: json['age'] ?? 25,
        weightKg: (json['weightKg'] ?? 70).toDouble(),
        heightCm: (json['heightCm'] ?? 170).toDouble(),
        fitnessLevel: json['fitnessLevel'] ?? 'beginner',
        goal: json['goal'] ?? 'general',
      );

  String get goalLabel {
    switch (goal) {
      case 'lose_weight':
        return 'Perder peso';
      case 'build_muscle':
        return 'Ganar músculo';
      case 'tone':
        return 'Tonificar';
      case 'strength':
        return 'Fuerza';
      default:
        return 'General';
    }
  }

  String get levelLabel {
    switch (fitnessLevel) {
      case 'beginner':
        return 'Principiante';
      case 'intermediate':
        return 'Intermedio';
      case 'advanced':
        return 'Avanzado';
      default:
        return 'Principiante';
    }
  }

  String get genderLabel {
    switch (gender) {
      case 'male':
        return 'Hombre';
      case 'female':
        return 'Mujer';
      default:
        return 'Otro';
    }
  }
}
