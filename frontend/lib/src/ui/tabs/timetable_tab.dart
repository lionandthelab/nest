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

    return ListView(
      children: [
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
        compact
            ? Column(
                children: [
                  _buildProposalPanel(controller),
                  const SizedBox(height: 12),
                  _buildBoardPanel(controller),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 2, child: _buildProposalPanel(controller)),
                  const SizedBox(width: 12),
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
            else
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
    required this.canDelete,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.close, size: 18),
              visualDensity: VisualDensity.compact,
            ),
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
