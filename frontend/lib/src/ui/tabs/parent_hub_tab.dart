import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class ParentHubTab extends StatelessWidget {
  const ParentHubTab({super.key, required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final sessions = controller.sessions.length;
    final gallery = controller.galleryItems.length;
    final announcements = controller.announcements.length;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parent Hub',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '우리 아이 반 운영 상황, 공지, 활동 기록을 한 곳에서 확인합니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricCard(label: '이번 반 수업 수', value: '$sessions'),
                    _MetricCard(label: '갤러리 항목', value: '$gallery'),
                    _MetricCard(label: '공지', value: '$announcements'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _AnnouncementCard(controller: controller),
        const SizedBox(height: 12),
        _ActivityTimelineCard(controller: controller),
      ],
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('공지', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (controller.announcements.isEmpty)
              const Text('등록된 공지가 없습니다.')
            else
              ...controller.announcements.take(20).map((row) {
                final when = row.createdAt == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt!);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NestColors.roseMist),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (row.pinned) const Chip(label: Text('PINNED')),
                            Chip(
                              label: Text(
                                row.classGroupId == null
                                    ? '전체'
                                    : controller.findClassGroupName(
                                        row.classGroupId,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          row.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(row.body),
                        const SizedBox(height: 4),
                        Text(
                          when,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ActivityTimelineCard extends StatelessWidget {
  const _ActivityTimelineCard({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final logs = controller.studentActivityLogs.toList(growable: false)
      ..sort((a, b) {
        final left = a.recordedAt?.millisecondsSinceEpoch ?? 0;
        final right = b.recordedAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('아동 활동 기록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              const Text('등록된 활동 기록이 없습니다.')
            else
              ...logs.take(40).map((log) {
                final childName =
                    controller.children
                        .where((child) => child.id == log.childId)
                        .map((child) => child.name)
                        .firstOrNull ??
                    log.childId;
                final when = log.recordedAt == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd HH:mm').format(log.recordedAt!);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('$childName · ${log.activityType}'),
                  subtitle: Text(log.content),
                  trailing: Text(
                    when,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
