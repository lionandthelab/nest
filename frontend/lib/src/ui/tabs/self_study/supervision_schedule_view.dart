import 'package:flutter/material.dart';

import '../../../models/nest_models.dart';
import '../../../services/self_study_planner.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';
import '../../widgets/nest_empty_state.dart';

/// 감독표 — 한 교사가 감독하는 자습을 요일·시간·장소로 보여준다.
///
/// 같은 요일·같은 방에서 시간이 겹치거나 이어지는 자습(여러 반)은 하나의
/// 카드로 묶는다. 매주 반복이면 '매주', 특정 날짜에만 감독하면 그 날짜를
/// 배지로 함께 표기해, 별도의 '회전 감독' 개념 없이 직관적으로 보이게 한다.
///
/// 관리자 자습 탭에서 교사를 눌렀을 때(전체 화면), 교사 뷰의 "내 감독 시간표"
/// 토글에서(임베드) 모두 재사용한다.
class SupervisionScheduleView extends StatelessWidget {
  const SupervisionScheduleView({
    super.key,
    required this.controller,
    required this.teacherProfileId,
    this.teacherName,
    this.showHeader = true,
  });

  final NestController controller;
  final String teacherProfileId;
  final String? teacherName;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final plan = controller.selectedSelfStudyPlan;
        final slots = controller.selfStudySlotsForSupervisor(teacherProfileId);
        final rotations =
            controller.selfStudySupervisionsForTeacher(teacherProfileId);
        final name =
            teacherName ?? controller.findTeacherName(teacherProfileId);

        if (plan == null) {
          return const NestEmptyState(
            icon: Icons.menu_book_outlined,
            title: '자습 시간표가 아직 없습니다',
          );
        }
        if (slots.isEmpty && rotations.isEmpty) {
          return NestEmptyState(
            icon: Icons.event_busy_outlined,
            title: '배정된 감독이 없습니다',
            subtitle: '$name 교사에게 배정된 자습 감독이 없어요.',
          );
        }

        // 슬롯(매주) + 회전(특정 날짜)을 하나의 카드 목록으로 합친다.
        final cards = <_SupCard>[
          ..._mergeSlotCards(slots),
          ..._rotationCards(rotations),
        ];

        final byDay = <int, List<_SupCard>>{};
        for (final c in cards) {
          byDay.putIfAbsent(c.day, () => []).add(c);
        }
        const order = [1, 2, 3, 4, 5, 6, 0];

        final children = <Widget>[];
        if (showHeader) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 2),
            child: Row(
              children: [
                Icon(Icons.assignment_ind_outlined, color: NestColors.clay),
                const SizedBox(width: 8),
                Text(
                  '$name 감독표',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ));
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 10, left: 2),
            child: Text(
              '${plan.name} · 총 ${cards.length}건',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.7),
                  ),
            ),
          ));
        }

        for (final day in order) {
          final ds = byDay[day];
          if (ds == null || ds.isEmpty) continue;
          ds.sort((a, b) {
            final byStart = a.startMin.compareTo(b.startMin);
            if (byStart != 0) return byStart;
            return a.room.compareTo(b.room);
          });
          children.add(Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6, left: 2),
            child: Text(
              '${weekdayLabel(day)}요일',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ));
          for (final c in ds) {
            children.add(_card(context, c));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  /// 같은 요일·같은 방에서 시간이 겹치거나 이어지는 슬롯(여러 반)을 하나로
  /// 묶는다. 시간은 합쳐진 전체 구간, 인원은 중복 제거한 자습생 수.
  List<_SupCard> _mergeSlotCards(List<SelfStudySlot> slots) {
    final byDayRoom = <String, List<SelfStudySlot>>{};
    for (final s in slots) {
      final room = s.room.trim().isEmpty ? '장소 미정' : s.room.trim();
      byDayRoom.putIfAbsent('${s.dayOfWeek}|$room', () => []).add(s);
    }

    final cards = <_SupCard>[];
    byDayRoom.forEach((_, group) {
      group.sort((a, b) =>
          minutesFromTime(a.startTime).compareTo(minutesFromTime(b.startTime)));
      final day = group.first.dayOfWeek;
      final room =
          group.first.room.trim().isEmpty ? '장소 미정' : group.first.room.trim();

      var start = -1;
      var end = -1;
      final bucket = <SelfStudySlot>[];

      void flush() {
        if (bucket.isEmpty) return;
        final childIds = <String>{};
        for (final s in bucket) {
          for (final child in controller.rosterForSelfStudySlot(s)) {
            childIds.add(child.id);
          }
        }
        cards.add(_SupCard(
          day: day,
          startMin: start,
          endMin: end,
          room: room,
          count: childIds.length,
          dateLabel: '매주',
        ));
        bucket.clear();
      }

      for (final s in group) {
        final st = minutesFromTime(s.startTime);
        final et = minutesFromTime(s.endTime);
        if (bucket.isEmpty) {
          start = st;
          end = et;
        } else if (st <= end) {
          // 겹치거나 바로 이어지는 구간 → 병합.
          if (et > end) end = et;
        } else {
          flush();
          start = st;
          end = et;
        }
        bucket.add(s);
      }
      flush();
    });
    return cards;
  }

  /// 특정 날짜(회전) 감독을 (요일·방·시간대)별로 묶어 카드로 만든다.
  List<_SupCard> _rotationCards(List<SelfStudySupervision> rotations) {
    final byBand = <String, List<SelfStudySupervision>>{};
    for (final r in rotations) {
      byBand
          .putIfAbsent('${r.dayOfWeek}|${r.room}|${r.bandStart}', () => [])
          .add(r);
    }
    final cards = <_SupCard>[];
    byBand.forEach((_, list) {
      final f = list.first;
      final weekly = list.any((r) => r.occurrenceDate == null);
      final dates = list
          .map((r) => r.occurrenceDate)
          .whereType<DateTime>()
          .toList()
        ..sort();
      final dateLabel =
          weekly ? '매주' : dates.map((d) => '${d.month}/${d.day}').join(', ');
      cards.add(_SupCard(
        day: f.dayOfWeek,
        startMin: minutesFromTime(f.bandStart),
        endMin: minutesFromTime(f.bandEnd),
        room: f.room.trim().isEmpty ? '장소 미정' : f.room.trim(),
        count: null,
        dateLabel: dateLabel,
      ));
    });
    return cards;
  }

  Widget _card(BuildContext context, _SupCard card) {
    final time = rangeLabel(card.startMin, card.endMin);
    final everyWeek = card.dateLabel == '매주';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: NestColors.dustyRose.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: NestColors.deepWood,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.meeting_room_outlined,
                        size: 16, color: NestColors.clay),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(card.room,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  card.count != null ? '자습생 ${card.count}명' : '자습 감독',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // '언제'를 직관적으로: 매주 반복이면 '매주', 특정 날짜만이면 날짜.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 104),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: everyWeek
                    ? NestColors.mutedSage.withValues(alpha: 0.18)
                    : NestColors.clay.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                everyWeek ? '매주' : card.dateLabel,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: NestColors.deepWood.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupCard {
  const _SupCard({
    required this.day,
    required this.startMin,
    required this.endMin,
    required this.room,
    required this.count,
    required this.dateLabel,
  });

  final int day;
  final int startMin;
  final int endMin;
  final String room;

  /// 슬롯 기반이면 자습생 수, 회전(날짜 지정)이면 null.
  final int? count;

  /// '매주' 또는 특정 날짜 목록(예: '7/6, 7/20').
  final String dateLabel;
}

/// 감독표를 전체 화면으로 연다(관리자에서 교사 클릭 시).
void showSupervisionSchedulePage(
  BuildContext context,
  NestController controller,
  String teacherProfileId, {
  String? teacherName,
}) {
  final name = teacherName ?? controller.findTeacherName(teacherProfileId);
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: NestColors.creamyWhite,
        appBar: AppBar(
          title: Text('$name 감독표'),
          backgroundColor: NestColors.creamyWhite,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: SupervisionScheduleView(
            controller: controller,
            teacherProfileId: teacherProfileId,
            teacherName: name,
            showHeader: false,
          ),
        ),
      ),
    ),
  );
}
