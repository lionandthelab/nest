import 'package:flutter/material.dart';

class NestColors {
  const NestColors._();

  // ── 화사하고 산뜻한 파스텔 컬러 시스템 ──
  // 메인 주조색: 따뜻하고 화사한 파스텔 코랄 로즈 (기존 0xFFDCAE96 대비 생동감 강화)
  static const Color dustyRose = Color(0xFFF79D8E);
  // 배경색: 맑고 부드러운 밀키 크림 화이트 (기존 0xFFF9F7F2 대비 맑고 화사한 바탕)
  static const Color creamyWhite = Color(0xFFFDFBF7);
  // 본문 텍스트: 리치 코코아 에스프레소 (기존 0xFF5A4637 대비 높은 가독성과 소프트한 대비)
  static const Color deepWood = Color(0xFF42342B);
  // 보조 활력색: 산뜻한 파스텔 민트 세이지 (기존 0xFF8A9A84 대비 싱그러운 파스텔)
  static const Color mutedSage = Color(0xFF90D5AF);
  // 3차 악센트: 부드럽고 따뜻한 파스텔 카라멜 앰버 (기존 0xFFB48268 대비 밝은 톤)
  static const Color clay = Color(0xFFD49A6A);
  // 면 하이라이트: 은은하고 맑은 페탈 블러시 핑크 (기존 0xFFF4E4DB 대비 화사한 카드/칩 배경)
  static const Color roseMist = Color(0xFFFFF0EB);

  // 추가 파스텔 디자인 악센트 (태그, 시간표, 뱃지용)
  static const Color pastelSky = Color(0xFFB8E0F9);
  static const Color pastelLavender = Color(0xFFE4D7F5);
  static const Color pastelButter = Color(0xFFFFF1C2);
}

class NestTheme {
  const NestTheme._();

  // 슬라이드 안내물과 동일한 폰트 시스템(번들 에셋).
  static const _display = 'BlackHanSans'; // 큰 제목/헤더 (임팩트)
  static const _ui = 'DoHyeon'; // 소제목·버튼·라벨 (깔끔한 강조)
  static const _body = 'Jua'; // 본문·친근한 텍스트

  static TextStyle _font(
    String family, {
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w400,
    Color color = NestColors.deepWood,
  }) => TextStyle(
    fontFamily: family,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: _body,
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

    final textTheme = base.textTheme.copyWith(
      // 큰 제목/헤더 → Black Han Sans
      displayLarge: _font(_display, fontSize: 42),
      displayMedium: _font(_display, fontSize: 34),
      displaySmall: _font(_display, fontSize: 28),
      headlineMedium: _font(_display, fontSize: 24),
      titleLarge: _font(_display, fontSize: 22),
      // 소제목·라벨 → Do Hyeon
      titleMedium: _font(_ui, fontSize: 17),
      titleSmall: _font(_ui, fontSize: 15),
      labelLarge: _font(_ui, fontSize: 15, color: Colors.white),
      // 본문 → Jua
      bodyLarge: _font(_body, fontSize: 17),
      bodyMedium: _font(_body, fontSize: 15),
      bodySmall: _font(_body, fontSize: 13),
    );

    return base.copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: NestColors.roseMist.withValues(alpha: 0.18),
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
        color: Colors.white.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        shadowColor: NestColors.dustyRose.withValues(alpha: 0.14),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: NestColors.roseMist.withValues(alpha: 0.9),
            width: 1.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        helperMaxLines: 3,
        errorMaxLines: 2,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: NestColors.deepWood.withValues(alpha: 0.45),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: NestColors.roseMist.withValues(alpha: 0.95),
            width: 1.2,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: NestColors.roseMist.withValues(alpha: 0.95),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: NestColors.dustyRose, width: 2.0),
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
      // Non-const map + bare constructor calls: newer Flutter stable (>3.41)
      // made some PageTransitionsBuilder constructors non-const, which broke the
      // previous const map literal. Bare calls compile whether or not the
      // constructors are const (at worst a non-fatal prefer_const info).
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {
          TargetPlatform.android: NestPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: NestPageTransitionsBuilder(),
          TargetPlatform.linux: NestPageTransitionsBuilder(),
          TargetPlatform.fuchsia: NestPageTransitionsBuilder(),
        },
      ),
      // Ensure minimum 48px touch targets for accessibility.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

/// 안드로이드 기본 줌 대신 짧은 페이드+상승. iOS는 시스템 스와이프 백을 유지한다.
class NestPageTransitionsBuilder extends PageTransitionsBuilder {
  const NestPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final curve = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.16, 1, 0.3, 1),
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(curve),
        child: child,
      ),
    );
  }
}
