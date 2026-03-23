import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/entity_visuals.dart';
import '../widgets/hub_scaffold.dart';
import '../widgets/nest_empty_state.dart';
import '../widgets/nest_skeleton.dart';

class ParentHomeTab extends StatefulWidget {
  const ParentHomeTab({
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
  State<ParentHomeTab> createState() => _ParentHomeTabState();
}

class _ParentHomeTabState extends State<ParentHomeTab> {
  String _sectionId = 'announcements';

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bundles = widget.childClassBundles;
    final enrolledClassCount = bundles.length;
    final enrolledSessionCount = bundles.values
        .map((b) => b.sessions.length)
        .fold<int>(0, (acc, v) => acc + v);

    final childLogs = widget.selectedChildId == null
        ? const <StudentActivityLog>[]
        : controller
              .activityLogsForChild(widget.selectedChildId!)
              .toList()
          ..sort((a, b) {
            final left = a.recordedAt?.millisecondsSinceEpoch ?? 0;
            final right = b.recordedAt?.millisecondsSinceEpoch ?? 0;
            return right.compareTo(left);
          });

    return HubScaffold(
      title: '대시보드',
      subtitle: '공지사항과 학습 현황을 한눈에 확인합니다.',
      icon: Icons.home_outlined,
      isBusy: controller.isBusy || widget.isLoadingChildClasses,
      metrics: [
        HubMetric(
          label: '배정 반',
          value: '$enrolledClassCount',
          icon: Icons.groups,
        ),
        HubMetric(
          label: '주간 수업',
          value: '$enrolledSessionCount',
          icon: Icons.view_week,
        ),
        HubMetric(
          label: '활동 기록',
          value: '${childLogs.length}',
          icon: Icons.assignment_outlined,
        ),
      ],
      selectedSectionId: _sectionId,
      onSelectSection: (id) => setState(() => _sectionId = id),
      sections: [
        HubSection(
          id: 'announcements',
          label: '공지사항',
          icon: Icons.campaign_outlined,
          content: _buildAnnouncementsSection(controller),
        ),
        HubSection(
          id: 'progress',
          label: '학습 현황',
          icon: Icons.insights_outlined,
          content: _buildProgressSection(controller, childLogs),
        ),
      ],
    );
  }

  // ── Announcements ──

  Widget _buildAnnouncementsSection(NestController controller) {
    final announcements =
        controller.announcements.toList()..sort((a, b) {
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return right.compareTo(left);
        });

    if (announcements.isEmpty) {
      if (controller.isBusy) {
        return const Column(
          children: [
            NestSkeletonCard(),
            SizedBox(height: 8),
            NestSkeletonCard(),
          ],
        );
      }
      return const NestEmptyState(
        icon: Icons.campaign_outlined,
        title: '등록된 공지사항이 없습니다',
        subtitle: '새로운 공지사항이 등록되면 여기서 확인할 수 있습니다.',
      );
    }

    return Column(
      children: announcements.map((a) {
        final when = a.createdAt == null
            ? '-'
            : DateFormat('yyyy-MM-dd HH:mm').format(a.createdAt!);
        final classGroupName = a.classGroupId == null
            ? '전체 공지'
            : controller.findClassGroupName(a.classGroupId!);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    EntityAvatar(
                      label: classGroupName,
                      icon: a.pinned
                          ? Icons.push_pin_outlined
                          : Icons.campaign_outlined,
                      size: 34,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (a.pinned)
                      Icon(
                        Icons.push_pin,
                        size: 16,
                        color: NestColors.dustyRose,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      classGroupName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      when,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                if (a.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(a.body),
                ],
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Progress / Activity Logs ──

  Widget _buildProgressSection(
    NestController controller,
    List<StudentActivityLog> childLogs,
  ) {
    if (widget.selectedChildId == null) {
      return const NestEmptyState(
        icon: Icons.trending_up,
        title: '아이를 먼저 선택하세요',
        subtitle: '상단에서 아이를 선택하면 학습 현황을 확인할 수 있습니다.',
      );
    }

    if (widget.isLoadingChildClasses && childLogs.isEmpty) {
      return const Column(
        children: [
          NestSkeletonCard(),
          SizedBox(height: 8),
          NestSkeletonCard(),
        ],
      );
    }

    final countsByType = <String, int>{};
    for (final log in childLogs) {
      countsByType[log.activityType] =
          (countsByType[log.activityType] ?? 0) + 1;
    }

    final sessionClassNameById = <String, String>{};
    for (final bundle in widget.childClassBundles.values) {
      for (final session in bundle.sessions) {
        sessionClassNameById[session.id] = bundle.classGroup.name;
      }
    }

    final displayLogs = childLogs.take(20).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Type breakdown chips
        if (countsByType.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: countsByType.entries.map((entry) {
                return Chip(
                  avatar: Icon(_activityIcon(entry.key), size: 16),
                  label: Text(
                    '${_activityTypeLabel(entry.key)} ${entry.value}건',
                  ),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ),

        if (childLogs.isEmpty)
          const NestEmptyState(
            icon: Icons.trending_up,
            title: '등록된 활동 기록이 없습니다',
            subtitle: '선생님이 기록을 남기면 여기서 확인할 수 있습니다.',
          )
        else
          ...displayLogs.map((log) {
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
                    Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 14,
                          color: NestColors.deepWood.withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            controller.findTeacherName(
                              log.recordedByTeacherId,
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: NestColors.deepWood.withValues(
                                    alpha: 0.74,
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
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
