import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NestColors {
  const NestColors._();

  static const Color dustyRose = Color(0xFFDCAE96);
  static const Color creamyWhite = Color(0xFFF9F7F2);
  static const Color deepWood = Color(0xFF5A4637);
  static const Color mutedSage = Color(0xFF8A9A84);
  static const Color clay = Color(0xFFB48268);
  static const Color roseMist = Color(0xFFF4E4DB);
}

class NestTheme {
  const NestTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: NestColors.dustyRose,
            brightness: Brightness.light,
            surface: Colors.white,
          ).copyWith(
            primary: NestColors.dustyRose,
            secondary: NestColors.mutedSage,
            tertiary: NestColors.clay,
          ),
    );

    final textTheme = GoogleFonts.notoSansKrTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.gowunBatang(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        color: NestColors.deepWood,
      ),
      displayMedium: GoogleFonts.gowunBatang(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: NestColors.deepWood,
      ),
      headlineMedium: GoogleFonts.gowunBatang(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: NestColors.deepWood,
      ),
      titleLarge: GoogleFonts.gowunBatang(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: NestColors.deepWood,
      ),
      bodyLarge: GoogleFonts.notoSansKr(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: NestColors.deepWood,
      ),
      bodyMedium: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: NestColors.deepWood,
      ),
      labelLarge: GoogleFonts.notoSansKr(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: NestColors.creamyWhite,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: NestColors.deepWood,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: NestColors.roseMist.withValues(alpha: 0.8)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: NestColors.deepWood.withValues(alpha: 0.55),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: NestColors.roseMist.withValues(alpha: 0.9),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: NestColors.roseMist.withValues(alpha: 0.9),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: NestColors.clay, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          backgroundColor: NestColors.dustyRose,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: NestColors.roseMist,
        side: BorderSide.none,
        selectedColor: NestColors.mutedSage.withValues(alpha: 0.18),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NestColors.dustyRose,
        linearTrackColor: NestColors.roseMist,
        circularTrackColor: Color(0x33DCAE96),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
