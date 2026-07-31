import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/exercise.dart';
import '../models/weekly_routine.dart';
import '../services/routine_service.dart';
import '../services/exercise_service.dart';
import '../services/supabase_service.dart';
import '../services/workout_progress_service.dart';
import '../theme/app_theme.dart';
import 'exercise_detail_screen.dart';
import 'calendar_screen.dart';
import 'profile_screen.dart';
import 'auth_screen.dart';
import 'chat_screen.dart';

class TrainerScreen extends StatefulWidget {
  const TrainerScreen({super.key});
  @override
  State<TrainerScreen> createState() => _TrainerScreenState();
}

class _TrainerScreenState extends State<TrainerScreen> {
  final _routineSvc = RoutineService();
  final _exerciseSvc = ExerciseService();
  final _supabase = SupabaseService();
  final _progress = WorkoutProgressService();
  String? _selectedDay; // Día seleccionado en la tira semanal

  @override
  void initState() {
    super.initState();
    _selectedDay = WeeklyRoutine.todayEs; // Por defecto, el día de hoy
    _progress.load();
    _loadData();
  }

  Future<void> _loadData() async {
    // Vincular datos al usuario actual
    _routineSvc.setCurrentUser(_supabase.userId);
    await _routineSvc.load();

    if (_supabase.isInitialized && _supabase.isLoggedIn) {
      final p = await _supabase.getProfile();
      final r = await _supabase.getCurrentRoutine();
      if (p != null) await _routineSvc.saveProfile(p);
      if (r != null) await _routineSvc.saveRoutine(r);
      if (mounted) setState(() {});
    }
  }

  /// Abre el chat con el entrenador IA para el día seleccionado.
  void _openAiChat(String day, String dayLabel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(dayName: day, dayLabel: dayLabel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routine = _routineSvc.currentRoutine;
    final profile = _routineSvc.profile;
    final todayLabel = _routineSvc.todayLabel;
    final hasRoutine = routine != null;
    
    // Ejercicios del día seleccionado (o de hoy por defecto)
    final selectedDay = _selectedDay ?? WeeklyRoutine.todayEs;
    final selectedDayExercises = routine?.days[selectedDay] ?? [];
    final isRest = hasRoutine && selectedDayExercises.isEmpty;
    
    // Nombre del día seleccionado para mostrar
    final selectedDayIdx = WeeklyRoutine.dayNames.indexOf(selectedDay);
    final selectedDayName = selectedDayIdx >= 0 ? WeeklyRoutine.dayNames[selectedDayIdx] : selectedDay;
    final isSelectedToday = selectedDay == WeeklyRoutine.todayEs;

    // Progreso del día seleccionado (ejercicios completados)
    final doneCount = _progress.completedCount(
      DateTime.now(),
      selectedDayExercises.map((e) => e.exerciseId).toList(),
    );
    final totalCount = selectedDayExercises.length;
    final dayProgress = totalCount == 0 ? 0.0 : doneCount / totalCount;

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
          Positioned(
            top: -60, left: -40,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.primary.withValues(alpha: 0.1), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true, floating: true,
                  backgroundColor: Colors.transparent, elevation: 0,
                  title: const Text('Entrenador',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  actions: [
                    if (_supabase.isInitialized)
                      IconButton(
                        icon: const Icon(Icons.logout, color: AppTheme.textMuted, size: 20),
                        tooltip: 'Cerrar sesión',
                        onPressed: () async {
                          await _supabase.signOut();
                          if (mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                              (_) => false,
                            );
                          }
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.person, color: AppTheme.primary),
                      tooltip: 'Perfil',
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                        setState(() {});
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, color: AppTheme.accent),
                      tooltip: 'Preguntar al entrenador IA',
                      onPressed: () => _openAiChat(selectedDay, selectedDayName),
                    ),
                    IconButton(
                      icon: const Icon(Icons.calendar_month, color: AppTheme.accent),
                      tooltip: 'Calendario',
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CalendarScreen(onRoutineGenerated: () => setState(() {})),
                          ),
                        );
                        setState(() {});
                      },
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                              colors: [AppTheme.primary.withValues(alpha: 0.15), AppTheme.accent.withValues(alpha: 0.05)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.glassBorder, width: 0.5),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(isSelectedToday ? 'Hoy, $todayLabel' : selectedDayName,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                                  const Spacer(),
                                  if (profile != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.3),
                                          borderRadius: BorderRadius.circular(10)),
                                      child: Text('${profile.genderLabel} · ${profile.age} años · ${profile.weightKg.toInt()} kg',
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isRest ? '¡Día de descanso! 💆' : hasRoutine ? 'Tu entrenamiento de hoy' : 'Sin rutina asignada',
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                              ),
                              if (hasRoutine && !isRest)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text('${selectedDayExercises.length} ejercicios · ${profile?.goalLabel ?? ''}',
                                      style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                                ),
                              if (hasRoutine && !isRest) ...[
                                const SizedBox(height: 14),
                                // ── Barra de progreso del día ──
                                Row(
                                  children: [
                                    Expanded(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: LinearProgressIndicator(
                                          value: dayProgress,
                                          minHeight: 7,
                                          backgroundColor:
                                              Colors.white.withValues(alpha: 0.08),
                                          valueColor: const AlwaysStoppedAnimation(
                                              AppTheme.primary),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      '$doneCount/$totalCount',
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  doneCount == totalCount
                                      ? '🎉 ¡Entrenamiento completado!'
                                      : 'Completados $doneCount de $totalCount ejercicios',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: doneCount == totalCount
                                          ? AppTheme.primary
                                          : AppTheme.textMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // ── Visual semanal ──────────────────
                if (hasRoutine)
                  SliverToBoxAdapter(child: _buildWeekStrip(routine, selectedDay)),
                if (!hasRoutine)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          if (profile == null) ...[
                            const Text('Configura tu perfil para recibir rutinas personalizadas con IA.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
                            const SizedBox(height: 16),
                            _btn('Configurar perfil', Icons.person, AppTheme.primary,
                                () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())).then((_) => setState(() {}))),
                          ] else ...[
                            const Text('Genera tu primera rutina semanal con IA.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
                            const SizedBox(height: 16),
                            _btn('Generar rutina con IA ✨', Icons.auto_awesome, AppTheme.primary,
                                () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => CalendarScreen(onRoutineGenerated: () => setState(() {}))))),
                          ],
                        ],
                      ),
                    ),
                  ),
                if (hasRoutine && !isRest) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                      child: Row(
                        children: [
                          Text(isSelectedToday ? 'TUS EJERCICIOS' : 'EJERCICIOS - ${selectedDayName.toUpperCase()}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.5)),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () => _openAiChat(selectedDay, selectedDayName),
                            icon: const Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.primary),
                            label: const Text('Preguntar a la IA', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
                          ),
                          TextButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
                            icon: const Icon(Icons.calendar_month, size: 16, color: AppTheme.accent),
                            label: const Text('Ver semana', style: TextStyle(fontSize: 12, color: AppTheme.accent)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final re = selectedDayExercises[index];
                          final fullEx = _exerciseSvc.getById(re.exerciseId);
                          if (fullEx == null) return const SizedBox.shrink();
                          final isDone = _progress.isCompleted(
                              DateTime.now(), re.exerciseId);
                          return _buildExerciseCard(
                              index, re, fullEx, isDone);
                        },
                        childCount: selectedDayExercises.length,
                      ),
                    ),
                  ),
                ],
                if (isRest)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.self_improvement, size: 64, color: AppTheme.accent.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text('Día de descanso', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          const SizedBox(height: 6),
                          const Text('Aprovecha para recuperarte.\n¡Mañana más!',
                              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
                            icon: const Icon(Icons.calendar_month, size: 18, color: AppTheme.accent),
                            label: const Text('Ver calendario semanal', style: TextStyle(color: AppTheme.accent)),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tarjeta de ejercicio ────────────────────
  Widget _buildExerciseCard(
      int index, RoutineExercise re, Exercise fullEx, bool isDone) {
    final color = isDone
        ? AppTheme.accent
        : AppTheme.getCategoryColor(fullEx.category);
    final imgUrl = fullEx.imageUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: isDone
                  ? AppTheme.accent.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDone
                    ? AppTheme.accent.withValues(alpha: 0.4)
                    : AppTheme.glassBorder,
                width: isDone ? 1 : 0.5,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => ExerciseDetailScreen(exercise: fullEx)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    // ── Botón completar ──
                    GestureDetector(
                      onTap: () async {
                        await _progress.toggle(
                            DateTime.now(), re.exerciseId);
                        if (mounted) setState(() {});
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDone
                              ? AppTheme.accent
                              : Colors.transparent,
                          border: Border.all(
                            color: isDone
                                ? AppTheme.accent
                                : AppTheme.textMuted,
                            width: 2,
                          ),
                        ),
                        child: isDone
                            ? const Icon(Icons.check,
                                color: Colors.black, size: 18)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // ── Imagen del ejercicio ──
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: color.withValues(alpha: 0.25),
                            width: 0.6),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: imgUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: color.withValues(alpha: 0.6)),
                                ),
                              ),
                              errorWidget: (_, __, ___) => _exerciseFallback(
                                  fullEx, color),
                            )
                          : _exerciseFallback(fullEx, color),
                    ),
                    const SizedBox(width: 12),

                    // ── Info ──
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  re.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDone
                                        ? AppTheme.accent
                                        : AppTheme.textPrimary,
                                    decoration: isDone
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: AppTheme.accent,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // ── Sets x Reps ──
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${re.sets}x${re.reps}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (re.notes != null && re.notes!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                re.notes!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                AppTheme.getEquipmentIcon(
                                    fullEx.equipment),
                                size: 12,
                                color: AppTheme.getEquipmentColor(
                                    fullEx.equipment),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                fullEx.equipment,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary),
                              ),
                              const SizedBox(width: 10),
                              Icon(Icons.fitness_center,
                                  size: 12,
                                  color: color.withValues(alpha: 0.8)),
                              const SizedBox(width: 4),
                              Text(
                                fullEx.target,
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // ── Temporizador de descanso ──
                    GestureDetector(
                      onTap: () => _openRestTimer(re.name),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: AppTheme.glassBorder, width: 0.5),
                        ),
                        child: const Icon(Icons.timer_outlined,
                            size: 18, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Placeholder cuando el ejercicio no tiene imagen.
  Widget _exerciseFallback(Exercise fullEx, Color color) {
    return Center(
      child: Icon(
        AppTheme.getCategoryIcon(fullEx.category),
        size: 26,
        color: color.withValues(alpha: 0.6),
      ),
    );
  }

  // ── Temporizador de descanso ─────────────────
  void _openRestTimer(String exerciseName) {
    const presets = [30, 45, 60, 90, 120];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RestTimerSheet(
        exerciseName: exerciseName,
        presets: presets,
      ),
    );
  }

  Widget _buildWeekStrip(WeeklyRoutine routine, String selectedDay) {
    const daysAbbr = ['LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.glassBorder, width: 0.5),
            ),
            child: Row(
              children: List.generate(7, (i) {
                final day = WeeklyRoutine.dayNames[i];
                final isSelected = day == selectedDay;
                final exs = routine.days[day] ?? [];
                final isRest = exs.isEmpty;
                final label = routine.dayLabel(day);
                final emoji = routine.dayEmoji(day);

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedDay = day;
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected
                            ? Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 1)
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            daysAbbr[i],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            emoji,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isRest ? '--' : label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: isRest ? AppTheme.textMuted : AppTheme.textSecondary,
                            ),
                          ),
                          if (!isRest)
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              width: 4, height: 4,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected ? AppTheme.primary : AppTheme.accent.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _btn(String label, IconData icon, Color color, VoidCallback onTap) {
    return SizedBox(
      height: 50,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: ElevatedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 20),
            label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.3)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Hoja inferior con temporizador de descanso entre series.
class _RestTimerSheet extends StatefulWidget {
  final String exerciseName;
  final List<int> presets;

  const _RestTimerSheet({
    required this.exerciseName,
    required this.presets,
  });

  @override
  State<_RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<_RestTimerSheet>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  int _remaining = 60;
  bool _running = false;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _start() {
    setState(() => _running = true);
    _pulseCtrl.repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_remaining <= 1) {
        t.cancel();
        _pulseCtrl.stop();
        _pulseCtrl.value = 1;
        if (mounted) {
          setState(() {
            _remaining = 0;
            _running = false;
          });
        }
      } else {
        if (mounted) setState(() => _remaining--);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    _pulseCtrl.stop();
    if (mounted) setState(() => _running = false);
  }

  void _reset() {
    _timer?.cancel();
    _pulseCtrl.stop();
    _pulseCtrl.value = 0;
    if (mounted) {
      setState(() {
        _remaining = 60;
        _running = false;
      });
    }
  }

  String get _formatted {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _remaining == 0;
    final ringColor =
        isDone ? AppTheme.accent : (_running ? AppTheme.primary : AppTheme.textSecondary);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          decoration: BoxDecoration(
            color: AppTheme.bgMid.withValues(alpha: 0.97),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppTheme.glassBorder, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.timer_outlined,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Descanso${widget.exerciseName.isNotEmpty ? ' · ${widget.exerciseName}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close,
                        size: 18, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── Tiempo ──
              AnimatedBuilder(
                animation: _pulseCtrl,
                builder: (context, _) {
                  final scale = 1 + _pulseCtrl.value * 0.03;
                  return Transform.scale(
                    scale: isDone ? 1 : scale,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            ringColor.withValues(alpha: isDone ? 0.3 : 0.18),
                            Colors.transparent,
                          ],
                        ),
                        border: Border.all(
                          color: ringColor.withValues(alpha: 0.5),
                          width: 3,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _formatted,
                              style: TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                color: isDone
                                    ? AppTheme.accent
                                    : AppTheme.textPrimary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                            Text(
                              isDone
                                  ? '¡Descanso terminado!'
                                  : _running
                                      ? 'Descansando...'
                                      : 'Listo para empezar',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDone
                                    ? AppTheme.accent
                                    : AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),

              // ── Presets ──
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: widget.presets.map((p) {
                  final active = !_running && !isDone && _remaining == p;
                  return GestureDetector(
                    onTap: _running
                        ? null
                        : () {
                            setState(() => _remaining = p);
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: active
                            ? AppTheme.primary.withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active
                              ? AppTheme.primary.withValues(alpha: 0.5)
                              : AppTheme.glassBorder,
                          width: 0.6,
                        ),
                      ),
                      child: Text(
                        '${p ~/ 60 > 0 ? '${p ~/ 60}:' : ''}${(p % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // ── Controles ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _reset,
                    icon: const Icon(Icons.replay,
                        color: AppTheme.textSecondary, size: 22),
                    tooltip: 'Reiniciar',
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: ElevatedButton(
                          onPressed: _running ? _pause : _start,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _running
                                ? AppTheme.textSecondary
                                : AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                          ),
                          child: Icon(
                            _running
                                ? Icons.pause
                                : (isDone ? Icons.refresh : Icons.play_arrow),
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () {
                      _pause();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.stop,
                        color: AppTheme.textSecondary, size: 22),
                    tooltip: 'Detener',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
