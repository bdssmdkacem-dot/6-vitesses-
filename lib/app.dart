import 'package:flutter/material.dart';
import 'features/hud/hud_screen.dart';
import 'features/settings/app_settings.dart';

class SixVitessesApp extends StatelessWidget {
  const SixVitessesApp({super.key, required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: settings,
    builder: (_, __) => MaterialApp(
      title: '6 Vitesses',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: HudScreen(settings: settings),
    ),
  );
}
