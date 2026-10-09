import 'package:flutter/material.dart';

/// Palette sobre de l'application + couleurs associees aux statuts de vol.
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF1E3A5F);
  static const Color primaryDark = Color(0xFF152A45);
  static const Color accent = Color(0xFF2E7D9A);
  static const Color background = Color(0xFFF5F6F8);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1C2633);
  static const Color textSecondary = Color(0xFF5B6B7B);
  static const Color danger = Color(0xFFC62828);

  /// Couleurs officielles par statut de vol.
  static const Map<String, Color> statusColors = {
    'scheduled': Color(0xFF546E7A), // gris/bleu
    'checkin_open': Color(0xFF00897B), // sarcelle
    'delayed': Color(0xFFEF6C00), // orange
    'rescheduled': Color(0xFF3949AB), // indigo
    'postponed': Color(0xFFF9A825), // ambre
    'cancelled': Color(0xFFC62828), // rouge
    'boarding': Color(0xFF1565C0), // bleu
    'departed': Color(0xFF6A1B9A), // violet
    'arrived': Color(0xFF2E7D32), // vert
  };

  static Color statusColor(String? status) {
    if (status == null) return const Color(0xFF546E7A);
    return statusColors[status] ?? const Color(0xFF546E7A);
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12),
        ),
      ),
      dividerTheme: const DividerThemeData(space: 1, thickness: 1),
    );
  }
}
