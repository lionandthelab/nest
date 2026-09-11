import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/schedule_occurrence.dart';
import '../../services/schedule_overlap.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'calendar_connect_card.dart';
import 'personal_event_sheet.dart';

Future<void> openPersonalEventForChild({
  required BuildContext context,
  required NestController controller,
  required String childId,
  required Iterable<ClassSession> sessions,
  PersonalEvent? event,
  DateTime? date,
  TimeSlot? slot,
}) async {
  final now = DateTime.now();
  final day = nestDateOnly(event?.startsAt ?? date ?? now);
  DateTime start;
  DateTime end;
  if (event != null) {
    start = event.startsAt;
    end = event.endsAt;
  } else if (slot != null) {
    start = nestDateTimeOn(day, slot.startTime);
    end = nestDateTimeOn(day, slot.endTime);
    if (!end.isAfter(start)) {
      end = start.add(const Duration(minutes: 50));
    }
  } else {
    start = DateTime(day.year, day.month, day.day, 16);
    end = start.add(const Duration(hours: 1));
  }

  final weekStart = nestMondayOf(start);
  final classes = <ResolvedOccurrence>[
    for (var i = 0; i < 7; i++)
      ...controller.occurrencesOn(
        weekStart.add(Duration(days: i)),
        forSessions: sessions,
      ),
  ];

  await showPersonalEventSheet(
    context: context,
    controller: controller,
    childId: childId,
    event: event,
    initialStart: start,
    initialEnd: end,
    overlappingClasses: classes,
  );
}

class PersonalWeekList extends StatelessWidget {
  const PersonalWeekList({
    super.key,
    required this.controller,
    required this.childId,
    required this.weekMonday,
    required this.sessions,
  });

  final NestController controller;
  final String childId;
  final DateTime weekMonday;
  final Iterable<ClassSession> sessions;

  @override
  Widget build(BuildContext context) {
    final start = nestMondayOf(weekMonday);
    final end = start.add(const Duration(days: 7));
    final events = controller
        .personalEventsForChild(childId)
        .where(
          (event) =>
              event.startsAt.isBefore(end) &&
              event.endsAt.isAfter(start),
        )
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Text(
              '이번 주 개인 일정',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => openPersonalEventForChild(
                context: context,
                controller: controller,
                childId: childId,
                sessions: sessions,
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('추가'),
            ),
          ],
        ),
        if (events.isEmpty)
          Text(
            '학원·병원처럼 학기 시간표 밖의 약속을 넣을 수 있습니다. 수업과 겹치면 칸에 표시됩니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.6),
            ),
          )
        else
          ...events.map((event) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(event.title),
                subtitle: Text(
                  DateFormat('E HH:mm', 'ko').format(event.startsAt) +
                      ' – ${DateFormat('HH:mm').format(event.endsAt)}',
                ),
                trailing: IconButton(
                  tooltip: '삭제',
                  onPressed: () =>
                      controller.deletePersonalEvent(eventId: event.id),
                  icon: const Icon(Icons.delete_outline),
                ),
                onTap: () => openPersonalEventForChild(
                  context: context,
                  controller: controller,
                  childId: childId,
                  sessions: sessions,
                  event: event,
                ),
              ),
            );
          }),
        const SizedBox(height: 8),
        CalendarConnectCard(controller: controller, childId: childId),
      ],
    );
  }
}
