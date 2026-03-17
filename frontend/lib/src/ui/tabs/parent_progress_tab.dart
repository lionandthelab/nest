import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/entity_visuals.dart';
import '../widgets/nest_empty_state.dart';
import '../widgets/nest_refresh.dart';
import '../widgets/nest_skeleton.dart';

class ParentProgressTab extends StatelessWidget {
  const ParentProgressTab({
    super.key,
    required this.controller,
    required this.selectedChildId,
    required this.childClassBundles,
    required this.isLoadingChildClasses,
  });

  final NestController controller;
  final String? selectedChildId;
  final Map<String, ChildClassBundle> childClassBundles;
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

    final displayLogs = childLogs.take(40).toList(growable: false);

    // Fixed items: title row + spacer = 2
    // Then: loading skeletons (3 cards + 2 spacers = 5) OR empty state (1) OR
    //       metrics + spacer + (empty state | log items)
    // We compute a flat item list to drive ListView.builder.
    final items = <Widget>[
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
    ];

    if (isLoadingChildClasses && selectedChildId != null && childLogs.isEmpty) {
      items.addAll(const [
        NestSkeletonCard(),
        SizedBox(height: 8),
        NestSkeletonCard(),
        SizedBox(height: 8),
        NestSkeletonCard(),
      ]);
    } else if (selectedChildId == null) {
      items.add(const NestEmptyState(
        icon: Icons.trending_up,
        title: '아이를 먼저 선택하세요',
        subtitle: '상단에서 아이를 선택하면 학습 현황을 확인할 수 있습니다.',
      ));
    } else {
      items.add(
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
      );
      items.add(const SizedBox(height: 12));

      if (childLogs.isEmpty) {
        items.add(const NestEmptyState(
          icon: Icons.trending_up,
          title: '등록된 상태 로그가 없습니다',
          subtitle: '선생님이 기록을 남기면 여기서 확인할 수 있습니다.',
        ));
      }
      // Log rows are rendered directly by itemBuilder below for lazy loading.
    }

    return NestRefreshable(
      onRefresh: () => controller.refreshAll(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
      itemCount: items.length + (selectedChildId != null && childLogs.isNotEmpty ? displayLogs.length : 0),
      itemBuilder: (context, index) {
        if (index < items.length) return items[index];

        final log = displayLogs[index - items.length];
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
                  text: controller.findTeacherName(log.recordedByTeacherId),
                ),
              ],
            ),
          ),
        );
      },
      ),
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
