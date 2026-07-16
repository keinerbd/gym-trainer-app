import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';

class FavoritesService {
  static final FavoritesService _instance = FavoritesService._();
  factory FavoritesService() => _instance;
  FavoritesService._();

  static const _key = 'favorite_exercise_ids';
  final _supabase = SupabaseService();
  Set<String> _favorites = {};
  bool _loaded = false;

  Set<String> get favorites => Set.unmodifiable(_favorites);
  bool get isLoaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    if (_supabase.isInitialized && _supabase.isLoggedIn) {
      try {
        final ids = await _supabase.getFavorites();
        _favorites = ids.toSet();
        _loaded = true;
        return;
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    _favorites = (prefs.getStringList(_key) ?? []).toSet();
    _loaded = true;
  }

  bool isFavorite(String id) => _favorites.contains(id);

  Future<void> toggle(String id) async {
    final wasFav = _favorites.contains(id);
    if (wasFav) { _favorites.remove(id); } else { _favorites.add(id); }
    if (_supabase.isInitialized && _supabase.isLoggedIn) {
      try { await _supabase.toggleFavorite(id, wasFav); } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _favorites.toList());
  }

  Future<void> remove(String id) async {
    _favorites.remove(id);
    if (_supabase.isInitialized && _supabase.isLoggedIn) {
      try { await _supabase.toggleFavorite(id, true); } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _favorites.toList());
  }
}
