import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/weekly_routine.dart';
import '../models/user_profile.dart';
import '../services/routine_service.dart';
import '../services/groq_service.dart';
import '../services/exercise_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'exercise_detail_screen.dart';
import 'profile_screen.dart';
import '../services/groq_service.dart';

/// Pantalla de calendario semanal con la rutina generada por IA.
class CalendarScreen extends StatefulWidget {
  final VoidCallback? onRoutineGenerated;

  const CalendarScreen({super.key, this.onRoutineGenerated});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _routineSvc = RoutineService();
  final _groqSvc = GroqService();
  final _exerciseSvc = ExerciseService();
  bool _generating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _groqSvc.setApiKey(_routineSvc.apiKey ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final routine = _routineSvc.currentRoutine;
    final profile = _routineSvc.profile;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.bgDark, AppTheme.bgMid, AppTheme.bgDark],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Mi Rutina',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (routine != null)
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppTheme.primary),
                          onPressed: _generating ? null : _generateRoutine,
                          tooltip: 'Regenerar rutina',
                        ),
                    ],
                  ),
                ),

                // Error
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => setState(() => _error = null),
                          ),
                        ],
                      ),
                    ),
                  ),

                // No routine yet
                if (routine == null)
                  Expanded(child: _buildNoRoutine(profile))
                else
                  Expanded(child: _buildCalendar(routine)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRoutine(UserProfile? profile) {
    final hasProfile = profile != null;
    final hasKey = _groqSvc.hasKey;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_month,
              size: 72,
              color: AppTheme.textMuted.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sin rutina asignada',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasProfile
                  ? 'Genera tu primera rutina con IA.'
                  : 'Primero configura tu perfil.',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            if (!hasKey) ...[
              // API Key input
              _buildApiKeyInput(),
            ] else if (hasProfile) ...[
              // Generate button
              _buildGenerateButton(),
            ] else ...[
              // Go to profile
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    );
                  },
                  icon: const Icon(Icons.person, size: 20),
                  label: const Text('Configurar perfil',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],

            if (_generating) ...[
              const SizedBox(height: 20),
              const Column(
                children: [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 12),
                  Text(
                    'La IA está creando tu rutina...',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  Text(
                    'Esto puede tardar ~15 segundos',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildApiKeyInput() {
    final ctrl = TextEditingController(text: _groqSvc.apiKey ?? '');

    return Column(
      children: [
        const Text(
          'Ingresa tu API Key de Groq',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Consíguela gratis en console.groq.com',
          style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: TextField(
              controller: ctrl,
              obscureText: true,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'gsk_...',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check, color: AppTheme.primary),
                  onPressed: () async {
                    final key = ctrl.text.trim();
                    if (key.isNotEmpty) {
                      _groqSvc.setApiKey(key);
                      await _routineSvc.saveApiKey(key);
                      setState(() {});
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      height: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ElevatedButton.icon(
            onPressed: _generateRoutine,
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: const Text('GENERAR RUTINA CON IA',
                style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendar(WeeklyRoutine routine) {
    final today = WeeklyRoutine.todayEs;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      itemCount: 7,
      itemBuilder: (context, index) {
        final day = WeeklyRoutine.dayNames[index];
        final exercises = routine.days[day] ?? [];
        final isToday = day == today;
        final isRest = exercises.isEmpty;
        final dayNumber = _dayNumber(index);
        final dayLabel = WeeklyRoutine.dayNames[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: isToday
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isToday ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.glassBorder,
                    width: isToday ? 1.2 : 0.5,
                  ),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    initiallyExpanded: isToday,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isToday
                            ? AppTheme.primary.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isToday ? AppTheme.primary : AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            dayLabel.substring(0, 3).toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isToday ? AppTheme.primary : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      dayLabel[0].toUpperCase() + dayLabel.substring(1),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isToday ? AppTheme.primary : AppTheme.textPrimary,
                      ),
                    ),
                    trailing: isRest
                        ? const Text(
                            'DESCANSO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textMuted,
                              letterSpacing: 1,
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${exercises.length} ejercicios',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                          ),
                    children: [
                      ...exercises.map((ex) {
                      final fullExercise = _exerciseSvc.getById(ex.exerciseId);
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                          child: Text(
                            '${ex.sets}x${ex.reps}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                        title: Text(
                          ex.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        subtitle: ex.notes != null
                            ? Text(
                                ex.notes!,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              )
                            : null,
                        trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                        onTap: fullExercise != null
                            ? () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ExerciseDetailScreen(exercise: fullExercise),
                                  ),
                                )
                            : null,
                      );
                    }),
                    // ── Botón de preguntar al entrenador IA ──
                    if (exercises.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                        child: TextButton.icon(
                          onPressed: () => _askAi(day, dayLabel, exercises),
                          icon: const Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.accent),
                          label: const Text('Preguntar al entrenador IA',
                              style: TextStyle(fontSize: 12, color: AppTheme.accent)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      },
    );
  }

  Future<void> _askAi(String day, String dayLabel, List<RoutineExercise> exercises) async {
    final profile = _routineSvc.profile;
    if (profile == null) return;

    final currentExs = exercises.map((e) => {
      'id': e.exerciseId,
      'name': e.name,
      'category': '',
      'equipment': '',
      'target': '',
    }).toList();

    // Obtener ejercicios disponibles (los del RAG)
    final supabase = SupabaseService();
    List<Map<String, String>> availableExs;
    if (supabase.isInitialized) {
      availableExs = await supabase.ragSearchExercises(profile: profile, limit: 40);
    } else {
      availableExs = _exerciseSvc.exercises.take(60).map((e) => {
        'id': e.id,
        'name': e.name,
        'category': e.category,
        'equipment': e.equipment,
        'target': e.target,
      }).toList();
    }

    final ctrl = TextEditingController();
    String? response;
    bool loading = false;

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.bgMid.withValues(alpha: 0.95),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: AppTheme.glassBorder, width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, color: AppTheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Entrenador IA · $dayLabel',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    // Exercises in the day
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 6, runSpacing: 4,
                        children: exercises.map((e) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('${e.sets}x${e.reps} ${e.name}',
                              style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // AI response
                    if (response != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                          ),
                          child: Text(response!, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5)),
                        ),
                      ),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                      ),
                    // Input
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: TextField(
                                  controller: ctrl,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                                  decoration: InputDecoration(
                                    hintText: 'Ej: "Sustituye press de banca por otro ejercicio de pecho"',
                                    hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    border: InputBorder.none,
                                    filled: true,
                                    fillColor: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: loading ? null : () async {
                              final msg = ctrl.text.trim();
                              if (msg.isEmpty) return;
                              setModalState(() {
                                loading = true;
                                response = null;
                              });
                              try {
                                final reply = await _groqSvc.chatAdvice(
                                  profile: profile,
                                  dayName: dayLabel,
                                  currentExercises: currentExs,
                                  availableExercises: availableExs,
                                  userMessage: msg,
                                );
                                setModalState(() {
                                  response = reply;
                                  loading = false;
                                });
                              } catch (e) {
                                setModalState(() {
                                  response = 'Error: ${e.toString().replaceFirst("Exception: ", "")}';
                                  loading = false;
                                });
                              }
                            },
                            child: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: AppTheme.primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _dayNumber(int index) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: index)).day;
  }

  Future<void> _generateRoutine() async {
    final profile = _routineSvc.profile;
    if (profile == null) {
      setState(() => _error = 'Configura tu perfil primero.');
      return;
    }
    if (!_groqSvc.hasKey) {
      setState(() => _error = 'Ingresa tu API key de Groq.');
      return;
    }

    setState(() {
      _generating = true;
      _error = null;
    });

    try {
      // ── RAG: Buscar ejercicios relevantes ─────
      final supabase = SupabaseService();
      List<Map<String, String>> ragExs;

      if (supabase.isInitialized) {
        ragExs = await supabase.ragSearchExercises(profile: profile, limit: 60);
      } else {
        // Fallback: muestra aleatoria del dataset local
        ragExs = _exerciseSvc.exercises.take(80).map((e) => {
              'id': e.id,
              'name': e.name,
              'category': e.category,
              'equipment': e.equipment,
              'target': e.target,
            }).toList();
      }

      final routine = await _groqSvc.generateRoutine(
        profile: profile,
        ragExercises: ragExs,
      );

      // Siempre guardar localmente para que la UI se actualice
      await _routineSvc.saveRoutine(routine);

      // Sincronizar con Supabase si está disponible
      if (supabase.isInitialized && supabase.isLoggedIn) {
        try {
          await supabase.saveRoutine(routine);
        } catch (_) {
          // Si falla Supabase, ya está guardado localmente
        }
      }

      setState(() => _generating = false);
      widget.onRoutineGenerated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ¡Rutina generada con IA + RAG!'),
            backgroundColor: AppTheme.bgMid,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _generating = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }
}
