import 'package:flutter/material.dart';

import 'router.dart';

class LedControllerApp extends StatelessWidget {
  const LedControllerApp({super.key});

  static const String _title = 'LED Controller';

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFCB7A36),
      onPrimary: Colors.white,
      secondary: Color(0xFF8BA8A1),
      onSecondary: Colors.white,
      error: Color(0xFFB45E52),
      onError: Colors.white,
      background: Color(0xFFF6F1EA),
      onBackground: Color(0xFF2D241E),
      surface: Colors.white,
      onSurface: Color(0xFF2D241E),
      tertiary: Color(0xFFE1B85B),
      onTertiary: Color(0xFF2D241E),
      surfaceVariant: Color(0xFFF1E6D8),
      onSurfaceVariant: Color(0xFF5F544B),
      outline: Color(0xFFD9C8B5),
      outlineVariant: Color(0xFFEADFD2),
      shadow: Color(0x14000000),
      scrim: Color(0x52000000),
      inverseSurface: Color(0xFF332A25),
      onInverseSurface: Color(0xFFF6F1EA),
      inversePrimary: Color(0xFFF0B37A),
    );

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.background,
        foregroundColor: colorScheme.onBackground,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.onBackground,
        contentTextStyle: TextStyle(color: colorScheme.background),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

    return MaterialApp(
      title: _title,
      theme: theme,
      initialRoute: '/',
      onGenerateRoute: buildLedRoute,
    );
  }
}
