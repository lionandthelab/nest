import 'package:flutter/material.dart';

import '../../services/schedule_occurrence.dart';
import '../nest_theme.dart';
import 'nest_motion.dart';

/// 다음 수업 히어로 + 오늘 남은 수업. 탭하면 시간표로 이동한다.
class TodayScheduleCard extends StatelessWidget {
  const TodayScheduleCard({
    super.key,
    required this.occurrences,
    required this.courseNameOf,
    this.classNameOf,
    this.now,
    this.onOpenTimetable,
    this.emptyLabel = '오늘 남은 수업이 없어요',
  });

  final List<ResolvedOccurrence> occurrences;
  final String Function(String courseId) courseNameOf;
  final String Function(String classGroupId)? classNameOf;
  final DateTime? now;
  final VoidCallback? onOpenTimetable;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final clock = now ?? DateTime.now();
    final remaining = occurrences
        .where((row) => !row.isCanceled)
        .where((row) {
          if (nestDateOnly(row.date) != nestDateOnly(clock)) return false;
          return nestMinutesFromTime(row.slot.endTime) >
              clock.hour * 60 + clock.minute;
        })
        .toList();
    final next = remaining.isEmpty ? null : remaining.first;
    final rest = remaining.length > 1 ? remaining.sublist(1) : const <ResolvedOccurrence>[];

    return Card(
      color: NestColors.roseMist.withValues(alpha: 0.35),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpenTimetable == null
            ? null
            : () {
                NestHaptics.selection();
                onOpenTimetable!();
              },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: next == null
              ? Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined, color: NestColors.clay),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        emptyLabel,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (onOpenTimetable != null)
                      Icon(
                        Icons.chevron_right,
                        color: NestColors.deepWood.withValues(alpha: 0.45),
                      ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '다음 수업',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.clay,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      courseNameOf(next.session.courseId),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _detailLine(next),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.72),
                      ),
                    ),
                    if (rest.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '오늘 남은 수업 ${rest.length}개',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: NestColors.deepWood.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...rest.take(3).map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${shortTimeLabel(row.slot.startTime)}  ${courseNameOf(row.session.courseId)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  String _detailLine(ResolvedOccurrence row) {
    final time =
        '${shortTimeLabel(row.slot.startTime)}–${shortTimeLabel(row.slot.endTime)}';
    final className = classNameOf?.call(row.session.classGroupId) ?? '';
    final parts = <String>[
      time,
      if (className.isNotEmpty) className,
      if (row.location.isNotEmpty) row.location,
    ];
    return parts.join(' · ');
  }
}
