import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// ألوان نظام iOS الرسمية.
class IosColors {
  static const blue = Color(0xFF007AFF);
  static const green = Color(0xFF34C759);
  static const indigo = Color(0xFF5856D6);
  static const orange = Color(0xFFFF9500);
  static const pink = Color(0xFFFF2D55);
  static const purple = Color(0xFFAF52DE);
  static const red = Color(0xFFFF3B30);
  static const teal = Color(0xFF30B0C7);
  static const yellow = Color(0xFFFFCC00);
  static const mint = Color(0xFF00C7BE);
  static const cyan = Color(0xFF32ADE6);
  static const brown = Color(0xFFA2845E);
  static const gray = Color(0xFF8E8E93);
}

/// ألوان الخلفيات والنصوص حسب الوضع (فاتح/داكن) كما في iOS.
class Ios {
  static bool _dark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  /// خلفية الشاشات المجمّعة (systemGroupedBackground)
  static Color bg(BuildContext c) =>
      _dark(c) ? const Color(0xFF000000) : const Color(0xFFF2F2F7);

  /// خلفية الخلايا (secondarySystemGroupedBackground)
  static Color cell(BuildContext c) =>
      _dark(c) ? const Color(0xFF1C1C1E) : Colors.white;

  /// خلفية عنصر داخل خلية (tertiary)
  static Color fill(BuildContext c) =>
      _dark(c) ? const Color(0xFF2C2C2E) : const Color(0xFFEFEFF4);

  static Color label(BuildContext c) => _dark(c) ? Colors.white : Colors.black;

  static Color secondary(BuildContext c) =>
      _dark(c) ? const Color(0x99EBEBF5) : const Color(0x993C3C43);

  static Color tertiary(BuildContext c) =>
      _dark(c) ? const Color(0x4DEBEBF5) : const Color(0x4D3C3C43);

  static Color separator(BuildContext c) =>
      _dark(c) ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);

  static Color tint(BuildContext c) => Theme.of(c).colorScheme.primary;
}

class AppTheme {
  static const tint = IosColors.blue;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  /// على iOS نترك خط النظام (SF Pro / SF Arabic).
  /// على أندرويد نستخدم Inter للأرقام واللاتيني و IBM Plex Sans Arabic للعربي.
  static bool get _useBundledFont =>
      defaultTargetPlatform != TargetPlatform.iOS;

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? const Color(0xFF000000) : const Color(0xFFF2F2F7);
    final cell = dark ? const Color(0xFF1C1C1E) : Colors.white;
    final label = dark ? Colors.white : Colors.black;
    final secondary = dark ? const Color(0x99EBEBF5) : const Color(0x993C3C43);
    final separator = dark ? const Color(0xFF38383A) : const Color(0xFFC6C6C8);
    final tintColor = dark ? const Color(0xFF0A84FF) : tint;

    final scheme = ColorScheme.fromSeed(seedColor: tint, brightness: b)
        .copyWith(
          primary: tintColor,
          onPrimary: Colors.white,
          surface: cell,
          onSurface: label,
          surfaceContainerLowest: cell,
          surfaceContainerLow: cell,
          surfaceContainer: cell,
          surfaceContainerHigh: dark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFEFEFF4),
          surfaceContainerHighest: dark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFE5E5EA),
          outline: secondary,
          outlineVariant: separator,
          error: dark ? const Color(0xFFFF453A) : IosColors.red,
        );

    final fontFamily = _useBundledFont ? 'Inter' : null;
    final fallback = _useBundledFont ? const ['IBMPlexSansArabic'] : null;

    var base = ThemeData(
      useMaterial3: true,
      brightness: b,
      platform: TargetPlatform
          .iOS, // سلوك iOS: الانتقالات، السحب للرجوع، الارتداد عند التمرير
      colorScheme: scheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fallback,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      splashFactory: NoSplash.splashFactory,
      highlightColor: dark ? const Color(0x22FFFFFF) : const Color(0x14000000),
      dividerTheme: DividerThemeData(
        color: separator,
        thickness: 0.5,
        space: 0.5,
      ),
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: tintColor,
        brightness: b,
        textTheme: _cupertinoText(fontFamily, fallback, label, tintColor),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: tintColor,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: tintColor),
        actionsIconTheme: IconThemeData(color: tintColor, size: 24),
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fallback,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: label,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: cell,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        iconColor: tintColor,
        subtitleTextStyle: TextStyle(color: secondary, fontSize: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cell,
        hintStyle: TextStyle(
          color: dark ? const Color(0x4DEBEBF5) : const Color(0x4D3C3C43),
        ),
        labelStyle: TextStyle(color: secondary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cell,
        selectedColor: tintColor,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        showCheckmark: false,
        labelStyle: TextStyle(color: label, fontSize: 14),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 14),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tintColor,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fallback,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tintColor,
          textStyle: TextStyle(
            fontFamily: fontFamily,
            fontFamilyFallback: fallback,
            fontSize: 17,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tintColor,
        linearTrackColor: dark
            ? const Color(0xFF38383A)
            : const Color(0xFFE5E5EA),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: cell,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark
            ? const Color(0xFF2C2C2E)
            : const Color(0xF2323232),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // أحجام النصوص على طريقة iOS (Body 17)
    base = base.copyWith(
      textTheme: base.textTheme.copyWith(
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 17,
          color: label,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 15,
          color: label,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 17,
          color: label,
        ),
      ),
    );
    return base;
  }

  /// خطوط عناصر Cupertino (شريط التبويب، الأزرار، العجلات) بنفس خط التطبيق.
  static CupertinoTextThemeData? _cupertinoText(
    String? family,
    List<String>? fallback,
    Color label,
    Color tint,
  ) {
    if (family == null) return null; // iOS: خط النظام SF
    TextStyle st(double size, Color color, [FontWeight w = FontWeight.w400]) =>
        TextStyle(
          fontFamily: family,
          fontFamilyFallback: fallback,
          fontSize: size,
          color: color,
          fontWeight: w,
          letterSpacing: -0.2,
        );
    return CupertinoTextThemeData(
      primaryColor: tint,
      textStyle: st(17, label),
      actionTextStyle: st(17, tint),
      actionSmallTextStyle: st(15, tint),
      tabLabelTextStyle: st(10, IosColors.gray, FontWeight.w500),
      navTitleTextStyle: st(17, label, FontWeight.w600),
      navLargeTitleTextStyle: st(34, label, FontWeight.w700),
      navActionTextStyle: st(17, tint),
      pickerTextStyle: st(21, label),
      dateTimePickerTextStyle: st(21, label),
    );
  }

  /// ألوان مختارة (ألوان نظام iOS).
  static const palette = <Color>[
    IosColors.blue,
    IosColors.green,
    IosColors.orange,
    IosColors.red,
    IosColors.purple,
    IosColors.pink,
    IosColors.teal,
    IosColors.yellow,
    IosColors.indigo,
    IosColors.gray,
  ];

  static const priorityColors = <Color>[
    IosColors.gray, // منخفضة
    IosColors.orange, // متوسطة
    IosColors.red, // عالية
  ];
}
