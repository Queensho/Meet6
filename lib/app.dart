import 'package:flutter/material.dart';

import 'screens/session_gate.dart';
import 'theme/app_colors.dart';
import 'theme/theme_controller.dart';

class Meet6App extends StatelessWidget {
  const Meet6App({super.key});

  ThemeData _lightTheme() {
    const background = Color(0xFFF8F9FD);
    const surface = Colors.white;
    const surfaceHigh = Color(0xFFF1F3FA);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.light,
      surface: surface,
    ).copyWith(
      primary: AppColors.blue,
      secondary: AppColors.lime,
      surface: surface,
      surfaceContainerHigh: surfaceHigh,
      onSurface: AppColors.navy,
      onSurfaceVariant: AppColors.muted,
      outlineVariant: AppColors.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      fontFamily: 'Arial',
      dividerColor: AppColors.border,
      cardColor: surface,
      dialogBackgroundColor: surface,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(
          color: Color(0xFFA8ADC1),
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.blue, width: 1.5),
        ),
      ),
    );
  }

  ThemeData _darkTheme() {
    const background = Color(0xFF071022);
    const surface = Color(0xFF111C3B);
    const surfaceHigh = Color(0xFF19264B);
    const text = Color(0xFFF7F9FF);
    const muted = Color(0xFFB7C0DB);
    const border = Color(0xFF2B3A65);
    const primary = Color(0xFF7894FF);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.dark,
      surface: surface,
    ).copyWith(
      primary: primary,
      secondary: AppColors.lime,
      surface: surface,
      surfaceContainerHigh: surfaceHigh,
      onSurface: text,
      onSurfaceVariant: muted,
      outlineVariant: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      fontFamily: 'Arial',
      dividerColor: border,
      cardColor: surface,
      dialogBackgroundColor: surface,
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        hintStyle: const TextStyle(
          color: muted,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        prefixIconColor: muted,
        suffixIconColor: muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 1.5),
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
