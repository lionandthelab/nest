import 'package:flutter/material.dart';

import 'nest_motion.dart';

/// 3D 클레이모픽 에셋 아이콘 위젯.
///
/// 부드러운 앰비언트 부유(Floating) 모션 및 촉각적 터치 반응을 지원합니다.
class Nest3dIcon extends StatelessWidget {
  const Nest3dIcon({
    super.key,
    required this.assetPath,
    this.size = 48.0,
    this.floating = false,
    this.floatDistance = 5.0,
    this.duration = const Duration(milliseconds: 2400),
    this.fit = BoxFit.contain,
    this.onTap,
  });

  /// 공지사항 / 메가폰
  const Nest3dIcon.announcement({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2200),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/announcement_3d.png';

  /// 캘린더 / 시간표 / 학사일정
  const Nest3dIcon.calendar({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2400),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/calendar_3d.png';

  /// 교과서 / 수업 / 진도
  const Nest3dIcon.studyBooks({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2300),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/study_books_3d.png';

  /// 발광 전구 / 홈스쿨 팁
  const Nest3dIcon.lightbulb({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 5.0,
    this.duration = const Duration(milliseconds: 2000),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/tips_lightbulb_3d.png';

  /// 빈 둥지 / 데이터 없음
  const Nest3dIcon.emptyNest({
    super.key,
    this.size = 76.0,
    this.floating = false,
    this.floatDistance = 5.0,
    this.duration = const Duration(milliseconds: 2600),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/empty_nest_3d.png';

  /// 성취 / 황금 별
  const Nest3dIcon.star({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2200),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/achievement_star_3d.png';

  /// 3D 로고 심볼
  const Nest3dIcon.logo({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 5.0,
    this.duration = const Duration(milliseconds: 2500),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/logo_3d_mark.png';

  final String assetPath;
  final double size;
  final bool floating;
  final double floatDistance;
  final Duration duration;
  final BoxFit fit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: fit,
    );

    if (floating) {
      image = Floating3DWidget(
        floatDistance: floatDistance,
        duration: duration,
        child: image,
      );
    }

    if (onTap != null) {
      image = NestPressable(
        onPressed: onTap,
        haptic: true,
        child: image,
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Center(child: image),
    );
  }
}
