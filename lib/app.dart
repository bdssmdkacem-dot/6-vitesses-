import 'package:flutter/material.dart';
import 'features/hud/hud_screen.dart';

class SixVitessesApp extends StatelessWidget {
  const SixVitessesApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '6 Vitesses',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const HudScreen(),
  );
}
