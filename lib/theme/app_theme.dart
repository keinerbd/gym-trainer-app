import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Colors ──────────────────────────────
  static const Color primary = Color(0xFFFF6B35);
  static const Color primaryLight = Color(0xFFFF8C60);
  static const Color accent = Color(0xFF00D2FF);

  // Dark background
  static const Color bgDark = Color(0xFF0A0A14);
  static const Color bgMid = Color(0xFF12121F);
  static const Color bgLight = Color(0xFF1A1A2E);

  // Text
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8892B0);
  static const Color textMuted = Color(0xFF5A6480);

  // Glass
  static const Color glassWhite = Color(0x10FFFFFF);
  static const Color glassBorder = Color(0x20FFFFFF);
  static const Color glassShine = Color(0x35FFFFFF);

  // ── Category Colors ──────────────────────────
  static const Map<String, Color> categoryColors = {
    'chest': Color(0xFFFF6B6B),
    'back': Color(0xFF4ECDC4),
    'shoulders': Color(0xFFFFD93D),
    'upper arms': Color(0xFFA855F7),
    'lower arms': Color(0xFFC084FC),
    'upper legs': Color(0xFF22C55E),
    'lower legs': Color(0xFF4ADE80),
    'waist': Color(0xFFFB923C),
    'cardio': Color(0xFF2DD4BF),
    'neck': Color(0xFF94A3B8),
  };

  static const Map<String, IconData> categoryIcons = {
    'chest': Icons.fitness_center,
    'back': Icons.accessibility_new,
    'shoulders': Icons.sports_handball,
    'upper arms': Icons.sports_kabaddi,
    'lower arms': Icons.front_hand,
    'upper legs': Icons.sports_gymnastics,
    'lower legs': Icons.downhill_skiing,
    'waist': Icons.self_improvement,
    'cardio': Icons.directions_run,
    'neck': Icons.airline_seat_flat,
  };

  static Color getCategoryColor(String cat) =>
      categoryColors[cat.toLowerCase()] ?? primary;

  static IconData getCategoryIcon(String cat) =>
      categoryIcons[cat.toLowerCase()] ?? Icons.fitness_center;

  // ── Equipment Colors ─────────────────────────
  static const Map<String, Color> equipmentColors = {
    'body weight': Color(0xFF4ADE80),
    'dumbbell': Color(0xFF60A5FA),
    'barbell': Color(0xFFF87171),
    'cable': Color(0xFFC084FC),
    'band': Color(0xFFFBBF24),
    'kettlebell': Color(0xFFFB923C),
    'smith machine': Color(0xFF94A3B8),
    'leverage machine': Color(0xFF2DD4BF),
    'stability ball': Color(0xFF38BDF8),
    'ez barbell': Color(0xFFF87171),
    'weighted': Color(0xFFA8A29E),
  };

  static Color getEquipmentColor(String eq) =>
      equipmentColors[eq.toLowerCase()] ?? textSecondary;

  // ── Equipment Icons ──────────────────────────
  static const Map<String, IconData> equipmentIcons = {
    'body weight': Icons.accessibility_new,
    'dumbbell': Icons.sports_gymnastics,
    'barbell': Icons.sports_martial_arts,
    'cable': Icons.vertical_align_center,
    'band': Icons.loop,
    'kettlebell': Icons.sports_kabaddi,
    'smith machine': Icons.settings_input_component,
    'leverage machine': Icons.settings,
    'stability ball': Icons.sports_soccer,
    'ez barbell': Icons.sports_martial_arts,
    'weighted': Icons.add_circle_outline,
  };

  static IconData getEquipmentIcon(String eq) =>
      equipmentIcons[eq.toLowerCase()] ?? Icons.fitness_center;

  // ── Glass helpers ────────────────────────────

  /// A frosted-glass surface decoration.
  static BoxDecoration glassSurface({
    double radius = 20,
    double opacity = 0.08,
    Color? borderColor,
  }) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? glassBorder, width: 0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      );

  /// Builds a glass card with BackdropFilter.
  static Widget glassCard({
    required Widget child,
    double radius = 20,
    double blur = 14,
    double opacity = 0.08,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? borderColor,
    VoidCallback? onTap,
    double? width,
    double? height,
  }) {
    Widget card = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          width: width,
          height: height,
          margin: margin,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: glassSurface(
            radius: radius,
            opacity: opacity,
            borderColor: borderColor,
          ),
          child: child,
        ),
      ),
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: card,
        ),
      );
    }

    return card;
  }

  // ── Theme Data ────────────────────────────────
  static ThemeData get glassTheme {
    final textTheme = GoogleFonts.interTextTheme();

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        surface: bgMid,
        onSurface: textPrimary,
      ),
      textTheme: textTheme.copyWith(
        headlineLarge: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w800, color: textPrimary, letterSpacing: -0.5,
        ),
        headlineMedium: textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700, color: textPrimary,
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700, color: textPrimary,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600, color: textPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(color: textPrimary),
        bodyMedium: textTheme.bodyMedium?.copyWith(color: textSecondary),
        bodySmall: textTheme.bodySmall?.copyWith(color: textMuted),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700, color: textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: glassWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: glassBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIconColor: textSecondary,
        hintStyle: const TextStyle(color: textMuted),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        unselectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
      ),
      dividerColor: glassBorder,
    );
  }
}
