import 'package:flutter/material.dart';

import '../nest_theme.dart';

/// 시간표 계열 화면이 공유하는 작은 배지들.
///
/// 원래 `tabs/student_home_tab.dart` 안에 있었는데, 학부모 홈까지 같은 표현을 쓰게
/// 되면서 탭이 탭을 import 하는(그리고 순환이 나는) 구조가 됐다. 표현만 담당하고
/// 상태를 모르는 위젯이므로 widgets 로 내렸다.

/// 수업 변경 배지(휴강·시간 변경·장소 변경 등).
class StudentChangeBadge extends StatelessWidget {
  const StudentChangeBadge({
    super.key,
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: NestColors.clay.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w800,
          color: NestColors.clay,
        ),
      ),
    );
  }
}

/// 결석 신고 배지.
class StudentAbsenceBadge extends StatelessWidget {
  const StudentAbsenceBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: NestColors.mutedSage.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '결석',
        style: TextStyle(
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w800,
          color: NestColors.mutedSage,
        ),
      ),
    );
  }
}

/// 결석 신고 상태 칩.
class StudentStatusChip extends StatelessWidget {
  const StudentStatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: NestColors.roseMist.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: NestColors.deepWood,
        ),
      ),
    );
  }
}
