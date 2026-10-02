import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

const Color brandSeed = Color(0xFF00C6A5);

const Color _darkSurface = Color(0xFF0E1417);
const Color _darkSurfaceHighest = Color(0xFF1A2429);
const Color _darkScaffold = Color(0xFF0A1012);
const Color _darkCard = Color(0xFF141C20);
const Color _darkBorder = Color(0xFF22303a);

const Color _lightSurface = Color(0xFFF4FBF8);
const Color _lightSurfaceHighest = Color(0xFFDCE9E4);
const Color _lightScaffold = Color(0xFFFAFDFC);
const Color _lightCard = Color(0xFFFFFFFF);
const Color _lightBorder = Color(0xFFC3D6CF);

ThemeData buildAppTheme({
  required Brightness brightness,
  ColorScheme? dynamicScheme,
}) {
  final isDark = brightness == Brightness.dark;

  final ColorScheme scheme;
  if (dynamicScheme != null) {
    scheme = dynamicScheme.harmonized().copyWith(brightness: brightness);
  } else {
    scheme = ColorScheme.fromSeed(
      seedColor: brandSeed,
      brightness: brightness,
      surface: isDark ? _darkSurface : _lightSurface,
      surfaceContainerHighest: isDark
          ? _darkSurfaceHighest
          : _lightSurfaceHighest,
    );
  }

  final scaffold = dynamicScheme != null
      ? scheme.surface
      : (isDark ? _darkScaffold : _lightScaffold);
  final card = dynamicScheme != null
      ? scheme.surfaceContainerHigh
      : (isDark ? _darkCard : _lightCard);
  final border = dynamicScheme != null
      ? scheme.outlineVariant
      : (isDark ? _darkBorder : _lightBorder);

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scaffold,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? scheme.primary : card,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}
