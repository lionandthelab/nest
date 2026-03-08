import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/child_selector_header.dart';
import '../widgets/entity_visuals.dart';

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
    final childLogs =
        selectedChildId == null
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
        Row(
          children: [
            Icon(
              Icons.insights_outlined,
              color: NestColors.deepWood.withValues(alpha: 0.76),
            ),
            const SizedBox(width: 8),
            Text('학습 현황', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 8),
        if (selectedChildId == null)
          _buildEmptyHint('아이를 먼저 선택하세요.')
        else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 840;
              final itemWidth = compact
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 16) / 3;
              final metricTiles = <Widget>[
                _ProgressMetricTile(
                  label: '총 기록',
                  value: '${childLogs.length}',
                  icon: Icons.assignment_outlined,
                ),
                ...countsByType.entries.map(
                  (entry) => _ProgressMetricTile(
                    label: _activityTypeLabel(entry.key),
                    value: '${entry.value}',
                    icon: _activityIcon(entry.key),
                  ),
                ),
              ];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: metricTiles
                    .map((tile) => SizedBox(width: itemWidth, child: tile))
                    .toList(growable: false),
              );
            },
          ),
          const SizedBox(height: 12),
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
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          EntityAvatar(
                            label: controller.findTeacherName(
                              log.recordedByTeacherId,
                            ),
                            icon: _activityIcon(log.activityType),
                            size: 30,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_activityTypeLabel(log.activityType)} · $className',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            when,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(log.content),
                      const SizedBox(height: 4),
                      _MetaText(
                        icon: Icons.school_outlined,
                        text: controller.findTeacherName(
                          log.recordedByTeacherId,
                        ),
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

  static IconData _activityIcon(String type) {
    return switch (type) {
      'ATTENDANCE' => Icons.how_to_reg_outlined,
      'ASSIGNMENT' => Icons.task_alt_outlined,
      _ => Icons.visibility_outlined,
    };
  }

  static String _activityTypeLabel(String type) {
    return switch (type) {
      'ATTENDANCE' => '출결',
      'ASSIGNMENT' => '과제',
      'OBSERVATION' => '관찰',
      _ => type,
    };
  }
}

class _ProgressMetricTile extends StatelessWidget {
  const _ProgressMetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
        color: Colors.white,
      ),
      child: Row(
        children: [
          EntityAvatar(label: label, icon: icon, size: 34),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
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

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: NestColors.deepWood.withValues(alpha: 0.65),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.74),
            ),
          ),
        ),
      ],
    );
  }
}
