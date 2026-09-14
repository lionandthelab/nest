import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'nest_empty_state.dart';
import 'nest_motion.dart';
import 'nest_sheet.dart';

Future<void> showNotificationInboxSheet({
  required BuildContext context,
  required NestController controller,
  required void Function(NotificationInboxItem item) onOpenItem,
}) {
  return showNestSheet<void>(
    context: context,
    builder: (context) {
      return AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final items = controller.notificationInbox;
          return NestSheet(
            title: '알림',
            subtitle: '수업 변경·결석·오늘 일정·수업 30분 전 알림',
            scrollable: false,
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: items.isEmpty
                          ? const NestEmptyState(
                              icon: Icons.notifications_none_outlined,
                              title: '아직 받은 알림이 없어요',
                              subtitle: '수업이 바뀌거나 오늘 일정이 생기면 여기에 모입니다.',
                            )
                          : ListView.separated(
                              itemCount: items.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final item = items[index];
                                return _InboxTile(
                                  item: item,
                                  onTap: () {
                                    NestHaptics.selection();
                                    Navigator.of(context).pop();
                                    onOpenItem(item);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
            ),
          );
        },
      );
    },
  );
}

class _InboxTile extends StatelessWidget {
  const _InboxTile({required this.item, required this.onTap});

  final NotificationInboxItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final when = item.createdAt == null
        ? ''
        : DateFormat('M/d HH:mm').format(item.createdAt!.toLocal());
    return NestPressable(
      onPressed: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        child: ListTile(
          leading: Icon(_iconFor(item.eventType), color: NestColors.clay),
          title: Text(
            item.title.isEmpty ? _fallbackTitle(item.eventType) : item.title,
            maxLines: 2,
            softWrap: true,
          ),
          subtitle: Text(
            [item.body, when].where((part) => part.isNotEmpty).join(' · '),
            maxLines: 4,
            softWrap: true,
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String eventType) {
    return switch (eventType) {
      'CLASS_REMINDER' => Icons.alarm_outlined,
      'MORNING_DIGEST' => Icons.wb_sunny_outlined,
      'CLASS_CHANGE' => Icons.swap_horiz_outlined,
      'ABSENCE' => Icons.event_busy_outlined,
      _ => Icons.notifications_outlined,
    };
  }

  String _fallbackTitle(String eventType) {
    return switch (eventType) {
      'CLASS_REMINDER' => '수업 30분 전',
      'MORNING_DIGEST' => '오늘 일정',
      'CLASS_CHANGE' => '수업 변경',
      'ABSENCE' => '결석 알림',
      _ => '알림',
    };
  }
}
