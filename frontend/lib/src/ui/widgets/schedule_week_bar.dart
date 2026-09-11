import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/schedule_occurrence.dart';
import '../nest_theme.dart';

/// 주간 시간표에서 "이번 주"를 고르는 막대.
class ScheduleWeekBar extends StatelessWidget {
  const ScheduleWeekBar({
    super.key,
    required this.weekMonday,
    required this.onChanged,
    this.termStart,
    this.termEnd,
  });

  final DateTime weekMonday;
  final ValueChanged<DateTime> onChanged;
  final DateTime? termStart;
  final DateTime? termEnd;

  @override
  Widget build(BuildContext context) {
    final monday = nestMondayOf(weekMonday);
    final sunday = monday.add(const Duration(days: 6));
    final label =
        '${DateFormat('M/d').format(monday)} – ${DateFormat('M/d').format(sunday)}';
    final todayWeek = nestMondayOf(DateTime.now());

    return Row(
      children: [
        IconButton(
          tooltip: '이전 주',
          onPressed: () => onChanged(monday.subtract(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: DateUtils.isSameDay(monday, todayWeek)
              ? null
              : () => onChanged(todayWeek),
          child: const Text('이번 주'),
        ),
        IconButton(
          tooltip: '다음 주',
          onPressed: () => onChanged(monday.add(const Duration(days: 7))),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class ScheduleDayChips extends StatelessWidget {
  const ScheduleDayChips({
    super.key,
    required this.academicTitles,
    required this.personalCount,
  });

  final List<String> academicTitles;
  final int personalCount;

  @override
  Widget build(BuildContext context) {
    if (academicTitles.isEmpty && personalCount <= 0) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          ...academicTitles.take(2).map(
            (title) => _chip(
              context,
              title,
              NestColors.clay,
            ),
          ),
          if (personalCount > 0)
            _chip(
              context,
              personalCount == 1 ? '개인' : '개인 $personalCount',
              NestColors.mutedSage,
            ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 9,
        ),
      ),
    );
  }
}
