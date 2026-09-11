import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/schedule_overlap.dart';
import '../nest_theme.dart';
import 'nest_motion.dart';

class TodayPersonalEvents extends StatelessWidget {
  const TodayPersonalEvents({
    super.key,
    required this.events,
    this.onAdd,
    this.onOpen,
  });

  final List<PersonalEvent> events;
  final VoidCallback? onAdd;
  final ValueChanged<PersonalEvent>? onOpen;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty && onAdd == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.event_available_outlined, size: 18, color: NestColors.mutedSage),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '오늘 개인 일정',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (onAdd != null)
              TextButton(onPressed: onAdd, child: const Text('추가')),
          ],
        ),
        if (events.isEmpty)
          Text(
            '아직 없어요. 병원·학원처럼 학기 시간표 밖의 약속을 넣을 수 있습니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.6),
            ),
          )
        else
          ...events.map((event) {
            return NestPressable(
              onPressed: onOpen == null ? null : () => onOpen!(event),
              child: Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: NestColors.mutedSage,
                  ),
                  title: Text(event.title),
                  subtitle: Text(
                    '${DateFormat('HH:mm').format(event.startsAt)} – '
                    '${DateFormat('HH:mm').format(event.endsAt)}'
                    '${event.prioritizesPersonal ? ' · ${conflictPolicyLabel(event.conflictPolicy)}' : ''}',
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
