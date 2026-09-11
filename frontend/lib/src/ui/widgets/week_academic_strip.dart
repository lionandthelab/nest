import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/schedule_occurrence.dart';
import '../../services/schedule_overlap.dart';
import '../nest_theme.dart';

Future<void> showAcademicEventPreview(
  BuildContext context,
  AcademicEvent event,
) {
  final range = event.endDate == null ||
          nestDateOnly(event.endDate!) == nestDateOnly(event.eventDate)
      ? DateFormat('M월 d일 (E)', 'ko').format(event.eventDate)
      : '${DateFormat('M월 d일').format(event.eventDate)} – '
          '${DateFormat('M월 d일').format(event.endDate!)}';
  final time = event.isAllDay
      ? '종일'
      : '${(event.startTime ?? '').split(':').take(2).join(':')}'
          '${(event.endTime ?? '').trim().isEmpty ? '' : ' – ${(event.endTime ?? '').split(':').take(2).join(':')}'}';
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(event.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${academicKindLabel(event.kind)} · $range · $time'),
          if (event.description.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(event.description.trim()),
          ],
          const SizedBox(height: 8),
          Text(
            event.publishAnnouncement
                ? '소식 탭 공지에도 같이 올라갑니다.'
                : '공지 없이 달력·시간표에만 표시됩니다.',
            style: Theme.of(ctx).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('닫기'),
        ),
      ],
    ),
  );
}

/// 선택한 주에 걸린 학사일정을 한 줄로 보여 주는 막대.
class WeekAcademicStrip extends StatelessWidget {
  const WeekAcademicStrip({
    super.key,
    required this.events,
    required this.weekMonday,
    this.onTapEvent,
    this.showWhenEmpty = false,
  });

  final List<AcademicEvent> events;
  final DateTime weekMonday;
  final ValueChanged<AcademicEvent>? onTapEvent;
  final bool showWhenEmpty;

  @override
  Widget build(BuildContext context) {
    final weekEvents = academicEventsInWeek(
      events: events,
      weekMonday: weekMonday,
    );
    if (weekEvents.isEmpty && !showWhenEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: NestColors.clay.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.clay.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '이번 주 학사일정',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: NestColors.clay,
            ),
          ),
          const SizedBox(height: 6),
          if (weekEvents.isEmpty)
            Text(
              '이 주에는 등록된 학사일정이 없습니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.62),
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: weekEvents
                  .map(
                    (event) => _WeekEventChip(
                      event: event,
                      onTap: onTapEvent == null
                          ? null
                          : () => onTapEvent!(event),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _WeekEventChip extends StatelessWidget {
  const _WeekEventChip({required this.event, this.onTap});

  final AcademicEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final start = DateFormat('M/d').format(event.eventDate);
    final end = event.endDate;
    final range = end == null || nestDateOnly(end) == nestDateOnly(event.eventDate)
        ? start
        : '$start–${DateFormat('M/d').format(end)}';
    final time = event.isAllDay
        ? '종일'
        : (event.startTime ?? '').split(':').take(2).join(':');
    final label = '$range · ${academicKindLabel(event.kind)} · $time';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: event.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: NestColors.deepWood,
                    fontSize: 12,
                  ),
                ),
                TextSpan(
                  text: '  $label',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: NestColors.deepWood.withValues(alpha: 0.62),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
