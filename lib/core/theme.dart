import 'package:flutter/material.dart';

class AppTheme {
  static const seed = Color(0xFF1E6F5C); // أخضر زمردي هادئ

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: b);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    );
  }

  /// ألوان مختارة للملاحظات والتصنيفات والمواعيد.
  static const palette = <Color>[
    Color(0xFF1E6F5C),
    Color(0xFF2E86DE),
    Color(0xFF8E44AD),
    Color(0xFFE67E22),
    Color(0xFFC0392B),
    Color(0xFF16A085),
    Color(0xFFD4AC0D),
    Color(0xFF7F8C8D),
  ];

  static const priorityColors = <Color>[
    Color(0xFF7F8C8D), // منخفضة
    Color(0xFFE67E22), // متوسطة
    Color(0xFFC0392B), // عالية
  ];
}
