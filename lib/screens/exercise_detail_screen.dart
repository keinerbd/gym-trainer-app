import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';

/// Pantalla de detalle de ejercicio - solo español.
class ExerciseDetailScreen extends StatefulWidget {
  final Exercise exercise;
  const ExerciseDetailScreen({super.key, required this.exercise});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final FavoritesService _fav = FavoritesService();
  bool _showGif = true;

  bool get _isFav => _fav.isFavorite(widget.exercise.id);

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final color = AppTheme.getCategoryColor(ex.category);
    final hasGif = ex.gifUrlFull != null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color.withValues(alpha: 0.08), AppTheme.bgDark, AppTheme.bgMid],
                ),
              ),
            ),
          ),
          Positioned(
            top: -60, right: -40,
            child: Container(
              width: 220, height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color.withValues(alpha: 0.15), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  pinned: true,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new, size: 18),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  actions: [
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isFav ? Icons.favorite : Icons.favorite_border,
                          size: 18,
                          color: _isFav ? Colors.redAccent : AppTheme.textSecondary,
                        ),
                      ),
                      onPressed: () async {
                        await _fav.toggle(ex.id);
                        setState(() {});
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _mediaSection(ex, color, hasGif),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ex.name,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, height: 1.15)),
                        const SizedBox(height: 16),

                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _chip(Icons.category, ex.category.toUpperCase(), color),
                          _chip(Icons.gps_fixed, ex.target, AppTheme.primary),
                          _chip(Icons.fitness_center, ex.equipment, AppTheme.getEquipmentColor(ex.equipment)),
                        ]),

                        const SizedBox(height: 24),

                        // Músculos
                        _glassSection('MÚSCULOS', Icons.accessibility_new, color,
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_cap(ex.target), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                            const SizedBox(height: 4),
                            Text('Sinergista: ${_cap(ex.muscleGroup)}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            if (ex.secondaryMuscles.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Secundarios: ${ex.secondaryMusclesFormatted}', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ],
                          ]),
                        ),

                        const SizedBox(height: 16),

                        // Instrucciones en español
                        if (ex.instructionsEs.isNotEmpty)
                          _glassSection('INSTRUCCIONES', Icons.menu_book, AppTheme.textPrimary,
                            Text(ex.instructionsEs, style: const TextStyle(fontSize: 14, height: 1.7, color: AppTheme.textSecondary)),
                          ),

                        const SizedBox(height: 16),

                        // Atribución
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.15)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.copyright, size: 13, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(child: Text(ex.attribution, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted, fontStyle: FontStyle.italic))),
                          ]),
                        ),
                      ],
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

  Widget _mediaSection(Exercise ex, Color color, bool hasGif) {
    final gifUrl = ex.gifUrlFull;
    final imgUrl = ex.imageUrl;
    return GestureDetector(
      onTap: hasGif ? () => setState(() => _showGif = !_showGif) : null,
      child: Stack(fit: StackFit.expand, children: [
        Container(color: color.withValues(alpha: 0.04)),
        if (_showGif && gifUrl != null)
          Image.network(gifUrl, fit: BoxFit.contain, frameBuilder: _fadeIn, errorBuilder: (_, __, ___) => _fallback(imgUrl, ex, color))
        else
          _fallback(imgUrl, ex, color),
        if (hasGif)
          Positioned(
            bottom: 10, right: 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(18)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(_showGif ? Icons.gif : Icons.image, color: Colors.white, size: 15),
                    const SizedBox(width: 5),
                    Text(_showGif ? 'GIF' : 'IMG', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _fallback(String? imgUrl, Exercise ex, Color color) {
    if (imgUrl != null) return Image.network(imgUrl, fit: BoxFit.contain, frameBuilder: _fadeIn, errorBuilder: (_, __, ___) => _icon(ex, color));
    return _icon(ex, color);
  }

  Widget _icon(Exercise ex, Color color) => Center(child: Icon(AppTheme.getCategoryIcon(ex.category), size: 70, color: color.withValues(alpha: 0.2)));

  Widget _fadeIn(BuildContext ctx, Widget child, int? frame, bool sync) {
    if (sync) return child;
    return AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: const Duration(milliseconds: 300), child: child);
  }

  Widget _chip(IconData icon, String label, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: c.withValues(alpha: 0.2), width: 0.5)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: c), const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c))]),
  );

  Widget _glassSection(String title, IconData icon, Color c, Widget child) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        width: double.infinity, padding: const EdgeInsets.all(18),
        decoration: AppTheme.glassSurface(opacity: 0.06),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 16, color: c), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.2))]),
          const SizedBox(height: 10), child,
        ]),
      ),
    ),
  );

  String _cap(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}
