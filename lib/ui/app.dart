import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../data/game_store.dart';
import 'components.dart';
import 'home_screen.dart';
export 'game_screen.dart';

class OrnithoApp extends StatelessWidget {
  final GameStore store;
  const OrnithoApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Petit ornitho',
    locale: const Locale('fr', 'CH'),
    supportedLocales: const [Locale('fr', 'CH')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xffc7e0e6)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xffc7e0e6), space: 24),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: green,
        linearTrackColor: const Color(0xffd6e9ec),
        borderRadius: BorderRadius.circular(8),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: green,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(
            fontFamily: 'Avenir',
            fontFamilyFallback: ['Avenir Next', 'Roboto', 'Arial'],
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: Color(0xff8bb7c1)),
          textStyle: const TextStyle(
            fontFamily: 'Avenir',
            fontFamilyFallback: ['Avenir Next', 'Roboto', 'Arial'],
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ink,
        contentTextStyle: const TextStyle(color: Colors.white, height: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(
            color: Color(0xfffff9e5),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? const Color(0xff145b72)
                : const Color(0xffffd56b),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xff145b72),
        foregroundColor: Color(0xfffff9e5),
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        fillColor: const Color(0xfffff8e7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xff8bb7c1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: green, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
      ),
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.fromSeed(seedColor: green, surface: cream),
      // System fallback keeps accents and glyphs available on every platform.
      fontFamily: 'Avenir',
      fontFamilyFallback: const ['Avenir Next', 'Roboto', 'Arial'],
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 21,
          fontWeight: FontWeight.w800,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 17, color: ink, height: 1.4),
        bodyMedium: TextStyle(fontSize: 15, color: ink, height: 1.45),
        bodySmall: TextStyle(fontSize: 13, color: muted, height: 1.4),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 1,
          shadowColor: const Color(0xff173326),
          side: const BorderSide(color: Color(0xff45b9bf), width: 1.5),
          backgroundColor: green,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          textStyle: const TextStyle(
            fontFamily: 'Avenir',
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    ),
    home: Home(store: store),
  );
}
