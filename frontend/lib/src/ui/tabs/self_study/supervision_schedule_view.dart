import 'package:flutter/material.dart';

import '../../../models/nest_models.dart';
import '../../../services/self_study_planner.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';
import '../../widgets/nest_empty_state.dart';

/// 감독표 — 한 교사가 감독하는 자습 슬롯을 날짜(요일)·시간·장소로 보여준다.
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
        final name = teacherName ?? controller.findTeacherName(teacherProfileId);

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

        final byDay = <int, List<SelfStudySlot>>{};
        for (final s in slots) {
          byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
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
              '${plan.name} · 총 ${slots.length + rotations.length}회',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.7),
                  ),
            ),
          ));
        }

        for (final day in order) {
          final ds = byDay[day];
          if (ds == null || ds.isEmpty) continue;
          ds.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
          for (final slot in ds) {
            children.add(_card(context, slot));
          }
        }

        if (rotations.isNotEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6, left: 2),
            child: Text(
              '회전 감독 (날짜별)',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ));
          final byBand = <String, List<SelfStudySupervision>>{};
          for (final r in rotations) {
            byBand
                .putIfAbsent('${r.dayOfWeek}|${r.room}|${r.bandStart}', () => [])
                .add(r);
          }
          for (final entry in byBand.entries) {
            children.add(_rotationCard(context, entry.value));
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }

  Widget _rotationCard(
    BuildContext context,
    List<SelfStudySupervision> list,
  ) {
    final f = list.first;
    final time = rangeLabel(
      minutesFromTime(f.bandStart),
      minutesFromTime(f.bandEnd),
    );
    final room = f.room.trim().isEmpty ? '장소 미정' : f.room.trim();
    final weekly = list.any((r) => r.occurrenceDate == null);
    final dates = list
        .map((r) => r.occurrenceDate)
        .whereType<DateTime>()
        .map((d) => '${d.month}/${d.day}')
        .join(', ');
    final datesLabel = weekly ? '매주' : dates;

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
                    Text('${weekdayLabel(f.dayOfWeek)}요일 · $room',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  datesLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, SelfStudySlot slot) {
    final time = rangeLabel(
      minutesFromTime(slot.startTime),
      minutesFromTime(slot.endTime),
    );
    final groupName = controller.findClassGroupName(slot.classGroupId);
    final room = slot.room.trim().isEmpty ? '장소 미정' : slot.room.trim();
    final count = controller.rosterForSelfStudySlot(slot).length;

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
                    Text(room,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$groupName · $count명',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.7),
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
