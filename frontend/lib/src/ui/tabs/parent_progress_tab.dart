import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/child_selector_header.dart';

class ParentProgressTab extends StatelessWidget {
  const ParentProgressTab({
    super.key,
    required this.controller,
    required this.selectedChildId,
    required this.childClassBundles,
    required this.onSelectChild,
    required this.isLoadingChildClasses,
  });

  final NestController controller;
  final String? selectedChildId;
  final Map<String, ChildClassBundle> childClassBundles;
  final ValueChanged<String?> onSelectChild;
  final bool isLoadingChildClasses;

  @override
  Widget build(BuildContext context) {
    final childLogs = selectedChildId == null
        ? const <StudentActivityLog>[]
        : controller
              .activityLogsForChild(selectedChildId!)
              .toList(growable: false)
          ..sort((a, b) {
            final left = a.recordedAt?.millisecondsSinceEpoch ?? 0;
            final right = b.recordedAt?.millisecondsSinceEpoch ?? 0;
            return right.compareTo(left);
          });

    final countsByType = <String, int>{};
    for (final log in childLogs) {
      countsByType[log.activityType] =
          (countsByType[log.activityType] ?? 0) + 1;
    }

    final sessionClassNameById = <String, String>{};
    for (final bundle in childClassBundles.values) {
      for (final session in bundle.sessions) {
        sessionClassNameById[session.id] = bundle.classGroup.name;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ChildSelectorHeader(
          controller: controller,
          selectedChildId: selectedChildId,
          childClassBundles: childClassBundles,
          onSelectChild: onSelectChild,
          isLoadingChildClasses: isLoadingChildClasses,
        ),
        const SizedBox(height: 12),
        Text('학습 현황', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (selectedChildId == null)
          _buildEmptyHint('아이를 먼저 선택하세요.')
        else ...[
          // Metrics
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.assignment, size: 16),
                label: Text('총 기록 ${childLogs.length}건'),
              ),
              ...countsByType.entries.map(
                (entry) => Chip(
                  label: Text('${entry.key} ${entry.value}건'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Activity log list
          if (childLogs.isEmpty)
            _buildEmptyHint('등록된 상태 로그가 없습니다.')
          else
            ...childLogs.take(40).map((log) {
              final when = log.recordedAt == null
                  ? '-'
                  : DateFormat('yyyy-MM-dd HH:mm').format(log.recordedAt!);
              final className = log.classSessionId == null
                  ? '세션 미지정'
                  : sessionClassNameById[log.classSessionId!] ?? '연결 반 확인 필요';

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NestColors.roseMist),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${log.activityType} · $className',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(log.content),
                      const SizedBox(height: 4),
                      Text(
                        '$when · ${controller.findTeacherName(log.recordedByTeacherId)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ],
    );
  }

  Widget _buildEmptyHint(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.roseMist.withValues(alpha: 0.36),
      ),
      child: Text(message),
    );
  }
}
