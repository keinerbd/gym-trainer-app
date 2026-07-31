import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/weekly_routine.dart';
import '../services/routine_service.dart';
import '../services/exercise_service.dart';
import '../services/supabase_service.dart';
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
  String? _selectedDay; // Día seleccionado en la tira semanal

  @override
  void initState() {
    super.initState();
    _selectedDay = WeeklyRoutine.todayEs; // Por defecto, el día de hoy
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
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  tileColor: Colors.white.withValues(alpha: 0.03),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: AppTheme.glassBorder, width: 0.5),
                                  ),
                                  leading: CircleAvatar(
                                    radius: 20,
                                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                                    child: Text('${re.sets}x${re.reps}',
                                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                                  ),
                                  title: Text(re.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                  subtitle: re.notes != null ? Text(re.notes!, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)) : null,
                                  trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExerciseDetailScreen(exercise: fullEx))),
                                ),
                              ),
                            ),
                          );
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

  Widget _buildWeekStrip(WeeklyRoutine routine, String selectedDay) {
    final today = WeeklyRoutine.todayEs;
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
                final isToday = day == today;
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
