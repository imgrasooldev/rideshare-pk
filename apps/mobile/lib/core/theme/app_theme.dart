import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens for the whole platform. One source of truth: screens never
/// hard-code colors, radii, or text styles — they read the theme.
abstract final class AppTheme {
  /// Emerald — trustworthy, fresh, unmistakably Pakistan.
  static const seed = Color(0xFF00875A);

  static const radiusCard = 20.0;
  static const radiusField = 14.0;

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final isLight = brightness == Brightness.light;
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: isLight ? const Color(0xFFF4F7F5) : const Color(0xFF101413),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isLight ? Colors.white : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? Colors.white : scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusField),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // Tall, but never intrinsically infinite-wide (that breaks Rows and
          // ListTile trailings); parents opt into full width explicitly.
          minimumSize: const Size(64, 52),
          shape: const StadiumBorder(),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        labelStyle: text.labelMedium,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isLight ? Colors.white : scheme.surfaceContainerHigh,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: const StadiumBorder(),
      ),
    );
  }
}
