import 'package:flutter/material.dart';

/// Neutral theme used on the role selection screen.
ThemeData neutralTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5)),
  scaffoldBackgroundColor: const Color(0xFFF6F7FB),
);

/// Holds the active theme. Changing it re-themes the whole app, including
/// every screen pushed afterwards (customer = indigo, delivery = teal).
final ValueNotifier<ThemeData> appTheme = ValueNotifier<ThemeData>(neutralTheme());
