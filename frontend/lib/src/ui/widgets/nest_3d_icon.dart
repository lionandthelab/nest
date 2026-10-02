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

  /// 성취 / 포트폴리오
  const Nest3dIcon.achievement({
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

  /// 학습 포트폴리오 바인더 (Blender 3D 렌더링)
  const Nest3dIcon.portfolio({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2300),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/portfolio_binder_3d.png';

  /// 추억 앨범 레트로 카메라 (Blender 3D 렌더링)
  const Nest3dIcon.camera({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2200),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/camera_memory_3d.png';

  /// 공식 승인 리본 메달 (Blender 3D 렌더링)
  const Nest3dIcon.certificate({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2100),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/ribbon_badge_3d.png';

  /// 포근한 새집 / 홈 / 대시보드 (Blender 3D 렌더링)
  const Nest3dIcon.home({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2400),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/home_nest_3d.png';

  /// 커뮤니티 대화 말풍선 쿠션 (Blender 3D 렌더링)
  const Nest3dIcon.community({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2300),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/community_chat_3d.png';

  /// 학기 설정 / 학교 블록 (Blender 3D 렌더링)
  const Nest3dIcon.termSetup({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2400),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/term_setup_3d.png';

  /// 시스템 설정 / 기어 (Blender 3D 렌더링)
  const Nest3dIcon.system({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2200),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/system_gear_3d.png';

  /// Teacher Hub 학사모 & 두루마리 (Blender 3D 렌더링)
  const Nest3dIcon.teacher({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2300),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/teacher_cap_3d.png';

  /// 학생 책가방 (Blender 3D 렌더링)
  const Nest3dIcon.student({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2400),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/student_backpack_3d.png';

  /// 가정 / 패밀리 둥지와 3개의 알 (Blender 3D 렌더링)
  const Nest3dIcon.family({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2500),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/family_nest_3d.png';

  /// 알림 차임벨 (Blender 3D 렌더링)
  const Nest3dIcon.bell({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2100),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/notification_bell_3d.png';

  /// 작성 / 과제 / 피드백 연필 (Blender 3D 렌더링)
  const Nest3dIcon.pencil({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2200),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/pencil_write_3d.png';

  /// 학습 현황 / 성취도 차트 & 별 (Blender 3D 렌더링)
  const Nest3dIcon.chart({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2300),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/insight_chart_3d.png';

  /// 출결 / 완료 체크마크 스탬프 (Blender 3D 렌더링)
  const Nest3dIcon.checkStamp({
    super.key,
    this.size = 44.0,
    this.floating = false,
    this.floatDistance = 4.0,
    this.duration = const Duration(milliseconds: 2200),
    this.fit = BoxFit.contain,
    this.onTap,
  }) : assetPath = 'assets/3d/check_stamp_3d.png';

  /// 탭 라벨명 기반으로 최적화된 3D 클레이 아이콘 위젯을 반환합니다.
  static Widget forTab(
    String label, {
    double size = 26.0,
    bool selected = false,
  }) {
    final Nest3dIcon icon = switch (label) {
      '시작하기' || '홈' || '대시보드' || 'Dashboard' =>
        Nest3dIcon.home(size: size),
      '시간표' || 'Timetable' || 'Schedule' =>
        Nest3dIcon.calendar(size: size),
      '자습' =>
        Nest3dIcon.studyBooks(size: size),
      '학습 현황' =>
        Nest3dIcon.chart(size: size),
      '소식' =>
        Nest3dIcon.announcement(size: size),
      'Teacher Hub' =>
        Nest3dIcon.teacher(size: size),
      '학기 설정' || 'Term Setup' =>
        Nest3dIcon.termSetup(size: size),
      '시스템' || 'System' =>
        Nest3dIcon.system(size: size),
      '커뮤니티' || 'Community' || 'SNS' || 'SNS Admin' =>
        Nest3dIcon.community(size: size),
      'Members' || 'Families' =>
        Nest3dIcon.family(size: size),
      '앨범' || '갤러리' || 'Gallery' =>
        Nest3dIcon.camera(size: size),
      _ => Nest3dIcon.star(size: size),
    };

    if (selected) {
      return icon;
    }
    return Opacity(
      opacity: 0.62,
      child: icon,
    );
  }

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
