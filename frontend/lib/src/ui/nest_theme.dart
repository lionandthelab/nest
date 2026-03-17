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
        fontSize: 17,
        fontWeight: FontWeight.w500,
        color: NestColors.deepWood,
      ),
      bodyMedium: GoogleFonts.notoSansKr(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: NestColors.deepWood,
      ),
      labelLarge: GoogleFonts.notoSansKr(
        fontSize: 15,
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
      dividerTheme: DividerThemeData(
        color: NestColors.roseMist.withValues(alpha: 0.8),
        thickness: 1,
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
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: NestColors.deepWood,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: NestColors.deepWood,
          side: BorderSide(color: NestColors.roseMist.withValues(alpha: 0.95)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.bodyMedium),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: NestColors.roseMist.withValues(alpha: 0.95)),
          ),
          foregroundColor: const WidgetStatePropertyAll(NestColors.deepWood),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return NestColors.roseMist;
            }
            return Colors.white;
          }),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.94),
        indicatorColor: NestColors.roseMist,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.bodySmall?.copyWith(
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: NestColors.deepWood.withValues(alpha: selected ? 1 : 0.7),
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white.withValues(alpha: 0.74),
        indicatorColor: NestColors.roseMist,
        selectedIconTheme: const IconThemeData(color: NestColors.deepWood),
        unselectedIconTheme: IconThemeData(
          color: NestColors.deepWood.withValues(alpha: 0.62),
        ),
        selectedLabelTextStyle: textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: NestColors.deepWood,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        showDragHandle: true,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: NestColors.dustyRose,
        linearTrackColor: NestColors.roseMist,
        circularTrackColor: Color(0x33DCAE96),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      // Ensure minimum 48px touch targets for accessibility.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titleTextStyle: textTheme.titleLarge,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: NestColors.deepWood,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: Colors.white),
      ),
    );
  }
}
