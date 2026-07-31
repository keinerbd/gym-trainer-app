import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/weekly_routine.dart';
import '../services/routine_service.dart';
import '../services/groq_service.dart';
import '../services/exercise_service.dart';
import '../theme/app_theme.dart';

/// Pantalla de chat con el entrenador IA.
/// Mantiene el historial de conversación y muestra las respuestas en streaming.
class ChatScreen extends StatefulWidget {
  final String dayName; // Clave en español: 'lunes', 'martes', ...
  final String dayLabel; // Etiqueta: 'Lunes', 'Martes', ...
  final VoidCallback? onRoutineGenerated;

  const ChatScreen({
    super.key,
    required this.dayName,
    required this.dayLabel,
    this.onRoutineGenerated,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _routineSvc = RoutineService();
  final _groqSvc = GroqService();
  final _exerciseSvc = ExerciseService();
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  final List<ChatMessage> _messages = [];
  bool _streaming = false;
  bool _started = false;

  // Sugerencias rápidas
  static const _suggestions = [
    '💪 Sustituye un ejercicio',
    '🔧 Ajusta series y repeticiones',
    '🩹 Dolor o molestias',
    '⏱️ Tiempo de descanso',
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      role: 'assistant',
      content:
          '¡Hola! 👋 Soy tu entrenador IA. Pregúntame lo que quieras sobre tu rutina de ${widget.dayLabel.toLowerCase()}: sustituir ejercicios, técnica, series, descanso...',
    ));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  /// Construye el contexto de toda la rutina semanal.
  String _buildRoutineContext() {
    final routine = _routineSvc.currentRoutine;
    if (routine == null) return 'Sin rutina generada todavía.';

    final buf = StringBuffer();
    for (final day in WeeklyRoutine.dayNames) {
      final exs = routine.days[day] ?? [];
      if (exs.isEmpty) {
        buf.writeln('- $day: descanso');
        continue;
      }
      buf.writeln('- $day:');
      for (final e in exs) {
        final notes = e.notes != null && e.notes!.isNotEmpty
            ? ' (${e.notes})'
            : '';
        buf.writeln('    · ${e.name} — ${e.sets}x${e.reps}$notes');
      }
    }
    return buf.toString();
  }

  Future<void> _send(String text) async {
    final msg = text.trim();
    if (msg.isEmpty || _streaming) return;

    final profile = _routineSvc.profile;
    if (profile == null) {
      setState(() => _messages.add(ChatMessage(
          role: 'assistant',
          content: '⚠️ Primero configura tu perfil en el icono 👤 para que pueda darte recomendaciones personalizadas.')));
      return;
    }
    if (!_groqSvc.hasKey) {
      setState(() => _messages.add(ChatMessage(
          role: 'assistant',
          content: '⚠️ No hay API key de Groq configurada. Ve a la pantalla de calendario para ingresarla.')));
      return;
    }

    setState(() {
      _started = true;
      _messages.add(ChatMessage(role: 'user', content: msg));
      _messages.add(ChatMessage(role: 'assistant', content: ''));
      _streaming = true;
    });
    _inputCtrl.clear();
    _scrollToBottom();

    try {
      await for (final delta in _groqSvc.chatStream(
        profile: profile,
        routineContext: _buildRoutineContext(),
        history: _messages.take(_messages.length - 1).toList(),
        userMessage: msg,
      )) {
        if (!mounted) return;
        setState(() {
          final last = _messages.last;
          _messages[_messages.length - 1] = ChatMessage(
            role: 'assistant',
            content: last.content + delta,
            timestamp: last.timestamp,
          );
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final last = _messages.last;
        _messages[_messages.length - 1] = ChatMessage(
          role: 'assistant',
          content: last.content.isNotEmpty
              ? last.content
              : '❌ ${e.toString().replaceFirst('Exception: ', '')}',
          timestamp: last.timestamp,
        );
      });
    } finally {
      if (mounted) setState(() => _streaming = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = _routineSvc.profile;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Fondo
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
          // Glows
          Positioned(
            top: -80,
            right: -50,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.primary.withValues(alpha: 0.12),
                  Colors.transparent,
                ]),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  AppTheme.accent.withValues(alpha: 0.08),
                  Colors.transparent,
                ]),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Header ─────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(18),
                          border:
                              Border.all(color: AppTheme.glassBorder, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back,
                                  color: AppTheme.textPrimary, size: 22),
                            ),
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppTheme.primary,
                                    AppTheme.primaryLight,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.auto_awesome,
                                  color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Entrenador IA',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'Rutina de ${widget.dayLabel.toLowerCase()}'
                                    '${profile != null ? ' · ${profile.levelLabel}' : ''}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            if (_streaming)
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.primary),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Mensajes ────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_started ? 0 : 1),
                    itemBuilder: (context, index) {
                      // Mostrar sugerencias solo al inicio (antes del 1er mensaje del usuario)
                      if (!_started && index == _messages.length) {
                        return _buildSuggestions();
                      }
                      return _buildBubble(_messages[index]);
                    },
                  ),
                ),

                // ── Input ────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(18),
                          border:
                              Border.all(color: AppTheme.glassBorder, width: 0.5),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inputCtrl,
                                textInputAction: TextInputAction.send,
                                onSubmitted: _streaming ? null : _send,
                                style: const TextStyle(
                                    color: AppTheme.textPrimary, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Escribe tu mensaje...',
                                  hintStyle: const TextStyle(
                                      color: AppTheme.textMuted, fontSize: 13),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: _streaming ? null : () => _send(_inputCtrl.text),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: _streaming
                                      ? AppTheme.primary.withValues(alpha: 0.4)
                                      : AppTheme.primary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.send_rounded,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Sugerencias rápidas ─────────────────────
  Widget _buildSuggestions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRUEBA PREGUNTAR:',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 1.5),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((s) => GestureDetector(
              onTap: _streaming ? null : () => _send(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      width: 0.6),
                ),
                child: Text(s,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  // ── Burbuja de mensaje ──────────────────────
  Widget _buildBubble(ChatMessage msg) {
    if (msg.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(left: 48, top: 4, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryLight],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Text(
            msg.content,
            style: const TextStyle(
                fontSize: 14, color: Colors.white, height: 1.4),
          ),
        ),
      );
    }

    // Mensaje del asistente
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.primary, AppTheme.primaryLight],
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 14),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(right: 40, top: 4, bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
                border: Border.all(color: AppTheme.glassBorder, width: 0.5),
              ),
              child: _streaming && msg == _messages.last && msg.content.isEmpty
                  ? _buildTypingIndicator()
                  : Text(
                      msg.content,
                      style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          height: 1.4),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Indicador de escritura ───────────────────
  Widget _buildTypingIndicator() {
    return const SizedBox(
      height: 20,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Dot(delay: 0),
          SizedBox(width: 4),
          _Dot(delay: 200),
          SizedBox(width: 4),
          _Dot(delay: 400),
        ],
      ),
    );
  }
}

/// Punto animado del indicador de escritura.
class _Dot extends StatefulWidget {
  final int delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.repeat();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final size = 6.0 + 4.0 * (0.5 - (t - 0.5).abs()) * 2;
        return Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppTheme.textSecondary,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
