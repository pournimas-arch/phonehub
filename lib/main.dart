import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:phonehub/app_theme_notifier.dart';
import 'package:phonehub/firebase_options.dart';
import 'package:phonehub/role_select_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PhoneHubApp());
}

class PhoneHubApp extends StatelessWidget {
  const PhoneHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds when a role screen changes appTheme (Customer / Delivery / Admin).
    return ValueListenableBuilder<ThemeData>(
      valueListenable: appTheme,
      builder: (context, theme, _) {
        return MaterialApp(
          title: 'PhoneHub',
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: const RoleSelectScreen(),
        );
      },
    );
  }
}