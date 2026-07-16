import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import '../models/exercise.dart';
import '../services/exercise_service.dart';
import '../services/favorites_service.dart';
import '../theme/app_theme.dart';
import '../widgets/exercise_card.dart';
import 'exercise_detail_screen.dart';

class ExerciseListScreen extends StatefulWidget {
  final String? category;
  final String? bodyPart;
  final String? equipment;
  final String? searchQuery;

  const ExerciseListScreen({
    super.key,
    this.category,
    this.bodyPart,
    this.equipment,
    this.searchQuery,
  });

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  final ExerciseService _svc = ExerciseService();
  final FavoritesService _fav = FavoritesService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<Exercise> _exercises = [];
  List<Exercise> _filtered = [];
  String _selCategory = '';
  String _selEquipment = '';
  List<String> _availCategories = [];
  List<String> _availEquipment = [];
  bool _showFilters = false;

  String get _title {
    if (widget.category != null) return widget.category!.toUpperCase();
    if (widget.bodyPart != null) return widget.bodyPart!.toUpperCase();
    if (widget.equipment != null) return widget.equipment!.toUpperCase();
    return 'Exercises';
  }

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = widget.searchQuery ?? '';
    _selCategory = widget.category ?? '';
    _selEquipment = widget.equipment ?? '';
    _reload();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    _exercises = _svc.filter(
      category: _selCategory,
      bodyPart: widget.bodyPart,
      equipment: _selEquipment,
    );
    _filtered = List.from(_exercises);
    _availCategories = _exercises.map((e) => e.category).toSet().toList()..sort();
    _availEquipment = _exercises.map((e) => e.equipment).toSet().toList()..sort();
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_exercises)
          : _exercises
              .where((e) =>
                  e.name.toLowerCase().contains(q) ||
                  e.target.toLowerCase().contains(q) ||
                  e.equipment.toLowerCase().contains(q))
              .toList();
    });
  }

  void _toggleCategory(String cat) {
    setState(() {
      _selCategory = _selCategory == cat ? '' : cat;
      _reload();
      if (_searchCtrl.text.isNotEmpty) _onSearch();
    });
  }

  void _toggleEquipment(String eq) {
    setState(() {
      _selEquipment = _selEquipment == eq ? '' : eq;
      _reload();
      if (_searchCtrl.text.isNotEmpty) _onSearch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catColor = _selCategory.isNotEmpty
        ? AppTheme.getCategoryColor(_selCategory)
        : AppTheme.primary;

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
                // ── Header ─────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          _showFilters ? Icons.filter_list_off : Icons.tune,
                          color: (_selCategory.isNotEmpty || _selEquipment.isNotEmpty)
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                        onPressed: () => setState(() => _showFilters = !_showFilters),
                      ),
                    ],
                  ),
                ),

                // ── Glass search bar ──────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Filter exercises...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => _searchCtrl.clear(),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Filter chips ──────────
                if (_showFilters) ...[
                  _filterRow('Category', _availCategories, _selCategory, _toggleCategory),
                  _filterRow('Equipment', _availEquipment, _selEquipment, _toggleEquipment),
                ],

                // ── Count + active filters ─
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  child: Row(
                    children: [
                      Text(
                        '${_filtered.length} exercises',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (_selCategory.isNotEmpty)
                        _chip(_selCategory, catColor, () => _toggleCategory(_selCategory)),
                      if (_selEquipment.isNotEmpty)
                        _chip(_selEquipment, AppTheme.getEquipmentColor(_selEquipment),
                            () => _toggleEquipment(_selEquipment)),
                    ],
                  ),
                ),

                // ── Grid ──────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fitness_center,
                                  size: 56, color: catColor.withValues(alpha: 0.2)),
                              const SizedBox(height: 12),
                              const Text(
                                'No exercises found',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : AnimationLimiter(
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(6, 4, 6, 20),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.72,
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (context, index) {
                              final ex = _filtered[index];
                              return AnimationConfiguration.staggeredGrid(
                                position: index,
                                duration: const Duration(milliseconds: 300),
                                columnCount: 2,
                                child: ScaleAnimation(
                                  child: FadeInAnimation(
                                    child: ExerciseCard(
                                      exercise: ex,
                                      isFavorite: _fav.isFavorite(ex.id),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ExerciseDetailScreen(exercise: ex),
                                        ),
                                      ),
                                      onFavoriteToggle: () async {
                                        await _fav.toggle(ex.id);
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
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

  Widget _filterRow(
    String title,
    List<String> options,
    String selected,
    Function(String) onSelect,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.2)),
          const SizedBox(height: 5),
          SizedBox(
            height: 30,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: options.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final opt = options[index];
                final isSel = opt == selected;
                return FilterChip(
                  label: Text(opt.toUpperCase(),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSel ? AppTheme.primary : AppTheme.textSecondary)),
                  selected: isSel,
                  onSelected: (_) => onSelect(opt),
                  selectedColor: AppTheme.primary.withValues(alpha: 0.15),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, Color color, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Chip(
        label: Text(label.toUpperCase(),
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white)),
        deleteIcon: const Icon(Icons.close, size: 12, color: Colors.white70),
        onDeleted: onRemove,
        backgroundColor: color.withValues(alpha: 0.5),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
