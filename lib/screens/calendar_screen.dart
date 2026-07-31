import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/weekly_routine.dart';
import '../models/user_profile.dart';
import '../services/routine_service.dart';
import '../services/routine_history_service.dart';
import '../services/groq_service.dart';
import '../services/exercise_service.dart';
import '../services/supabase_service.dart';
import '../services/workout_progress_service.dart';
import '../theme/app_theme.dart';
import 'exercise_detail_screen.dart';
import 'profile_screen.dart';
import 'chat_screen.dart';

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
  final _historySvc = RoutineHistoryService();
  final _progressSvc = WorkoutProgressService();
  bool _generating = false;
  String? _generatingDay;
  String? _error;

  // ── Estado de la vista del calendario ──
  bool _showMonthly = false; // false = vista semanal, true = vista mensual
  DateTime _currentMonth = DateTime.now();
  DateTime? _selectedDay; // Día seleccionado en vista mensual

  @override
  void initState() {
    super.initState();
    _groqSvc.setApiKey(_routineSvc.apiKey ?? '');
    _historySvc.load();
    _progressSvc.load();
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
                      // Toggle vista semanal / mensual
                      if (routine != null)
                        IconButton(
                          icon: Icon(
                            _showMonthly ? Icons.view_week_outlined : Icons.calendar_month,
                            color: AppTheme.primary,
                          ),
                          onPressed: () => setState(() => _showMonthly = !_showMonthly),
                          tooltip: _showMonthly ? 'Vista semanal' : 'Vista mensual',
                        ),
                      if (routine != null)
                        IconButton(
                          icon: const Icon(Icons.refresh, color: AppTheme.primary),
                          onPressed: _generating ? null : _generateFullRoutine,
                          tooltip: 'Regenerar toda la semana',
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
                else if (_showMonthly)
                  Expanded(child: _buildMonthlyCalendar(routine))
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
            onPressed: _generateFullRoutine,
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

        // Estado del día
        final dayStatus = WeeklyRoutine.dayStatus(day);
        final isPast = dayStatus == 'past';
        final isFuture = dayStatus == 'future';
        final isGeneratingThisDay = _generatingDay == day;
        final canRegenerate = WeeklyRoutine.canRegenerateRoutine(day);

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
                      : isPast
                          ? Colors.white.withValues(alpha: 0.01)
                          : Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isToday
                        ? AppTheme.primary.withValues(alpha: 0.4)
                        : isPast
                            ? AppTheme.textMuted.withValues(alpha: 0.15)
                            : AppTheme.glassBorder,
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
                            : isPast
                                ? AppTheme.textMuted.withValues(alpha: 0.08)
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
                              color: isToday
                                  ? AppTheme.primary
                                  : isPast
                                      ? AppTheme.textMuted
                                      : AppTheme.textPrimary,
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
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            dayLabel[0].toUpperCase() + dayLabel.substring(1),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? AppTheme.primary
                                  : isPast
                                      ? AppTheme.textMuted
                                      : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        // Badge día bloqueado (pasado)
                        if (isPast)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.textMuted.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline, size: 10, color: AppTheme.textMuted),
                                SizedBox(width: 2),
                                Text(
                                  'CERRADO',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textMuted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Badge día futuro con ejercicios
                        if (isFuture && !isRest)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.schedule, size: 10, color: AppTheme.accent),
                                SizedBox(width: 2),
                                Text(
                                  'PRÓXIMO',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.accent,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    trailing: isRest
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'DESCANSO',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textMuted,
                                  letterSpacing: 1,
                                ),
                              ),
                              if (canRegenerate) ...[
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: isGeneratingThisDay
                                      ? const Padding(
                                          padding: EdgeInsets.all(5),
                                          child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                        )
                                      : IconButton(
                                          padding: EdgeInsets.zero,
                                          iconSize: 16,
                                          icon: Icon(Icons.auto_awesome,
                                              color: AppTheme.primary.withValues(alpha: 0.7)),
                                          tooltip: 'Generar rutina para este día',
                                          onPressed: () => _generateDayRoutine(day, dayLabel),
                                        ),
                                ),
                              ],
                            ],
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
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isPast ? AppTheme.textMuted : AppTheme.textPrimary,
                            ),
                          ),
                          subtitle: ex.notes != null
                              ? Text(
                                  ex.notes!,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                )
                              : null,
                          trailing: const Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
                          onTap: fullExercise != null && !isPast
                              ? () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ExerciseDetailScreen(exercise: fullExercise),
                                    ),
                                  )
                              : null,
                        );
                      }),
                      // ── Preguntar al entrenador IA (solo si no es pasado) ──
                      if (exercises.isNotEmpty && !isPast)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                          child: TextButton.icon(
                            onPressed: () => _askAi(day, dayLabel, exercises),
                            icon: const Icon(Icons.chat_bubble_outline, size: 16, color: AppTheme.accent),
                            label: const Text('Preguntar al entrenador IA',
                                style: TextStyle(fontSize: 12, color: AppTheme.accent)),
                          ),
                        ),
                      // ── Botón regenerar este día (solo hoy/futuro) ──
                      if (canRegenerate && !isRest)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: SizedBox(
                            width: double.infinity,
                            child: isGeneratingThisDay
                                ? const Column(
                                    children: [
                                      SizedBox(height: 4),
                                      CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                                      SizedBox(height: 6),
                                      Text(
                                        'Regenerando este día...',
                                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  )
                                : OutlinedButton.icon(
                                    onPressed: () => _generateDayRoutine(day, dayLabel),
                                    icon: const Icon(Icons.auto_awesome, size: 14, color: AppTheme.primary),
                                    label: Text('Regenerar $dayLabel',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.primary)),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.3)),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
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

  // ══════════════════════════════════════════════════════════════
  //  VISTA MENSUAL — Registro día por día
  // ══════════════════════════════════════════════════════════════
  Widget _buildMonthlyCalendar(WeeklyRoutine routine) {
    final now = DateTime.now();
    final year = _currentMonth.year;
    final month = _currentMonth.month;
    final firstDay = DateTime(year, month, 1);
    final lastDay = DateTime(year, month + 1, 0);
    final startOffset = (firstDay.weekday - 1) % 7; // 0=lunes
    final daysInMonth = lastDay.day;

    const dayHeaders = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
      children: [
        // ── Navegación de mes ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left, color: AppTheme.primary),
              onPressed: () => setState(() {
                _currentMonth = DateTime(year, month - 1);
                _selectedDay = null;
              }),
            ),
            Text(
              _monthName(month).toUpperCase(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '$year',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, color: AppTheme.primary),
              onPressed: () => setState(() {
                _currentMonth = DateTime(year, month + 1);
                _selectedDay = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Encabezados L-D ──
        Row(
          children: dayHeaders
              .map((d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),

        // ── Grilla de días ──
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: startOffset + daysInMonth,
          itemBuilder: (context, index) {
            if (index < startOffset) return const SizedBox.shrink();

            final day = index - startOffset + 1;
            final date = DateTime(year, month, day);
            final isToday = date.year == now.year &&
                date.month == now.month &&
                date.day == now.day;
            final isFuture = date.isAfter(now);
            final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
            final isSelected = _selectedDay != null &&
                _selectedDay!.year == date.year &&
                _selectedDay!.month == date.month &&
                _selectedDay!.day == date.day;

            // ── Obtener estado del día ──
            final dayIdx = (date.weekday - 1) % 7;
            final dayName = WeeklyRoutine.dayNames[dayIdx];
            final exercises = routine.days[dayName] ?? [];
            final hasExercises = exercises.isNotEmpty;
            final hasRecord = _historySvc.hasRecordForDate(date);

            // Progreso si hay datos
            int doneCount = 0;
            int totalCount = exercises.length;
            if (totalCount > 0 && isPast) {
              doneCount = _progressSvc.completedCount(
                date,
                exercises.map((e) => e.exerciseId).toList(),
              );
            }

            // ── Color del día ──
            Color bgColor;
            Color borderColor;
            Color textColor;
            Widget? indicator;

            if (isToday) {
              bgColor = AppTheme.primary.withValues(alpha: 0.25);
              borderColor = AppTheme.primary;
              textColor = AppTheme.primary;
            } else if (isFuture) {
              bgColor = Colors.white.withValues(alpha: 0.03);
              borderColor = AppTheme.glassBorder;
              textColor = AppTheme.textSecondary;
            } else if (!hasRecord && !hasExercises) {
              // Sin datos de rutina
              bgColor = Colors.white.withValues(alpha: 0.02);
              borderColor = AppTheme.glassBorder;
              textColor = AppTheme.textMuted;
            } else if (!hasExercises) {
              // Día de descanso con rutina
              bgColor = Colors.white.withValues(alpha: 0.03);
              borderColor = AppTheme.glassBorder;
              textColor = AppTheme.textMuted;
            } else if (totalCount > 0 && doneCount == totalCount) {
              // ✅ Completado
              bgColor = AppTheme.accent.withValues(alpha: 0.15);
              borderColor = AppTheme.accent;
              textColor = AppTheme.accent;
              indicator = Icon(Icons.check_circle, size: 10, color: AppTheme.accent);
            } else if (doneCount > 0) {
              // 🟡 Parcial
              bgColor = Colors.amber.withValues(alpha: 0.12);
              borderColor = Colors.amber;
              textColor = Colors.amber;
              indicator = Icon(Icons.adjust, size: 10, color: Colors.amber);
            } else if (isPast && hasExercises) {
              // ❌ No completado
              bgColor = Colors.red.withValues(alpha: 0.08);
              borderColor = Colors.red.withValues(alpha: 0.3);
              textColor = Colors.red;
              indicator = Icon(Icons.close, size: 10, color: Colors.red.withValues(alpha: 0.6));
            } else {
              // Futuro con ejercicios asignados
              bgColor = AppTheme.primary.withValues(alpha: 0.06);
              borderColor = AppTheme.primary.withValues(alpha: 0.2);
              textColor = AppTheme.textPrimary;
            }

            return GestureDetector(
              onTap: () => setState(() => _selectedDay = date),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : borderColor,
                    width: isSelected ? 1.5 : 0.5,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    if (indicator != null) ...[
                      const SizedBox(height: 1),
                      indicator,
                    ] else if (!hasExercises && hasRecord && !isFuture && isPast) ...[
                      const SizedBox(height: 1),
                      Icon(Icons.bedtime_outlined,
                          size: 9, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                    ],
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 16),

        // ── Leyenda ──
        _buildLegend(),

        // ── Detalle del día seleccionado ──
        if (_selectedDay != null) ...[
          const SizedBox(height: 12),
          _buildSelectedDayDetail(routine),
        ],
      ],
    );
  }

  Widget _buildLegend() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.glassBorder, width: 0.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legendItem(AppTheme.accent, Icons.check_circle, 'Completado'),
              _legendItem(Colors.amber, Icons.adjust, 'Parcial'),
              _legendItem(Colors.red.withValues(alpha: 0.6), Icons.close, 'Sin hacer'),
              _legendItem(AppTheme.textMuted, Icons.bedtime_outlined, 'Descanso'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayDetail(WeeklyRoutine routine) {
    final date = _selectedDay!;
    final now = DateTime.now();
    final isToday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
    final isPast = date.isBefore(DateTime(now.year, now.month, now.day));
    final isFuture = date.isAfter(DateTime(now.year, now.month, now.day));
    final dayIdx = (date.weekday - 1) % 7;
    final dayName = WeeklyRoutine.dayNames[dayIdx];
    final dayLabel = _capitalize(dayName);
    final exercises = routine.days[dayName] ?? [];
    final hasExercises = exercises.isNotEmpty;
    final hasRecord = _historySvc.hasRecordForDate(date);

    int doneCount = 0;
    int totalCount = exercises.length;
    if (totalCount > 0) {
      doneCount = _progressSvc.completedCount(
        date,
        exercises.map((e) => e.exerciseId).toList(),
      );
    }

    // Determinar estado del día
    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (isFuture) {
      if (hasExercises) {
        statusText = 'Rutina programada — ${exercises.length} ejercicios';
        statusColor = AppTheme.primary;
        statusIcon = Icons.schedule;
      } else {
        statusText = 'Día de descanso';
        statusColor = AppTheme.textMuted;
        statusIcon = Icons.bedtime_outlined;
      }
    } else if (!hasRecord && !hasExercises) {
      statusText = 'Sin registro de rutina';
      statusColor = AppTheme.textMuted;
      statusIcon = Icons.help_outline;
    } else if (!hasExercises) {
      statusText = 'Día de descanso';
      statusColor = AppTheme.textMuted;
      statusIcon = Icons.bedtime_outlined;
    } else if (totalCount > 0 && doneCount == totalCount) {
      statusText = '🎉 ¡Rutina completada! $doneCount/$totalCount';
      statusColor = AppTheme.accent;
      statusIcon = Icons.check_circle;
    } else if (doneCount > 0) {
      statusText = 'Rutina parcial — $doneCount/$totalCount ejercicios';
      statusColor = Colors.amber;
      statusIcon = Icons.adjust;
    } else {
      statusText = 'Rutina sin completar — $totalCount ejercicios';
      statusColor = Colors.red.withValues(alpha: 0.7);
      statusIcon = Icons.close;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.glassBorder, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(statusIcon, size: 20, color: statusColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$dayLabel ${date.day}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Bara de progreso (si hay ejercicios)
              if (hasExercises && !isFuture) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: totalCount > 0 ? doneCount / totalCount : 0,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation(statusColor),
                  ),
                ),
              ],

              // Lista de ejercicios
              if (hasExercises) ...[
                const SizedBox(height: 12),
                ...exercises.map((ex) {
                  final fullEx = _exerciseSvc.getById(ex.exerciseId);
                  final isDone = isPast &&
                      _progressSvc.isCompleted(date, ex.exerciseId);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
                          size: 14,
                          color: isDone ? AppTheme.accent : AppTheme.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            ex.name,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDone ? AppTheme.accent : AppTheme.textSecondary,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              decorationColor: AppTheme.accent,
                            ),
                          ),
                        ),
                        Text(
                          '${ex.sets}x${ex.reps}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDone ? AppTheme.accent : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const names = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return names[month];
  }

  String _capitalize(String s) => s[0].toUpperCase() + s.substring(1);

  Future<void> _askAi(String day, String dayLabel, List<RoutineExercise> exercises) async {
    final profile = _routineSvc.profile;
    if (profile == null) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          dayName: day,
          dayLabel: dayLabel,
          onRoutineGenerated: widget.onRoutineGenerated,
        ),
      ),
    );
  }

  int _dayNumber(int index) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return monday.add(Duration(days: index)).day;
  }

  Future<void> _generateFullRoutine() async {
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
      final supabase = SupabaseService();
      List<Map<String, String>> ragExs;

      if (supabase.isInitialized) {
        ragExs = await supabase.ragSearchExercises(profile: profile, limit: 60);
      } else {
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

      await _routineSvc.saveRoutine(routine);

      // Registrar en historial
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final daysWithExercises = routine.days.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => e.key)
          .toList();
      await _historySvc.registerRoutine(
        weekStart: monday,
        daysWithExercises: daysWithExercises,
      );

      if (supabase.isInitialized && supabase.isLoggedIn) {
        try {
          await supabase.saveRoutine(routine);
        } catch (_) {}
      }

      setState(() => _generating = false);
      widget.onRoutineGenerated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ ¡Rutina regenerada con IA!'),
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

  /// Regenera la rutina para UN solo día específico.
  Future<void> _generateDayRoutine(String day, String dayLabel) async {
    final profile = _routineSvc.profile;
    if (profile == null) {
      setState(() => _error = 'Configura tu perfil primero.');
      return;
    }
    if (!_groqSvc.hasKey) {
      setState(() => _error = 'Ingresa tu API key de Groq.');
      return;
    }
    // No regenerar días pasados
    if (WeeklyRoutine.isLocked(day)) {
      setState(() => _error = 'No se puede modificar un día que ya pasó.');
      return;
    }

    setState(() {
      _generatingDay = day;
      _error = null;
    });

    try {
      final supabase = SupabaseService();
      List<Map<String, String>> ragExs;

      if (supabase.isInitialized) {
        ragExs = await supabase.ragSearchExercises(profile: profile, limit: 60);
      } else {
        ragExs = _exerciseSvc.exercises.take(80).map((e) => {
              'id': e.id,
              'name': e.name,
              'category': e.category,
              'equipment': e.equipment,
              'target': e.target,
            }).toList();
      }

      // Determinar grupo muscular del día actual para dar contexto a la IA
      final routine = _routineSvc.currentRoutine;
      String? muscleGroup;
      if (routine != null) {
        muscleGroup = routine.dayLabel(day);
      }

      final newExercises = await _groqSvc.generateDayRoutine(
        profile: profile,
        dayName: day,
        ragExercises: ragExs,
        muscleGroup: muscleGroup,
      );

      // Actualizar solo ese día en la rutina
      await _routineSvc.updateDay(day, newExercises);

      // Actualizar historial con los días que tienen ejercicios
      final updatedRoutine = _routineSvc.currentRoutine;
      if (updatedRoutine != null) {
        final now = DateTime.now();
        final monday = now.subtract(Duration(days: now.weekday - 1));
        final daysWithExercises = updatedRoutine.days.entries
            .where((e) => e.value.isNotEmpty)
            .map((e) => e.key)
            .toList();
        await _historySvc.registerRoutine(
          weekStart: monday,
          daysWithExercises: daysWithExercises,
        );
      }

      if (supabase.isInitialized && supabase.isLoggedIn) {
        try {
          final updated = _routineSvc.currentRoutine;
          if (updated != null) await supabase.saveRoutine(updated);
        } catch (_) {}
      }

      setState(() => _generatingDay = null);
      widget.onRoutineGenerated?.call();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ¡Rutina de $dayLabel regenerada!'),
            backgroundColor: AppTheme.bgMid,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _generatingDay = null;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }
}
