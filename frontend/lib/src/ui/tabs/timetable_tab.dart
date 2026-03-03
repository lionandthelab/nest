import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class TimetableTab extends StatefulWidget {
  const TimetableTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab> {
  final _promptController = TextEditingController();

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1180;
    final adminEditable = controller.isAdminLike;

    return ListView(
      children: [
        if (adminEditable) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prompt Studio',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '프롬프트로 생성안을 만든 뒤 적용하거나, 드래그 앤 드롭으로 바로 수동 편집할 수 있습니다.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _promptController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: '예: 화/목 오전은 국어/수학 중심으로 편성해줘.',
                      labelText: '시간표 생성 프롬프트',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: controller.isBusy ? null : _generateProposal,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('생성안 만들기'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: controller.isBusy ? null : _reloadProposals,
                        icon: const Icon(Icons.refresh),
                        label: const Text('생성안 갱신'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ] else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Read-only Timetable',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '현재 뷰에서는 시간표 열람만 가능합니다. 수정은 관리자 뷰에서 진행하세요.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        compact
            ? Column(
                children: [
                  if (adminEditable) ...[
                    _buildProposalPanel(controller),
                    const SizedBox(height: 12),
                  ],
                  _buildBoardPanel(controller),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (adminEditable) ...[
                    Expanded(flex: 2, child: _buildProposalPanel(controller)),
                    const SizedBox(width: 12),
                  ],
                  Expanded(flex: 3, child: _buildBoardPanel(controller)),
                ],
              ),
      ],
    );
  }

  Widget _buildProposalPanel(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('생성안 목록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (controller.proposals.isEmpty)
              const Text('생성안이 없습니다.')
            else
              ...controller.proposals.map((proposal) {
                final rows =
                    controller.proposalSessionsById[proposal.id] ?? const [];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: NestColors.roseMist),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          proposal.prompt,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('yyyy-MM-dd HH:mm').format(proposal.createdAt ?? DateTime.now())} · '
                          '${proposal.status} · ${rows.length}세션',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: controller.isBusy
                                  ? null
                                  : () => _applyProposal(proposal.id),
                              child: const Text('적용'),
                            ),
                            FilledButton.tonal(
                              onPressed: controller.isBusy
                                  ? null
                                  : () => _discardProposal(proposal.id),
                              child: const Text('폐기'),
                            ),
                          ],
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

  Widget _buildBoardPanel(NestController controller) {
    final sortedSlots = controller.timeSlots.toList(growable: false)
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) {
          return day;
        }
        return a.startTime.compareTo(b.startTime);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manual Board', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (controller.courses.isEmpty)
              const Text('과목이 없습니다. Dashboard에서 과목을 추가하세요.')
            else if (controller.isAdminLike)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: controller.courses
                    .map(
                      (course) => LongPressDraggable<DragPayload>(
                        data: DragPayload(
                          type: DragPayloadType.course,
                          id: course.id,
                        ),
                        feedback: Material(
                          color: Colors.transparent,
                          child: _CourseChip(
                            label: course.name,
                            dragging: true,
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _CourseChip(label: course.name),
                        ),
                        child: _CourseChip(label: course.name),
                      ),
                    )
                    .toList(growable: false),
              ),
            if (!controller.isAdminLike)
              Text(
                '읽기 전용 모드에서는 과목 드래그/세션 이동이 비활성화됩니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            if (sortedSlots.isEmpty)
              const Text('시간 슬롯이 없습니다. Dashboard에서 초기 세팅을 진행하세요.')
            else
              ...sortedSlots.map((slot) => _buildSlot(controller, slot)),
          ],
        ),
      ),
    );
  }

  Widget _buildSlot(NestController controller, TimeSlot slot) {
    final slotSessions = controller.sessionsForSlot(slot.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DragTarget<DragPayload>(
        onWillAcceptWithDetails: (_) =>
            controller.isAdminLike && !controller.isBusy,
        onAcceptWithDetails: (details) async {
          final payload = details.data;
          if (payload.type == DragPayloadType.course) {
            await _safeCall(() {
              return controller.createSessionByCourse(
                courseId: payload.id,
                slotId: slot.id,
              );
            });
          } else {
            await _safeCall(() {
              return controller.moveSession(
                sessionId: payload.id,
                targetSlotId: slot.id,
              );
            });
          }
        },
        builder: (context, candidateData, rejectedData) {
          final isHovering = candidateData.isNotEmpty;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isHovering
                  ? NestColors.roseMist.withValues(alpha: 0.55)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isHovering ? NestColors.clay : NestColors.roseMist,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(
                      avatar: const Icon(Icons.schedule, size: 16),
                      label: Text(
                        '${_dayLabel(slot.dayOfWeek)} '
                        '${_shortTime(slot.startTime)}-${_shortTime(slot.endTime)}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (slotSessions.isEmpty)
                  Text(
                    controller.isAdminLike
                        ? '여기로 과목 또는 수업 카드를 드래그하세요.'
                        : '배정된 수업 없음',
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  ...slotSessions.map(
                    (session) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: LongPressDraggable<DragPayload>(
                        data: DragPayload(
                          type: DragPayloadType.session,
                          id: session.id,
                        ),
                        feedback: Material(
                          color: Colors.transparent,
                          child: _SessionCard(
                            title: session.title.isEmpty
                                ? controller.findCourseName(session.courseId)
                                : session.title,
                            subtitle:
                                '${controller.findCourseName(session.courseId)} · ${session.sourceType}',
                            teacherBadges: const [],
                            conflictMessages: const [],
                            canManageTeachers: false,
                            onManageTeachers: null,
                            canDelete: false,
                            onDelete: null,
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _SessionCard(
                            title: session.title.isEmpty
                                ? controller.findCourseName(session.courseId)
                                : session.title,
                            subtitle:
                                '${controller.findCourseName(session.courseId)} · ${session.sourceType}',
                            teacherBadges: const [],
                            conflictMessages: const [],
                            canManageTeachers: false,
                            onManageTeachers: null,
                            canDelete: false,
                            onDelete: null,
                          ),
                        ),
                        child: _SessionCard(
                          title: session.title.isEmpty
                              ? controller.findCourseName(session.courseId)
                              : session.title,
                          subtitle:
                              '${controller.findCourseName(session.courseId)} · ${session.sourceType}',
                          teacherBadges: controller
                              .teacherAssignmentsForSession(session.id)
                              .map(
                                (row) =>
                                    '${row.assignmentRole == 'MAIN' ? '주' : '보조'} · ${controller.findTeacherName(row.teacherProfileId)}',
                              )
                              .toList(growable: false),
                          conflictMessages: controller
                              .teacherConflictMessagesForSession(session.id),
                          canManageTeachers:
                              controller.canManageTeacherAssignments,
                          onManageTeachers:
                              controller.canManageTeacherAssignments
                              ? () => _openTeacherAssignDialog(
                                  sessionId: session.id,
                                )
                              : null,
                          canDelete: controller.isAdminLike,
                          onDelete: () => _safeCall(
                            () => controller.cancelSession(session.id),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _generateProposal() async {
    await _safeCall(
      () => widget.controller.generateProposal(_promptController.text),
    );
  }

  Future<void> _reloadProposals() async {
    await _safeCall(widget.controller.refreshAll);
  }

  Future<void> _applyProposal(String proposalId) async {
    await _safeCall(() => widget.controller.applyProposal(proposalId));
  }

  Future<void> _discardProposal(String proposalId) async {
    await _safeCall(() => widget.controller.discardProposal(proposalId));
  }

  Future<void> _openTeacherAssignDialog({required String sessionId}) async {
    final controller = widget.controller;
    String? selectedTeacherId = controller.teacherProfiles.firstOrNull?.id;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final assignmentRows = controller.teacherAssignmentsForSession(
              sessionId,
            );
            final teacherItems = controller.teacherProfiles
                .map(
                  (teacher) => DropdownMenuItem(
                    value: teacher.id,
                    child: Text(teacher.displayName),
                  ),
                )
                .toList(growable: false);

            if (selectedTeacherId == null && teacherItems.isNotEmpty) {
              selectedTeacherId = teacherItems.first.value;
            }

            return AlertDialog(
              title: const Text('교사 배정 관리'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (teacherItems.isEmpty)
                      const Text('먼저 교사 프로필을 등록하세요.')
                    else ...[
                      DropdownButtonFormField<String>(
                        initialValue: selectedTeacherId,
                        decoration: const InputDecoration(labelText: '교사 선택'),
                        items: teacherItems,
                        onChanged: controller.isBusy
                            ? null
                            : (value) {
                                setLocalState(() {
                                  selectedTeacherId = value;
                                });
                              },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton(
                            onPressed:
                                controller.isBusy || selectedTeacherId == null
                                ? null
                                : () async {
                                    await _safeCall(
                                      () => controller.assignTeacherToSession(
                                        classSessionId: sessionId,
                                        teacherProfileId: selectedTeacherId!,
                                        assignmentRole: 'MAIN',
                                      ),
                                    );
                                    if (!context.mounted) {
                                      return;
                                    }
                                    setLocalState(() {});
                                  },
                            child: const Text('주강사 지정'),
                          ),
                          FilledButton.tonal(
                            onPressed:
                                controller.isBusy || selectedTeacherId == null
                                ? null
                                : () async {
                                    await _safeCall(
                                      () => controller.assignTeacherToSession(
                                        classSessionId: sessionId,
                                        teacherProfileId: selectedTeacherId!,
                                        assignmentRole: 'ASSISTANT',
                                      ),
                                    );
                                    if (!context.mounted) {
                                      return;
                                    }
                                    setLocalState(() {});
                                  },
                            child: const Text('보조 추가'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      '현재 배정',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    if (assignmentRows.isEmpty)
                      const Text('배정된 교사가 없습니다.')
                    else
                      ...assignmentRows.map((row) {
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${row.assignmentRole == 'MAIN' ? '주강사' : '보조'} · ${controller.findTeacherName(row.teacherProfileId)}',
                          ),
                          trailing: IconButton(
                            onPressed: controller.isBusy
                                ? null
                                : () async {
                                    await _safeCall(
                                      () => controller.removeTeacherFromSession(
                                        classSessionId: sessionId,
                                        teacherProfileId: row.teacherProfileId,
                                      ),
                                    );
                                    if (!context.mounted) {
                                      return;
                                    }
                                    setLocalState(() {});
                                  },
                            icon: const Icon(Icons.close),
                          ),
                        );
                      }),
                    const SizedBox(height: 8),
                    if (controller
                        .teacherConflictMessagesForSession(sessionId)
                        .isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: controller
                            .teacherConflictMessagesForSession(sessionId)
                            .map((text) => Chip(label: Text(text)))
                            .toList(growable: false),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('닫기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _safeCall(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
    }
  }
}

class _CourseChip extends StatelessWidget {
  const _CourseChip({required this.label, this.dragging = false});

  final String label;
  final bool dragging;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: dragging
            ? NestColors.dustyRose.withValues(alpha: 0.92)
            : NestColors.roseMist,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: NestColors.dustyRose.withValues(alpha: 0.48)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: dragging ? Colors.white : NestColors.deepWood,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.title,
    required this.subtitle,
    required this.teacherBadges,
    required this.conflictMessages,
    required this.canManageTeachers,
    required this.onManageTeachers,
    required this.canDelete,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final List<String> teacherBadges;
  final List<String> conflictMessages;
  final bool canManageTeachers;
  final VoidCallback? onManageTeachers;
  final bool canDelete;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (canManageTeachers)
                IconButton(
                  onPressed: onManageTeachers,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: '교사 배정',
                ),
              if (canDelete)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (teacherBadges.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: teacherBadges
                  .map(
                    (text) => Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(text),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
          if (conflictMessages.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: conflictMessages
                  .map(
                    (text) => Chip(
                      backgroundColor: Colors.amber.shade100,
                      visualDensity: VisualDensity.compact,
                      label: Text(text),
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

String _dayLabel(int dayOfWeek) {
  const labels = <int, String>{
    0: 'Sun',
    1: 'Mon',
    2: 'Tue',
    3: 'Wed',
    4: 'Thu',
    5: 'Fri',
    6: 'Sat',
  };
  return labels[dayOfWeek] ?? '$dayOfWeek';
}

String _shortTime(String value) {
  final parsed = DateFormat('HH:mm:ss').tryParse(value);
  if (parsed == null) {
    final fallback = DateFormat('HH:mm').tryParse(value);
    return fallback == null ? value : DateFormat('HH:mm').format(fallback);
  }
  return DateFormat('HH:mm').format(parsed);
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
