import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/user_profile.dart';
import '../models/weekly_routine.dart';
import '../models/chat_message.dart';

/// Servicio que se comunica con la API de Groq para generar rutinas con IA.
class GroqService {
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const _model = 'openai/gpt-oss-120b';

  String? _apiKey;

  void setApiKey(String key) => _apiKey = key;

  String? get apiKey {
    // Primero la key seteada en runtime, luego la del config
    if (_apiKey != null && _apiKey!.isNotEmpty) return _apiKey;
    final configKey = AppConfig.groqApiKey.trim();
    if (configKey.isNotEmpty) return configKey;
    return null;
  }

  bool get hasKey {
    final key = apiKey;
    return key != null && key.isNotEmpty;
  }

  /// Genera una rutina semanal usando RAG: recibe ejercicios ya filtrados
  /// por relevancia desde Supabase en lugar de una muestra aleatoria.
  Future<WeeklyRoutine> generateRoutine({
    required UserProfile profile,
    required List<Map<String, String>> ragExercises,
  }) async {
    if (!hasKey) throw Exception('API key de Groq no configurada.');

    // Usar ejercicios filtrados por RAG (ya relevantes al perfil)
    final exerciseList = ragExercises
        .map((e) =>
            '- ID:${e['id']} | ${e['name']} | categoría:${e['category']} | equipo:${e['equipment']} | músculo:${e['target']}')
        .join('\n');

    final prompt =
        '''Eres un entrenador personal profesional. Crea una rutina de ejercicios semanal en español para el siguiente perfil:

- Género: ${profile.genderLabel}
- Edad: ${profile.age} años
- Peso: ${profile.weightKg} kg
- Altura: ${profile.heightCm} cm
- Nivel: ${profile.levelLabel}
- Objetivo: ${profile.goalLabel}

Reglas:
- Asigna ejercicios SOLO para 4-5 días como máximo (los demás son descanso).
- **AGRUPACIÓN MUSCULAR**: Cada día debe enfocarse en UN grupo muscular principal. Distribuye así:
  - Día 1: Pierna (cuádriceps, femoral, glúteos, pantorrillas)
  - Día 2: Pecho y Tríceps (empuje / push)
  - Día 3: Espalda y Bíceps (jalón / pull)
  - Día 4: Hombro y Trapecio (deltoides)
  - Día 5 (opcional): Abdomen y Core, o Full Body
  - Ajusta según el objetivo: si es "Perder peso" incluye más cardio; si es "Fuerza" enfoca en ejercicios compuestos pesados.
- Cada día debe tener entre 5 y 8 ejercicios, TODOS del mismo grupo muscular asignado.
- Cada ejercicio debe tener series (sets), repeticiones (reps) y el exerciseId EXACTO de la lista.
- Usa SOLO exerciseId que aparezcan en la lista proporcionada.
- Incluye notas breves en español para cada ejercicio si es relevante.

Lista de ejercicios disponibles:
$exerciseList

Responde ÚNICAMENTE con un JSON válido, sin markdown ni texto adicional, con esta estructura exacta (cada día enfocado en un grupo muscular):
{
  "lunes": [
    {"exerciseId": "0001", "sets": 3, "reps": 12, "notes": "DÍA DE PIERNA - Controla el descenso"},
    {"exerciseId": "0002", "sets": 3, "reps": 10, "notes": "DÍA DE PIERNA - Sentadilla profunda"},
    {"exerciseId": "0003", "sets": 4, "reps": 12, "notes": "DÍA DE PIERNA - Extensión controlada"},
    {"exerciseId": "0004", "sets": 3, "reps": 15, "notes": "DÍA DE PIERNA - Elevación de talones"},
    {"exerciseId": "0005", "sets": 3, "reps": 12, "notes": "DÍA DE PIERNA - Peso muerto rumano"}
  ],
  "martes": [
    {"exerciseId": "0006", "sets": 4, "reps": 10, "notes": "DÍA DE PECHO Y TRÍCEPS - Empuje controlado"},
    {"exerciseId": "0007", "sets": 3, "reps": 12, "notes": "DÍA DE PECHO Y TRÍCEPS - Press inclinado"},
    {"exerciseId": "0008", "sets": 3, "reps": 12, "notes": "DÍA DE PECHO Y TRÍCEPS - Aperturas"},
    {"exerciseId": "0009", "sets": 3, "reps": 10, "notes": "DÍA DE PECHO Y TRÍCEPS - Fondo en paralelas"},
    {"exerciseId": "0010", "sets": 3, "reps": 15, "notes": "DÍA DE PECHO Y TRÍCEPS - Extensión de tríceps"}
  ],
  "miércoles": [],
  "jueves": [
    {"exerciseId": "0011", "sets": 3, "reps": 12, "notes": "DÍA DE ESPALDA Y BÍCEPS - Aprieta al subir"},
    {"exerciseId": "0012", "sets": 4, "reps": 10, "notes": "DÍA DE ESPALDA Y BÍCEPS - Remo con barra"},
    {"exerciseId": "0013", "sets": 3, "reps": 12, "notes": "DÍA DE ESPALDA Y BÍCEPS - Jalón al pecho"},
    {"exerciseId": "0014", "sets": 3, "reps": 12, "notes": "DÍA DE ESPALDA Y BÍCEPS - Curl de bíceps"},
    {"exerciseId": "0015", "sets": 3, "reps": 15, "notes": "DÍA DE ESPALDA Y BÍCEPS - Martillo"}
  ],
  "viernes": [
    {"exerciseId": "0016", "sets": 4, "reps": 10, "notes": "DÍA DE HOMBRO - No uses impulso"},
    {"exerciseId": "0017", "sets": 3, "reps": 12, "notes": "DÍA DE HOMBRO - Press militar"},
    {"exerciseId": "0018", "sets": 3, "reps": 12, "notes": "DÍA DE HOMBRO - Elevaciones laterales"},
    {"exerciseId": "0019", "sets": 3, "reps": 12, "notes": "DÍA DE HOMBRO - Pájaro"},
    {"exerciseId": "0020", "sets": 4, "reps": 10, "notes": "DÍA DE HOMBRO - Encogimientos"}
  ],
  "sábado": [],
  "domingo": []
}

IMPORTANTE: Usa días en español: "lunes", "martes", "miércoles", "jueves", "viernes", "sábado", "domingo". Los días sin ejercicio deben ser array vacío [].
Los exerciseId DEBEN ser IDs exactos de la lista de arriba. NO inventes IDs. Si no encuentras un ejercicio adecuado, deja ese día vacío. Responde SOLO con el JSON.''';

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content':
                'Eres un entrenador personal que responde solo con JSON válido.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.7,
        'max_tokens': 3000,
      }),
    );

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(
          'Error de Groq API: ${err['error']?['message'] ?? response.body}');
    }

    final data = jsonDecode(response.body);
    final content = data['choices'][0]['message']['content'] as String;

    // Limpiar posible markdown
    final clean =
        content.replaceAll('```json', '').replaceAll('```', '').trim();

    final daysJson = jsonDecode(clean) as Map<String, dynamic>;

    final days = <String, List<RoutineExercise>>{};
    for (final day in WeeklyRoutine.dayNames) {
      final list = (daysJson[day] as List?) ?? [];
      days[day] = list.map((e) {
        final ex = e as Map<String, dynamic>;
        // Buscar nombre del ejercicio en la lista
        final found = ragExercises.firstWhere(
          (ae) => ae['id'] == ex['exerciseId'],
          orElse: () => {'name': ex['exerciseId'] ?? 'Ejercicio'},
        );
        return RoutineExercise(
          exerciseId: ex['exerciseId']?.toString() ?? '',
          name: found['name'] ?? ex['exerciseId']?.toString() ?? 'Ejercicio',
          sets: ex['sets'] ?? 3,
          reps: ex['reps'] ?? 12,
          durationSeconds: ex['durationSeconds'],
          notes: ex['notes']?.toString(),
        );
      }).toList();
    }

    return WeeklyRoutine(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      createdAt: DateTime.now(),
      days: days,
    );
  }

  /// 🗨️ Chat con el entrenador IA: el usuario puede pedir sustituciones,
  /// consejos, o modificar ejercicios de un día específico.
  Future<String> chatAdvice({
    required UserProfile profile,
    required String dayName,
    required List<Map<String, String>> currentExercises,
    required List<Map<String, String>> availableExercises,
    required String userMessage,
  }) async {
    if (!hasKey) throw Exception('API key de Groq no configurada.');

    final currentList = currentExercises
        .map((e) =>
            '- ID:${e['id']} | ${e['name']} | categoría:${e['category']} | equipo:${e['equipment']} | músculo:${e['target']}')
        .join('\n');

    final availableList = availableExercises
        .where((e) => !currentExercises.any((ce) => ce['id'] == e['id']))
        .take(40)
        .map((e) =>
            '- ID:${e['id']} | ${e['name']} | categoría:${e['category']} | equipo:${e['equipment']} | músculo:${e['target']}')
        .join('\n');

    final prompt =
        '''Eres un entrenador personal profesional experto en fitness. El usuario tiene el siguiente perfil:
- ${profile.genderLabel}, ${profile.age} años, ${profile.weightKg.toInt()} kg, ${profile.heightCm.toInt()} cm
- Nivel: ${profile.levelLabel}
- Objetivo: ${profile.goalLabel}

El usuario está viendo su rutina del día "$dayName" con estos ejercicios:
$currentList

Ejercicios alternativos disponibles (fuera de su rutina actual):
$availableList

El usuario pregunta: "$userMessage"

INSTRUCCIONES:
- Responde en español, de forma breve y útil (máximo 3-4 frases).
- Si pide sustituir un ejercicio, sugiere UNO de la lista de ALTERNATIVOS y explica por qué.
- Si pide consejo, da tips prácticos y específicos.
- Sé motivador pero directo.
- NO uses markdown. Solo texto plano.''';

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {
            'role': 'system',
            'content':
                'Eres un entrenador personal que responde en español, breve y útil.'
          },
          {'role': 'user', 'content': prompt},
        ],
        'temperature': 0.7,
        'max_tokens': 400,
      }),
    );

    if (response.statusCode != 200) {
      final err = jsonDecode(response.body);
      throw Exception(
          'Error de Groq API: ${err['error']?['message'] ?? response.body}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'] as String;
  }

  /// 🗨️ Chat con el entrenador IA con MEMORIA de conversación y STREAMING.
  ///
  /// Envía todo el historial de la conversación para que la IA recuerde
  /// el contexto, y devuelve un stream de texto con las respuestas parciales
  /// para mostrar la respuesta mientras se genera.
  Stream<String> chatStream({
    required UserProfile profile,
    required String routineContext,
    required List<ChatMessage> history,
    required String userMessage,
  }) async* {
    if (!hasKey) throw Exception('API key de Groq no configurada.');

    final systemPrompt = '''
Eres un entrenador personal profesional experto en fitness y nutrición.
Responde SIEMPRE en español, de forma breve y útil (3-5 frases salvo que pidan más detalle).
NO uses markdown (ni **, ni #, ni listas con guiones). Usa texto plano, puedes usar emojis con moderación.
Sé motivador, directo y específico. Si el usuario pregunta algo fuera de fitness, redirige amablemente.

Perfil del usuario:
- ${profile.genderLabel}, ${profile.age} años, ${profile.weightKg.toInt()} kg, ${profile.heightCm.toInt()} cm
- Nivel: ${profile.levelLabel}
- Objetivo: ${profile.goalLabel}

Rutina semanal actual del usuario:
$routineContext

Contexto adicional:
- El usuario puede pedirte que sustituyas ejercicios, ajustes series/reps, o te explique la técnica.
- Si sugiere un ejercicio, explícalo brevemente y justifica por qué encaja con su objetivo.
- Ten en cuenta su nivel y objetivo en cada recomendación.
''';

    final chatHistory = history
        .where((m) => m.isUser || m.isAssistant)
        .toList();
    // Solo enviar los últimos 10 mensajes para no saturar el contexto
    final trimmed = chatHistory.length > 10
        ? chatHistory.sublist(chatHistory.length - 10)
        : chatHistory;

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...trimmed.map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': userMessage},
    ];

    final client = http.Client();
    final request = http.Request('POST', Uri.parse(_baseUrl));
    request.headers.addAll({
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    });
    request.body = jsonEncode({
      'model': _model,
      'messages': messages,
      'temperature': 0.7,
      'max_tokens': 800,
      'stream': true,
    });

    final response = await client.send(request);

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Error de Groq API: $body');
    }

    // Parseo de Server-Sent Events (SSE)
    var buffer = '';
    await for (final chunk in response.stream.transform(utf8.decoder)) {
      buffer += chunk;
      while (buffer.contains('\n')) {
        final lineEnd = buffer.indexOf('\n');
        final line = buffer.substring(0, lineEnd).trim();
        buffer = buffer.substring(lineEnd + 1);

        if (!line.startsWith('data:')) continue;
        final data = line.substring(5).trim();
        if (data == '[DONE]') return;

        try {
          final json = jsonDecode(data);
          final delta = json['choices']?[0]?['delta']?['content'];
          if (delta != null && delta.isNotEmpty) {
            yield delta;
          }
        } catch (_) {
          // Ignorar líneas no parseables
        }
      }
    }
  }
}
