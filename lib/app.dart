import 'package:flutter/material.dart';

import 'screens/login_screen.dart';
import 'theme/app_colors.dart';

class Meet6App extends StatelessWidget {
  const Meet6App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meet6',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.blue),
        fontFamily: 'Arial',
      ),
      home: const LoginScreen(),
    );
  }
}
