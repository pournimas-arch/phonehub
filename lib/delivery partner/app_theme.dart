import 'package:flutter/material.dart';
import 'package:phonehub/app_text.dart';

class AppColors {
  static const primary = Color(0xFF0F766E);
  static const primaryDark = Color(0xFF134E4A);
  static const accent = Color(0xFFF59E0B);
  static const bg = Color(0xFFF4F7F6);
  static const text = Color(0xFF12201F);
  static const muted = Color(0xFF7A8B89);
  static const success = Color(0xFF16A34A);
  static const danger = Color(0xFFEF4444);
  static const info = Color(0xFF2563EB);
  static const border = Color(0xFFE2E8E6);
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, primary: AppColors.primary),
    scaffoldBackgroundColor: AppColors.bg,
    textTheme: buildAppTextTheme(AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      foregroundColor: AppColors.text,
      titleTextStyle: TextStyle(color: AppColors.text, fontSize: AppText.title, fontWeight: FontWeight.w700),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(54),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size.fromHeight(54),
        side: const BorderSide(color: AppColors.primary, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: AppText.subtitle, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

BoxDecoration cardDeco({double radius = 20, Color color = Colors.white}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(color: const Color(0xFF12201F).withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6)),
    ],
  );
}