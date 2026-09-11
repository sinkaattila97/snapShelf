import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SnapShelf visual language — ink + sea-glass (light) / deep slate (dark).
class AppTheme {
  static const ink = Color(0xFF14212B);
  static const sea = Color(0xFF1F6F78);
  static const seaSoft = Color(0xFFD7EEEF);
  static const sand = Color(0xFFF3EFE6);
  static const mist = Color(0xFFE7EEF2);
  static const coral = Color(0xFFC45C26);

  static const night = Color(0xFF0B1218);
  static const nightCard = Color(0xFF152029);
  static const nightMist = Color(0xFF1C2A36);
  static const moon = Color(0xFFE8EEF2);
  static const seaDark = Color(0xFF3FA4AD);

  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: sea,
      brightness: Brightness.light,
      primary: sea,
      onPrimary: Colors.white,
      secondary: ink,
      surface: sand,
      error: coral,
    );
    return _build(
      scheme: base.copyWith(
        surfaceContainerLowest: Colors.white,
        surfaceContainerLow: const Color(0xFFFAF7F1),
        surfaceContainer: mist,
        surfaceContainerHigh: seaSoft,
      ),
      scaffold: sand,
      inkColor: ink,
      appBarBg: sand.withValues(alpha: 0.92),
      navBg: Colors.white.withValues(alpha: 0.94),
      indicator: seaSoft,
      fieldFill: Colors.white,
      chipSelected: seaSoft,
      dialogBg: Colors.white,
      fabBg: ink,
    );
  }

  static ThemeData dark() {
    final base = ColorScheme.fromSeed(
      seedColor: seaDark,
      brightness: Brightness.dark,
      primary: seaDark,
      onPrimary: night,
      secondary: moon,
      surface: night,
      error: const Color(0xFFFF8A65),
    );
    return _build(
      scheme: base.copyWith(
        surfaceContainerLowest: nightCard,
        surfaceContainerLow: nightCard,
        surfaceContainer: nightMist,
        surfaceContainerHigh: const Color(0xFF243442),
        onSurface: moon,
        onSurfaceVariant: moon.withValues(alpha: 0.7),
      ),
      scaffold: night,
      inkColor: moon,
      appBarBg: night.withValues(alpha: 0.92),
      navBg: nightCard.withValues(alpha: 0.96),
      indicator: const Color(0xFF244850),
      fieldFill: nightCard,
      chipSelected: const Color(0xFF244850),
      dialogBg: nightCard,
      fabBg: seaDark,
    );
  }

  static ThemeData _build({
    required ColorScheme scheme,
    required Color scaffold,
    required Color inkColor,
    required Color appBarBg,
    required Color navBg,
    required Color indicator,
    required Color fieldFill,
    required Color chipSelected,
    required Color dialogBg,
    required Color fabBg,
  }) {
    final text = GoogleFonts.dmSansTextTheme(scheme.brightness == Brightness.dark
            ? ThemeData.dark().textTheme
            : ThemeData.light().textTheme)
        .apply(bodyColor: inkColor, displayColor: inkColor);
    final display = GoogleFonts.frauncesTextTheme(text);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      textTheme: text.copyWith(
        displaySmall: display.displaySmall?.copyWith(fontWeight: FontWeight.w600),
        headlineMedium:
            display.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: appBarBg,
        foregroundColor: inkColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: display.titleLarge?.copyWith(
          color: inkColor,
          fontWeight: FontWeight.w600,
          fontSize: 22,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: navBg,
        indicatorColor: indicator,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? scheme.primary
                : inkColor.withValues(alpha: 0.55),
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: fabBg,
        foregroundColor:
            scheme.brightness == Brightness.dark ? night : Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: inkColor.withValues(alpha: 0.12)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: inkColor.withValues(alpha: 0.12)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: BorderSide(color: inkColor.withValues(alpha: 0.12)),
        selectedColor: chipSelected,
        checkmarkColor: scheme.primary,
        labelStyle: GoogleFonts.dmSans(
          fontWeight: FontWeight.w600,
          color: inkColor,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: inkColor,
        contentTextStyle: GoogleFonts.dmSans(
          color: scheme.brightness == Brightness.dark ? night : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dialogBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }
}

class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  Color(0xFF0B1218),
                  Color(0xFF102028),
                  Color(0xFF0E1A22),
                ]
              : const [
                  Color(0xFFF7F3EA),
                  Color(0xFFEAF3F4),
                  Color(0xFFE7EEF2),
                ],
        ),
      ),
      child: child,
    );
  }
}
