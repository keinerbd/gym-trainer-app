import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/routine_service.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';

/// Pantalla de perfil del usuario - configura género, edad, peso, altura, objetivo.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _routineSvc = RoutineService();
  final _formKey = GlobalKey<FormState>();

  late String _gender;
  late String _fitnessLevel;
  late String _goal;
  late TextEditingController _ageCtrl;
  late TextEditingController _weightCtrl;
  late TextEditingController _heightCtrl;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = _routineSvc.profile;
    _gender = p?.gender ?? 'male';
    _fitnessLevel = p?.fitnessLevel ?? 'beginner';
    _goal = p?.goal ?? 'general';
    _ageCtrl = TextEditingController(text: '${p?.age ?? 25}');
    _weightCtrl = TextEditingController(text: '${p?.weightKg ?? 70}');
    _heightCtrl = TextEditingController(text: '${p?.heightCm ?? 170}');
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text(
                        'Tu Perfil',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.person, color: AppTheme.primary, size: 28),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Configura tu perfil para que la IA genere rutinas personalizadas.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 24),

                  // ── Género ──────────────────
                  _sectionLabel('GÉNERO'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _genderBtn('male', '♂ Hombre', Icons.male),
                      const SizedBox(width: 10),
                      _genderBtn('female', '♀ Mujer', Icons.female),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Datos físicos ───────────
                  _sectionLabel('DATOS FÍSICOS'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _numberField('Edad', _ageCtrl, 'años')),
                      const SizedBox(width: 10),
                      Expanded(child: _numberField('Peso (kg)', _weightCtrl, 'kg')),
                      const SizedBox(width: 10),
                      Expanded(child: _numberField('Altura (cm)', _heightCtrl, 'cm')),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Nivel ───────────────────
                  _sectionLabel('NIVEL DE EXPERIENCIA'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    _chipBtn('beginner', '🌱 Principiante'),
                    _chipBtn('intermediate', '🔥 Intermedio'),
                    _chipBtn('advanced', '💪 Avanzado'),
                  ]),
                  const SizedBox(height: 20),

                  // ── Objetivo ────────────────
                  _sectionLabel('OBJETIVO'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _chipBtn('lose_weight', '⚖️ Perder peso'),
                    _chipBtn('build_muscle', '🏋️ Ganar músculo'),
                    _chipBtn('tone', '✨ Tonificar'),
                    _chipBtn('strength', '🦾 Fuerza'),
                    _chipBtn('general', '❤️ Salud general'),
                  ]),
                  const SizedBox(height: 32),

                  // ── Botón guardar ───────────
                  SizedBox(
                    height: 52,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'GUARDAR PERFIL',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 1.5,
        ),
      );

  Widget _genderBtn(String value, String label, IconData icon) {
    final selected = _gender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _gender = value),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected
                    ? AppTheme.primary.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.glassBorder,
                  width: selected ? 1.2 : 0.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(icon, color: selected ? AppTheme.primary : AppTheme.textMuted, size: 26),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppTheme.primary : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _numberField(String label, TextEditingController ctrl, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                suffixText: unit,
                suffixStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requerido';
                if (int.tryParse(v) == null) return 'Número';
                return null;
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipBtn(String value, String label) {
    final selected = (value == _fitnessLevel || value == _goal);
    final isLevel = ['beginner', 'intermediate', 'advanced'].contains(value);
    return GestureDetector(
      onTap: () => setState(() {
        if (isLevel) {
          _fitnessLevel = value;
        } else {
          _goal = value;
        }
      }),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? AppTheme.primary : AppTheme.glassBorder,
                width: selected ? 1.2 : 0.5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.primary : AppTheme.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final profile = UserProfile(
      gender: _gender,
      age: int.tryParse(_ageCtrl.text) ?? 25,
      weightKg: double.tryParse(_weightCtrl.text) ?? 70,
      heightCm: double.tryParse(_heightCtrl.text) ?? 170,
      fitnessLevel: _fitnessLevel,
      goal: _goal,
    );

    // Guardar localmente (con clave por usuario)
    await _routineSvc.saveProfile(profile);

    // Sincronizar con Supabase si está disponible
    final supabase = SupabaseService();
    if (supabase.isInitialized && supabase.isLoggedIn) {
      try {
        await supabase.saveProfile(profile);
      } catch (_) {
        // Ya está guardado localmente
      }
    }

    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Perfil guardado correctamente'),
          backgroundColor: AppTheme.bgMid,
        ),
      );
      Navigator.pop(context);
    }
  }
}
