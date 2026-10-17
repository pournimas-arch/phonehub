import 'package:flutter/material.dart';

class AppText {
  static const double title = 17;      // स्क्रीनचे शीर्षक
  static const double subtitle = 15;   // उप-शीर्षक
  static const double body = 13;       // सामान्य मजकूर
  static const double small = 11;      // छोटा मजकूर
  static const double caption = 10;    // अगदी छोटा

  static const TextStyle titleStyle =
  TextStyle(fontSize: title, fontWeight: FontWeight.w700);
  static const TextStyle subtitleStyle =
  TextStyle(fontSize: subtitle, fontWeight: FontWeight.w600);
  static const TextStyle bodyStyle = TextStyle(fontSize: body);
  static const TextStyle smallStyle = TextStyle(fontSize: small);
  static const TextStyle captionStyle = TextStyle(fontSize: caption);
}

/// तीनही theme (Customer / Admin / Delivery) मध्ये हीच textTheme वापरली जाते.
/// [color] = त्या theme चा मुख्य text रंग.
TextTheme buildAppTextTheme(Color color) {
  return const TextTheme(
    titleLarge: AppText.titleStyle,       // 17
    titleMedium: AppText.subtitleStyle,   // 15
    bodyLarge: AppText.bodyStyle,         // 13
    bodyMedium: AppText.bodyStyle,        // 13  (साधा Text('...') याचा वापर करतो)
    bodySmall: AppText.smallStyle,        // 11
    labelSmall: AppText.captionStyle,     // 10
  ).apply(bodyColor: color, displayColor: color);
}
