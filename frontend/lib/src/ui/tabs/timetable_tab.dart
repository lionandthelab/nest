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
  final Set<int> _selectedDays = <int>{1, 2, 3, 4, 5};
  final Set<String> _preferredTeacherIds = <String>{};
  final Map<String, int> _courseWeightsById = <String, int>{};
  int _sessionsPerDay = 2;
  int _optionCount = 3;
  bool _keepExistingSessions = true;
  String _teacherStrategy = 'BALANCED';
  bool _preferOnlySelectedTeachers = false;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    _syncConciergeState(controller);
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 1180;
    final adminEditable = controller.isAdminLike;

    return ListView(
      children: [
        if (adminEditable) ...[
          _buildConciergeCard(controller),
          const SizedBox(height: 12),
          _buildScheduleDraftPanel(controller),
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

  void _syncConciergeState(NestController controller) {
    final courseIds = controller.courses.map((course) => course.id).toSet();
    _courseWeightsById.removeWhere(
      (courseId, _) => !courseIds.contains(courseId),
    );
    for (final course in controller.courses) {
      _courseWeightsById.putIfAbsent(course.id, () => 1);
    }

    final teacherIds = controller.teacherProfiles
        .map((teacher) => teacher.id)
        .toSet();
    _preferredTeacherIds.removeWhere(
      (teacherId) => !teacherIds.contains(teacherId),
    );
  }

  Widget _buildConciergeCard(NestController controller) {
    final selectedDays = _selectedDays.toList(growable: false)..sort();
    final daysLabel = selectedDays.map(_dayLabel).join(', ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule Concierge',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '몇 가지 질문에 답하면 반/교사 배정을 고려한 시간표 초안을 여러 개 제안합니다. 제안안을 보정하면 충돌 여부를 즉시 확인할 수 있습니다.',
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
                hintText: '예: 월수금 오전은 수학/국어, 화목 오후는 탐구/미술 중심',
                labelText: '운영 방향 프롬프트',
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '질문 1. 수업 요일 선택 ($daysLabel)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildDayChip(1, 'Mon'),
                _buildDayChip(2, 'Tue'),
                _buildDayChip(3, 'Wed'),
                _buildDayChip(4, 'Thu'),
                _buildDayChip(5, 'Fri'),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '질문 2. 하루 수업 수',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 1, label: Text('1교시')),
                ButtonSegment(value: 2, label: Text('2교시')),
                ButtonSegment(value: 3, label: Text('3교시')),
                ButtonSegment(value: 4, label: Text('4교시')),
              ],
              selected: {_sessionsPerDay},
              onSelectionChanged: controller.isBusy
                  ? null
                  : (values) {
                      if (values.isEmpty) {
                        return;
                      }
                      setState(() {
                        _sessionsPerDay = values.first;
                      });
                    },
            ),
            const SizedBox(height: 10),
            Text(
              '질문 3. 생성할 대안 개수',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 2, label: Text('2개')),
                ButtonSegment(value: 3, label: Text('3개')),
                ButtonSegment(value: 4, label: Text('4개')),
              ],
              selected: {_optionCount},
              onSelectionChanged: controller.isBusy
                  ? null
                  : (values) {
                      if (values.isEmpty) {
                        return;
                      }
                      setState(() {
                        _optionCount = values.first;
                      });
                    },
            ),
            const SizedBox(height: 10),
            Text(
              '질문 4. 과목 빈도 가중치',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            if (controller.courses.isEmpty)
              const Text('가중치를 조정할 과목이 없습니다.')
            else
              ...controller.courses.map((course) {
                final currentWeight = _courseWeightsById[course.id] ?? 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text(course.name)),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 1, label: Text('낮음')),
                          ButtonSegment(value: 2, label: Text('보통')),
                          ButtonSegment(value: 3, label: Text('높음')),
                        ],
                        selected: {
                          currentWeight < 1
                              ? 1
                              : (currentWeight > 3 ? 3 : currentWeight),
                        },
                        onSelectionChanged: controller.isBusy
                            ? null
                            : (values) {
                                if (values.isEmpty) {
                                  return;
                                }
                                setState(() {
                                  _courseWeightsById[course.id] = values.first;
                                });
                              },
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 10),
            Text(
              '질문 5. 교사 배정 선호',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'BALANCED', label: Text('균형')),
                ButtonSegment(value: 'PREFERRED_FIRST', label: Text('선호교사 우선')),
                ButtonSegment(value: 'PARENT_FIRST', label: Text('부모교사 우선')),
              ],
              selected: {_teacherStrategy},
              onSelectionChanged: controller.isBusy
                  ? null
                  : (values) {
                      if (values.isEmpty) {
                        return;
                      }
                      setState(() {
                        _teacherStrategy = values.first;
                      });
                    },
            ),
            const SizedBox(height: 6),
            if (controller.teacherProfiles.isEmpty)
              const Text('선택 가능한 교사가 없습니다.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: controller.teacherProfiles
                    .map((teacher) {
                      final selected = _preferredTeacherIds.contains(
                        teacher.id,
                      );
                      return FilterChip(
                        selected: selected,
                        label: Text(teacher.displayName),
                        onSelected: controller.isBusy
                            ? null
                            : (value) {
                                setState(() {
                                  if (value) {
                                    _preferredTeacherIds.add(teacher.id);
                                  } else {
                                    _preferredTeacherIds.remove(teacher.id);
                                  }
                                });
                              },
                      );
                    })
                    .toList(growable: false),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('선택한 교사만 사용'),
              subtitle: const Text('선택 교사 수가 부족하면 미배정 경고가 발생할 수 있습니다.'),
              value: _preferOnlySelectedTeachers,
              onChanged: controller.isBusy
                  ? null
                  : (value) {
                      setState(() {
                        _preferOnlySelectedTeachers = value;
                      });
                    },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('기존 시간표는 유지하고 빈 슬롯만 사용'),
              value: _keepExistingSessions,
              onChanged: controller.isBusy
                  ? null
                  : (value) {
                      setState(() {
                        _keepExistingSessions = value;
                      });
                    },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : _generateScheduleOptions,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('질문 기반 초안 생성'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy ? null : _generateProposal,
                  icon: const Icon(Icons.psychology),
                  label: const Text('기존 프롬프트 생성안 저장'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy ? null : _reloadProposals,
                  icon: const Icon(Icons.refresh),
                  label: const Text('전체 새로고침'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayChip(int day, String label) {
    return FilterChip(
      label: Text(label),
      selected: _selectedDays.contains(day),
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedDays.add(day);
            return;
          }
          if (_selectedDays.length == 1) {
            return;
          }
          _selectedDays.remove(day);
        });
      },
    );
  }

  Widget _buildScheduleDraftPanel(NestController controller) {
    final drafts = controller.scheduleOptionDrafts;
    final selectedDraft = controller.selectedScheduleOption;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('초안 대안 비교', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (drafts.isEmpty)
              const Text('질문 기반 생성 버튼을 눌러 초안을 만드세요.')
            else ...[
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: drafts
                    .map(
                      (draft) => Container(
                        width: 240,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selectedDraft?.id == draft.id
                              ? NestColors.roseMist.withValues(alpha: 0.45)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selectedDraft?.id == draft.id
                                ? NestColors.clay
                                : NestColors.roseMist,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              draft.label,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${draft.sessions.length}세션 · 하드충돌 ${draft.hardConflictCount} · 경고 ${draft.warningCount}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton.tonal(
                                  onPressed: controller.isBusy
                                      ? null
                                      : () => controller
                                            .selectScheduleOptionDraft(
                                              draft.id,
                                            ),
                                  child: const Text('선택'),
                                ),
                                ElevatedButton(
                                  onPressed: controller.isBusy
                                      ? null
                                      : () => _applyScheduleOption(draft.id),
                                  child: const Text('적용'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              if (selectedDraft != null) ...[
                const SizedBox(height: 12),
                _buildDraftEditor(controller, selectedDraft),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDraftEditor(
    NestController controller,
    ScheduleOptionDraft draft,
  ) {
    final slotItems = controller.timeSlots.toList(growable: false)
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) {
          return day;
        }
        return a.startTime.compareTo(b.startTime);
      });

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('선택 초안 보정', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (draft.sessions.isEmpty)
            const Text('세션이 없습니다.')
          else
            ...draft.sessions.map((session) {
              final sessionIssues = draft.issues
                  .where((issue) => issue.sessionLocalId == session.localId)
                  .toList(growable: false);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sessionIssues.any((issue) => issue.isHard)
                          ? Colors.red.shade300
                          : NestColors.roseMist,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.localId,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: controller.isBusy
                                ? null
                                : () => controller.removeScheduleOptionSession(
                                    optionId: draft.id,
                                    sessionLocalId: session.localId,
                                  ),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue:
                            controller.courses.any(
                              (course) => course.id == session.courseId,
                            )
                            ? session.courseId
                            : null,
                        decoration: const InputDecoration(labelText: '과목'),
                        items: controller.courses
                            .map(
                              (course) => DropdownMenuItem(
                                value: course.id,
                                child: Text(course.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: controller.isBusy
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                controller.updateScheduleOptionSession(
                                  optionId: draft.id,
                                  sessionLocalId: session.localId,
                                  courseId: value,
                                );
                              },
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue:
                            slotItems.any(
                              (slot) => slot.id == session.timeSlotId,
                            )
                            ? session.timeSlotId
                            : null,
                        decoration: const InputDecoration(labelText: '시간 슬롯'),
                        items: slotItems
                            .map(
                              (slot) => DropdownMenuItem(
                                value: slot.id,
                                child: Text(
                                  '${_dayLabel(slot.dayOfWeek)} ${_shortTime(slot.startTime)}-${_shortTime(slot.endTime)}',
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: controller.isBusy
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                controller.updateScheduleOptionSession(
                                  optionId: draft.id,
                                  sessionLocalId: session.localId,
                                  timeSlotId: value,
                                );
                              },
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue:
                            session.teacherMainId != null &&
                                controller.teacherProfiles.any(
                                  (teacher) =>
                                      teacher.id == session.teacherMainId,
                                )
                            ? session.teacherMainId
                            : '__NONE__',
                        decoration: const InputDecoration(labelText: '주강사'),
                        items: [
                          const DropdownMenuItem(
                            value: '__NONE__',
                            child: Text('미지정'),
                          ),
                          ...controller.teacherProfiles.map(
                            (teacher) => DropdownMenuItem(
                              value: teacher.id,
                              child: Text(teacher.displayName),
                            ),
                          ),
                        ],
                        onChanged: controller.isBusy
                            ? null
                            : (value) {
                                if (value == null) {
                                  return;
                                }
                                controller.updateScheduleOptionSession(
                                  optionId: draft.id,
                                  sessionLocalId: session.localId,
                                  teacherMainId: value == '__NONE__'
                                      ? null
                                      : value,
                                  clearTeacherMainId: value == '__NONE__',
                                );
                              },
                      ),
                      if (sessionIssues.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: sessionIssues
                              .map(
                                (issue) => Chip(
                                  backgroundColor: issue.isHard
                                      ? Colors.red.shade50
                                      : Colors.amber.shade100,
                                  label: Text(issue.message),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: controller.isBusy
                    ? null
                    : () => controller.addScheduleOptionSession(draft.id),
                icon: const Icon(Icons.add),
                label: const Text('세션 추가'),
              ),
              ElevatedButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () => _applyScheduleOption(draft.id),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('이 초안 적용'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (draft.issues.isEmpty)
            const Text('충돌 없음. 적용 가능한 초안입니다.')
          else
            Text(
              '충돌 점검: 하드 ${draft.hardConflictCount}건, 경고 ${draft.warningCount}건',
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
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
            Builder(
              builder: (context) {
                final issues = controller.timetableBoardIssueMessages();
                if (issues.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: const Text('현재 시간표 충돌 없음'),
                  );
                }
                return Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.amber.shade50,
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('충돌/경고 ${issues.length}건'),
                      const SizedBox(height: 6),
                      ...issues
                          .take(5)
                          .map(
                            (text) => Text(
                              '• $text',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            if (controller.courses.isEmpty)
              const Text('과목이 없습니다. Term Setup에서 과목을 추가하세요.')
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
              const Text('시간 슬롯이 없습니다. Dashboard 빠른 초기 세팅을 먼저 진행하세요.')
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

  Future<void> _generateScheduleOptions() async {
    await _safeCall(() {
      return widget.controller.generateScheduleOptions(
        prompt: _promptController.text,
        preferredDays: _selectedDays,
        sessionsPerDay: _sessionsPerDay,
        courseWeightsById: _courseWeightsById,
        preferredTeacherIds: _preferredTeacherIds,
        teacherStrategy: _teacherStrategy,
        preferOnlySelectedTeachers: _preferOnlySelectedTeachers,
        optionCount: _optionCount,
        keepExistingSessions: _keepExistingSessions,
      );
    });
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

  Future<void> _applyScheduleOption(String optionId) async {
    await _safeCall(() => widget.controller.applyScheduleOptionDraft(optionId));
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
