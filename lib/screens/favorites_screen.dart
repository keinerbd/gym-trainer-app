import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import 'exercise_detail_screen.dart';

/// Pantalla de favoritos mejorada con búsqueda, filtros por categoría,
/// vista de cuadrícula con animaciones y eliminar por deslizamiento.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _exSvc = ExerciseService();
  final _favSvc = FavoritesService();
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  String? _selectedCategory;
  String _query = '';

  List<Exercise> get _allFavorites =>
      _exSvc.getByIds(_favSvc.favorites.toList());

  List<Exercise> get _filtered {
    var list = _allFavorites;
    if (_selectedCategory != null) {
      list = list.where((e) => e.category == _selectedCategory).toList();
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list
          .where((e) =>
              e.name.toLowerCase().contains(q) ||
              e.target.toLowerCase().contains(q) ||
              e.equipment.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  /// Categorías presentes entre los favoritos.
  List<String> get _availableCategories {
    final cats = _allFavorites.map((e) => e.category).toSet().toList();
    cats.sort();
    return cats;
  }

  @override
  void initState() {
    super.initState();
    _favSvc.load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  Future<void> _removeFavorite(Exercise ex) async {
    await _favSvc.remove(ex.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ex.name} eliminado de favoritos'),
          backgroundColor: AppTheme.bgMid,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Deshacer',
            textColor: AppTheme.primary,
            onPressed: () async {
              await _favSvc.toggle(ex.id);
              _refresh();
            },
          ),
        ),
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final favs = _filtered;
    final totalCount = _allFavorites.length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // ── Fondo gradiente ──
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

          // ── Glow decorativo ──
          Positioned(
            top: -80,
            right: -50,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.redAccent.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -60,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Contenido ──
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(totalCount),

                // Barra de búsqueda
                if (totalCount > 0) _buildSearchBar(),

                // Filtros de categoría
                if (_availableCategories.isNotEmpty)
                  _buildCategoryFilters(),

                // Contador de resultados
                if (totalCount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          '${favs.length} ejercicio${favs.length == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedCategory != null || _query.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategory = null;
                                _query = '';
                                _searchCtrl.clear();
                              });
                            },
                            child: const Text(
                              'Limpiar filtros',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.primary),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Lista / Grid / Empty
                Expanded(
                  child: favs.isEmpty
                      ? _buildEmptyState(totalCount)
                      : _buildGrid(favs),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════════════════════════════
  Widget _buildHeader(int totalCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Icon(Icons.favorite, size: 22, color: Colors.redAccent),
          const SizedBox(width: 8),
          const Text(
            'Favoritos',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          if (totalCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: Colors.redAccent.withValues(alpha: 0.25)),
              ),
              child: Text(
                '$totalCount',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BARRA DE BÚSQUEDA
  // ══════════════════════════════════════════════════════════════
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Buscar en favoritos...',
              hintStyle:
                  const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              prefixIcon:
                  const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear,
                          color: AppTheme.textMuted, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: AppTheme.glassBorder.withValues(alpha: 0.3)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide(color: AppTheme.primary, width: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  FILTROS POR CATEGORÍA
  // ══════════════════════════════════════════════════════════════
  Widget _buildCategoryFilters() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _categoryChip(
            label: 'Todos',
            icon: Icons.grid_view,
            color: AppTheme.textSecondary,
            isSelected: _selectedCategory == null,
            onTap: () => setState(() => _selectedCategory = null),
          ),
          ..._availableCategories.map((cat) {
            final color = AppTheme.getCategoryColor(cat);
            final icon = AppTheme.getCategoryIcon(cat);
            return _categoryChip(
              label: _catLabel(cat),
              icon: icon,
              color: color,
              isSelected: _selectedCategory == cat,
              onTap: () => setState(() {
                _selectedCategory = _selectedCategory == cat ? null : cat;
              }),
            );
          }),
        ],
      ),
    );
  }

  Widget _categoryChip({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.5)
                  : AppTheme.glassBorder,
              width: isSelected ? 1 : 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: isSelected ? color : AppTheme.textMuted),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _catLabel(String cat) {
    const labels = {
      'chest': 'Pecho',
      'back': 'Espalda',
      'shoulders': 'Hombros',
      'upper arms': 'Brazos',
      'lower arms': 'Antebrazo',
      'upper legs': 'Piernas',
      'lower legs': 'Pantorrilla',
      'waist': 'Abdomen',
      'cardio': 'Cardio',
      'neck': 'Cuello',
    };
    return labels[cat] ?? cat[0].toUpperCase() + cat.substring(1);
  }

  // ══════════════════════════════════════════════════════════════
  //  GRID DE FAVORITOS
  // ══════════════════════════════════════════════════════════════
  Widget _buildGrid(List<Exercise> favs) {
    return GridView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.68,
      ),
      itemCount: favs.length,
      itemBuilder: (context, index) {
        final ex = favs[index];
        return _FavoriteCard(
          exercise: ex,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ExerciseDetailScreen(exercise: ex)),
          ),
          onRemove: () => _removeFavorite(ex),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  EMPTY STATE
  // ══════════════════════════════════════════════════════════════
  Widget _buildEmptyState(int totalCount) {
    final hasFilters = _selectedCategory != null || _query.isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent.withValues(alpha: 0.08),
                border:
                    Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
              ),
              child: Icon(
                hasFilters ? Icons.search_off : Icons.favorite_border,
                size: 40,
                color: Colors.redAccent.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilters
                  ? 'Sin resultados'
                  : totalCount == 0
                      ? 'Sin favoritos aún'
                      : 'Nada por aquí',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'Intenta con otros filtros o limpiar la búsqueda'
                  : 'Toca el icono ♥ en cualquier ejercicio para guardarlo aquí',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  TARJETA DE FAVORITO (con dismiss)
// ══════════════════════════════════════════════════════════════
class _FavoriteCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  const _FavoriteCard({
    required this.exercise,
    required this.onTap,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getCategoryColor(exercise.category);
    final imgUrl = exercise.imageUrl;

    return Dismissible(
      key: Key(exercise.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.bgMid,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text(
              '¿Eliminar de favoritos?',
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            content: Text(
              'Se eliminará "${exercise.name}" de tus favoritos.',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar',
                    style: TextStyle(color: AppTheme.textMuted)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Eliminar',
                    style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline,
            color: Colors.redAccent, size: 28),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.bgLight,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 0.8,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Zona de imagen ──
                Expanded(
                  flex: 5,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imgUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imgUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => _imgFallback(color),
                              errorWidget: (_, __, ___) => _imgFallback(color),
                            )
                          : _imgFallback(color),

                      // ── Icono categoría (top-left) ──
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            AppTheme.getCategoryIcon(exercise.category),
                            size: 14,
                            color: color,
                          ),
                        ),
                      ),

                      // ── Heart badge ──
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.favorite,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // ── Degradado sutil abajo ──
                      const Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 30,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, AppTheme.bgLight],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Info ──
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            height: 1.25,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _catLabel(exercise.category),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              AppTheme.getEquipmentIcon(exercise.equipment),
                              size: 11,
                              color: AppTheme.getEquipmentColor(
                                  exercise.equipment),
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                exercise.equipment,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _imgFallback(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.2),
            color.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          AppTheme.getCategoryIcon(exercise.category),
          size: 36,
          color: color.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  String _catLabel(String cat) {
    const labels = {
      'chest': 'Pecho',
      'back': 'Espalda',
      'shoulders': 'Hombros',
      'upper arms': 'Brazos',
      'lower arms': 'Antebrazo',
      'upper legs': 'Piernas',
      'lower legs': 'Pantorrilla',
      'waist': 'Abdomen',
      'cardio': 'Cardio',
      'neck': 'Cuello',
    };
    return labels[cat] ?? cat[0].toUpperCase() + cat.substring(1);
  }
}
