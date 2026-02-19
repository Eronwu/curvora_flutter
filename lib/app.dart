import 'package:curvora_flutter/screens/curvora_screen.dart';
import 'package:flutter/material.dart';

class CurvoraApp extends StatelessWidget {
  const CurvoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF65D6FF),
      brightness: Brightness.dark,
    );

    return MaterialApp(
      title: 'Curvora Audio Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        cardTheme: CardThemeData(
          color: const Color(0xFF171B24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF262D3A)),
          ),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: Color(0xFF65D6FF),
          inactiveTrackColor: Color(0xFF324154),
          thumbColor: Color(0xFF90E6FF),
        ),
      ),
      home: const CurvoraScreen(),
    );
  }
}
