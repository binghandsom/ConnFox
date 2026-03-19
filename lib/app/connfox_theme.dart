import 'package:flutter/material.dart';

class ConnFoxPalette {
  static const Color shell = Color(0xFFF2ECE3);
  static const Color panel = Color(0xFFFFFBF4);
  static const Color panelMuted = Color(0xFFF6F0E5);
  static const Color border = Color(0xFFD8D0C2);
  static const Color ink = Color(0xFF1F2933);
  static const Color mutedText = Color(0xFF5F6C7A);
  static const Color accent = Color(0xFF0F766E);
  static const Color accentSoft = Color(0xFFDDF2EE);
  static const Color warning = Color(0xFFB45309);
  static const Color danger = Color(0xFFB42318);
  static const Color editorSurface = Color(0xFF182430);
  static const Color editorText = Color(0xFFEAF2F7);
}

ThemeData buildConnFoxTheme() {
  const scheme = ColorScheme(
    brightness: Brightness.light,
    primary: ConnFoxPalette.accent,
    onPrimary: Colors.white,
    secondary: ConnFoxPalette.warning,
    onSecondary: Colors.white,
    error: ConnFoxPalette.danger,
    onError: Colors.white,
    surface: ConnFoxPalette.panel,
    onSurface: ConnFoxPalette.ink,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: ConnFoxPalette.shell,
    dividerColor: ConnFoxPalette.border,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: ConnFoxPalette.ink,
      displayColor: ConnFoxPalette.ink,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ConnFoxPalette.accent,
        foregroundColor: Colors.white,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ConnFoxPalette.ink,
        side: const BorderSide(color: ConnFoxPalette.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: ConnFoxPalette.mutedText),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ConnFoxPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: ConnFoxPalette.accent, width: 1.4),
      ),
    ),
  );
}
