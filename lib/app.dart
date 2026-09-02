import 'package:flutter/material.dart';

import 'screens/session_gate.dart';
import 'theme/app_colors.dart';
import 'theme/theme_controller.dart';

class Meet6App extends StatelessWidget {
  const Meet6App({super.key});

  ThemeData _lightTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.light,
      surface: AppColors.background,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: scheme.copyWith(
        primary: AppColors.blue,
        secondary: AppColors.lime,
        surface: AppColors.background,
        onSurface: AppColors.navy,
        onSurfaceVariant: AppColors.muted,
        outlineVariant: AppColors.border,
      ),
      fontFamily: 'Arial',
      dividerColor: AppColors.border,
      cardColor: Colors.white,
    );
  }

  ThemeData _darkTheme() {
    const background = Color(0xFF0D1020);
    const surface = Color(0xFF171B2D);
    const surfaceHigh = Color(0xFF20253A);
    const text = Color(0xFFF5F7FF);
    const muted = Color(0xFFA7AEC4);
    const border = Color(0xFF30364E);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.dark,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: scheme.copyWith(
        primary: const Color(0xFF6F8DFF),
        secondary: AppColors.lime,
        surface: surface,
        surfaceContainerHigh: surfaceHigh,
        onSurface: text,
        onSurfaceVariant: muted,
        outlineVariant: border,
      ),
      fontFamily: 'Arial',
      dividerColor: border,
      cardColor: surface,
      dialogBackgroundColor: surface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Meet6',
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          themeMode: mode,
          themeAnimationDuration: const Duration(milliseconds: 220),
          home: const SessionGate(),
        );
      },
    );
  }
}
