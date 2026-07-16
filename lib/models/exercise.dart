/// Modelo de ejercicio - solo español.
class Exercise {
  final String id;
  final String name;
  final String category;
  final String bodyPart;
  final String equipment;
  final String instructionsEs;
  final String muscleGroup;
  final List<String> secondaryMuscles;
  final String target;
  final String? mediaId;
  final String? image;
  final String? gifUrl;
  final String attribution;
  final String? createdAt;

  const Exercise({
    required this.id,
    required this.name,
    required this.category,
    required this.bodyPart,
    required this.equipment,
    required this.instructionsEs,
    required this.muscleGroup,
    required this.secondaryMuscles,
    required this.target,
    this.mediaId,
    this.image,
    this.gifUrl,
    required this.attribution,
    this.createdAt,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    // Instrucciones en español: prioridad instructions.es, luego instructions_es (Supabase)
    String instr = '';
    final instructionsRaw = json['instructions'];
    if (instructionsRaw is Map) {
      instr = (instructionsRaw['es'] ?? instructionsRaw['en'] ?? '').toString();
    } else if (json['instructions_es'] is String) {
      instr = json['instructions_es'];
    }

    final secondaryRaw = json['secondary_muscles'];
    final List<String> secondary;
    if (secondaryRaw is List) {
      secondary = secondaryRaw.map((e) => e.toString()).toList();
    } else {
      secondary = [];
    }

    return Exercise(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      bodyPart: json['body_part']?.toString() ?? '',
      equipment: json['equipment']?.toString() ?? '',
      instructionsEs: instr,
      muscleGroup: json['muscle_group']?.toString() ?? '',
      secondaryMuscles: secondary,
      target: json['target']?.toString() ?? '',
      mediaId: json['media_id']?.toString(),
      image: json['image']?.toString(),
      gifUrl: json['gif_url']?.toString(),
      attribution: json['attribution']?.toString() ?? '',
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'body_part': bodyPart,
        'equipment': equipment,
        'instructions_es': instructionsEs,
        'muscle_group': muscleGroup,
        'secondary_muscles': secondaryMuscles,
        'target': target,
        'media_id': mediaId,
        'image': image,
        'gif_url': gifUrl,
        'attribution': attribution,
        'created_at': createdAt,
      };

  static const String mediaBaseUrl =
      'https://raw.githubusercontent.com/hasaneyldrm/exercises-dataset/main';

  String? get imageUrl {
    if (image == null || image!.isEmpty) return null;
    return '$mediaBaseUrl/$image';
  }

  String? get gifUrlFull {
    if (gifUrl == null || gifUrl!.isEmpty) return null;
    return '$mediaBaseUrl/$gifUrl';
  }

  String get secondaryMusclesFormatted {
    if (secondaryMuscles.isEmpty) return 'Ninguno';
    return secondaryMuscles
        .map((m) => m.isEmpty ? m : m[0].toUpperCase() + m.substring(1))
        .join(', ');
  }

  @override
  String toString() => 'Exercise(id: $id, name: $name)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Exercise && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
