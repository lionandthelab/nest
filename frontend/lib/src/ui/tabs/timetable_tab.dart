import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/download_helper.dart';
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
  final _timetableRepaintKey = GlobalKey();
  final Set<int> _selectedDays = <int>{1, 2, 3, 4, 5};
  final Set<String> _preferredTeacherIds = <String>{};
  final Map<String, int> _courseWeightsById = <String, int>{};
  int _wizardStep = 0;
  int _sessionsPerDay = 2;
  int _optionCount = 3;
  bool _keepExistingSessions = true;
  String _teacherStrategy = 'BALANCED';
  bool _preferOnlySelectedTeachers = false;
  String _statusPanelMode = 'CLASS';

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
    final compact = width < 1200;
    final adminEditable = controller.isAdminLike;

    return ListView(
      children: [
        if (!adminEditable) ...[
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
        // Timetable grid is always first (main focus).
        if (adminEditable && !compact)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: _buildBoardPanel(controller, onOpenStatusPanel: null),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 360,
                child: Column(
                  children: [
                    _buildStatusInsightPanel(controller),
                    const SizedBox(height: 12),
                    _buildProposalPanel(controller),
                  ],
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildBoardPanel(
                controller,
                onOpenStatusPanel: adminEditable
                    ? () => _openStatusPanelSheet(controller)
                    : null,
              ),
              if (adminEditable) ...[
                const SizedBox(height: 12),
                _buildProposalPanel(controller),
              ],
            ],
          ),
      ],
    );
  }

  void _openWizardModal(NestController controller) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: NestColors.creamyWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return AnimatedBuilder(
                  animation: controller,
                  builder: (context, _) {
                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: NestColors.deepWood.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        _buildConciergeCard(controller),
                        const SizedBox(height: 12),
                        _buildScheduleDraftPanel(controller),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _exportTimetableImage() async {
    final boundary = _timetableRepaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();
    final helper = createDownloadHelper();
    helper.downloadBytes(
      bytes: bytes,
      filename: 'timetable_${DateTime.now().millisecondsSinceEpoch}.png',
      mimeType: 'image/png',
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
    final steps = const ['기본 설정', '리소스 조건', '생성/검토'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('초안 위자드', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '질문 순서대로 답하면 반/선생님 조건을 반영한 시간표 초안을 자동 생성합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(steps.length, (index) {
                final selected = _wizardStep == index;
                return ChoiceChip(
                  selected: selected,
                  label: Text('${index + 1}. ${steps[index]}'),
                  onSelected: controller.isBusy
                      ? null
                      : (_) {
                          setState(() {
                            _wizardStep = index;
                          });
                        },
                );
              }),
            ),
            const SizedBox(height: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey<int>(_wizardStep),
                child: _buildWizardStepBody(
                  controller: controller,
                  daysLabel: daysLabel,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy || _wizardStep == 0
                      ? null
                      : () {
                          setState(() {
                            _wizardStep = _wizardStep - 1;
                          });
                        },
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('이전'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy || _wizardStep == 2
                      ? null
                      : () {
                          setState(() {
                            _wizardStep = _wizardStep + 1;
                          });
                        },
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('다음'),
                ),
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

  Widget _buildWizardStepBody({
    required NestController controller,
    required String daysLabel,
  }) {
    switch (_wizardStep) {
      case 0:
        return Column(
          key: const ValueKey<String>('wizard-step-0'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
          ],
        );
      case 1:
        return Column(
          key: const ValueKey<String>('wizard-step-1'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '질문 3. 과목 빈도 가중치',
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
              '질문 4. 교사 배정 선호',
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
          ],
        );
      default:
        return Column(
          key: const ValueKey<String>('wizard-step-2'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '질문 5. 생성할 대안 개수',
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
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: NestColors.creamyWhite,
                border: Border.all(color: NestColors.roseMist),
              ),
              child: Text(
                '현재 설정으로 $_optionCount개의 시간표 초안을 만듭니다. 생성 후 아래 대안 비교에서 바로 적용/보정하세요.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        );
    }
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

  Widget _buildPromptActionBar(NestController controller) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.creamyWhite,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 860;
          final textField = TextField(
            controller: _promptController,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '프롬프트 수정',
              hintText: '예: 3교시는 예체능 위주로 재배치해줘',
            ),
          );
          final actions = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: controller.isBusy ? null : _generateScheduleOptions,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('프롬프트로 초안 생성'),
              ),
              FilledButton.tonalIcon(
                onPressed: controller.isBusy ? null : _generateProposal,
                icon: const Icon(Icons.psychology),
                label: const Text('생성안 저장'),
              ),
              FilledButton.tonalIcon(
                onPressed: controller.isBusy
                    ? null
                    : () => _openWizardModal(controller),
                icon: const Icon(Icons.assistant_navigation),
                label: const Text('위자드 열기'),
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                textField,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: actions),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: textField),
              const SizedBox(width: 10),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusInsightPanel(NestController controller) {
    final classId = controller.selectedClassGroupId;
    final issueRows = controller.timetableBoardIssueMessages();
    final parentBlocked = issueRows
        .where((row) => row.contains('부모 불가 시간대'))
        .length;
    final teacherBlocked = issueRows
        .where((row) => row.contains('불가 시간대 배정'))
        .length;
    final teacherConflicts = issueRows
        .where((row) => row.contains('시간충돌'))
        .length;

    final missingMain = controller.sessions
        .where(
          (session) => !controller
              .teacherAssignmentsForSession(session.id)
              .any((row) => row.assignmentRole == 'MAIN'),
        )
        .length;

    final enrolledChildren = classId == null
        ? 0
        : controller.enrolledChildIdsForClassGroup(classId).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('상황 패널', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '반/교사 상태를 즉시 확인하면서 시간표를 보정하세요.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'CLASS', label: Text('반 상태')),
                ButtonSegment(value: 'TEACHER', label: Text('교사 상태')),
              ],
              selected: {_statusPanelMode},
              onSelectionChanged: (values) {
                if (values.isEmpty) {
                  return;
                }
                setState(() {
                  _statusPanelMode = values.first;
                });
              },
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: _statusPanelMode == 'CLASS'
                  ? _buildClassStatusPanelContent(
                      controller: controller,
                      className: controller.findClassGroupName(classId),
                      enrolledChildren: enrolledChildren,
                      missingMain: missingMain,
                      parentBlocked: parentBlocked,
                      teacherBlocked: teacherBlocked,
                      teacherConflicts: teacherConflicts,
                      issueRows: issueRows,
                    )
                  : _buildTeacherStatusPanelContent(controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassStatusPanelContent({
    required NestController controller,
    required String className,
    required int enrolledChildren,
    required int missingMain,
    required int parentBlocked,
    required int teacherBlocked,
    required int teacherConflicts,
    required List<String> issueRows,
  }) {
    return Column(
      key: const ValueKey<String>('status-class'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _statusMetricTile('현재 반', className, Icons.groups_2_outlined),
        const SizedBox(height: 8),
        _statusMetricTile(
          '반 편성',
          '아이 $enrolledChildren명 · 수업 ${controller.sessions.length}개',
          Icons.dataset_outlined,
        ),
        const SizedBox(height: 8),
        _statusMetricTile(
          '리스크',
          '주강사 미지정 $missingMain, 교사충돌 $teacherConflicts',
          Icons.warning_amber_outlined,
        ),
        const SizedBox(height: 8),
        _statusMetricTile(
          '제약 충돌',
          '부모불가 $parentBlocked, 교사불가 $teacherBlocked',
          Icons.rule_outlined,
        ),
        const SizedBox(height: 10),
        Text('최근 경고', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        if (issueRows.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Text('현재 감지된 충돌이 없습니다.'),
          )
        else
          ...issueRows
              .take(6)
              .map(
                (row) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '• $row',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildTeacherStatusPanelContent(NestController controller) {
    final rows = _buildTeacherStatusRows(controller);

    return Column(
      key: const ValueKey<String>('status-teacher'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rows.isEmpty)
          const Text('현재 반에 배정된 교사 정보가 없습니다.')
        else
          ...rows.map((row) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NestColors.roseMist),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.teacherName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '주강사 ${row.mainCount} · 보조 ${row.assistantCount} · 총 ${row.totalCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '시간충돌 ${row.conflictCount} · 불가시간 배정 ${row.blockedCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  List<_TeacherStatusRow> _buildTeacherStatusRows(NestController controller) {
    final sessionMap = {
      for (final session in controller.sessions) session.id: session,
    };
    if (sessionMap.isEmpty) {
      return const [];
    }

    final blockedByTeacher = controller.blockedSlotIdsByTeacherProfile();
    final rowsByTeacher = <String, _TeacherStatusRow>{};

    for (final assignment in controller.sessionTeacherAssignments) {
      final session = sessionMap[assignment.classSessionId];
      if (session == null) {
        continue;
      }

      final teacherId = assignment.teacherProfileId;
      final current =
          rowsByTeacher[teacherId] ??
          _TeacherStatusRow(
            teacherId: teacherId,
            teacherName: controller.findTeacherName(teacherId),
            mainCount: 0,
            assistantCount: 0,
            totalCount: 0,
            conflictCount: 0,
            blockedCount: 0,
          );

      final updated = current.copyWith(
        mainCount: assignment.assignmentRole == 'MAIN'
            ? current.mainCount + 1
            : current.mainCount,
        assistantCount: assignment.assignmentRole == 'ASSISTANT'
            ? current.assistantCount + 1
            : current.assistantCount,
        totalCount: current.totalCount + 1,
      );
      rowsByTeacher[teacherId] = updated;
    }

    final conflictSlotsByTeacher = <String, Set<String>>{};
    for (final teacherId in rowsByTeacher.keys) {
      final slots = <String, int>{};
      for (final assignment in controller.sessionTeacherAssignments.where(
        (row) => row.teacherProfileId == teacherId,
      )) {
        final session = sessionMap[assignment.classSessionId];
        if (session == null) {
          continue;
        }
        slots[session.timeSlotId] = (slots[session.timeSlotId] ?? 0) + 1;
      }
      conflictSlotsByTeacher[teacherId] = slots.entries
          .where((entry) => entry.value > 1)
          .map((entry) => entry.key)
          .toSet();
    }

    for (final teacherId in rowsByTeacher.keys.toList(growable: false)) {
      final assignedSessions = controller.sessionTeacherAssignments.where(
        (row) => row.teacherProfileId == teacherId,
      );
      var blockedCount = 0;
      for (final assignment in assignedSessions) {
        final session = sessionMap[assignment.classSessionId];
        if (session == null) {
          continue;
        }
        if (blockedByTeacher[teacherId]?.contains(session.timeSlotId) == true) {
          blockedCount += 1;
        }
      }

      final conflictCount = conflictSlotsByTeacher[teacherId]?.length ?? 0;
      rowsByTeacher[teacherId] = rowsByTeacher[teacherId]!.copyWith(
        conflictCount: conflictCount,
        blockedCount: blockedCount,
      );
    }

    final rows = rowsByTeacher.values.toList(growable: false)
      ..sort((a, b) {
        final riskA = a.conflictCount + a.blockedCount;
        final riskB = b.conflictCount + b.blockedCount;
        if (riskA != riskB) {
          return riskB.compareTo(riskA);
        }
        return a.teacherName.compareTo(b.teacherName);
      });
    return rows;
  }

  Widget _statusMetricTile(String title, String value, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStatusPanelSheet(NestController controller) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: SingleChildScrollView(
              child: _buildStatusInsightPanel(controller),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBoardPanel(
    NestController controller, {
    required VoidCallback? onOpenStatusPanel,
  }) {
    final sortedSlots = controller.timeSlots.toList(growable: false)
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) {
          return day;
        }
        return a.startTime.compareTo(b.startTime);
      });
    final slotsByDay = <int, List<TimeSlot>>{};
    for (final slot in sortedSlots) {
      slotsByDay.putIfAbsent(slot.dayOfWeek, () => <TimeSlot>[]);
      slotsByDay[slot.dayOfWeek]!.add(slot);
    }
    final dayOrder = slotsByDay.keys.toList(growable: false)..sort();
    var maxPeriods = 0;
    for (final rows in slotsByDay.values) {
      if (rows.length > maxPeriods) {
        maxPeriods = rows.length;
      }
    }
    final narrow = MediaQuery.sizeOf(context).width < 1120;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '시간표 메인 보드',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    controller.isAdminLike ? 'EDIT MODE' : 'READ ONLY',
                  ),
                ),
                const Spacer(),
                if (controller.isAdminLike) ...[
                  FilledButton.tonalIcon(
                    onPressed: controller.isBusy
                        ? null
                        : () => _openWizardModal(controller),
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('초안 위자드'),
                  ),
                  const SizedBox(width: 8),
                ],
                FilledButton.tonalIcon(
                  onPressed: _exportTimetableImage,
                  icon: const Icon(Icons.image_outlined),
                  label: const Text('내보내기'),
                ),
                if (onOpenStatusPanel != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: onOpenStatusPanel,
                    icon: const Icon(Icons.tune),
                    label: const Text('반/교사 현황'),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '과목을 시간표 셀로 드래그해 배치하고, 수업 카드를 다른 셀로 이동해 즉시 수정하세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            _buildPromptActionBar(controller),
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
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('충돌/경고 ${issues.length}건'),
                      const SizedBox(height: 6),
                      ...issues
                          .take(6)
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
            if (sortedSlots.isEmpty)
              const Text('시간 슬롯이 없습니다. Dashboard 빠른 초기 세팅을 먼저 진행하세요.')
            else if (dayOrder.isEmpty || maxPeriods == 0)
              const Text('시간표를 표시할 수 있는 슬롯 구성이 없습니다.')
            else if (narrow)
              Column(
                children: [
                  if (controller.isAdminLike) ...[
                    _buildCoursePalette(controller),
                    const SizedBox(height: 12),
                  ],
                  _buildVisualTimetableGrid(
                    controller: controller,
                    dayOrder: dayOrder,
                    slotsByDay: slotsByDay,
                    maxPeriods: maxPeriods,
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (controller.isAdminLike) ...[
                    SizedBox(
                      width: 260,
                      child: _buildCoursePalette(controller),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: _buildVisualTimetableGrid(
                      controller: controller,
                      dayOrder: dayOrder,
                      slotsByDay: slotsByDay,
                      maxPeriods: maxPeriods,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoursePalette(NestController controller) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('과목 팔레트', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            '과목을 시간표 셀로 길게 눌러 드래그하세요.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          if (controller.courses.isEmpty)
            const Text('과목이 없습니다. Term Setup에서 과목을 추가하세요.')
          else
            SizedBox(
              height: 520,
              child: SingleChildScrollView(
                child: Wrap(
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
                              label:
                                  '${course.name} ${course.defaultDurationMin}m',
                              dragging: true,
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.35,
                            child: _CourseChip(
                              label:
                                  '${course.name} ${course.defaultDurationMin}m',
                            ),
                          ),
                          child: _CourseChip(
                            label:
                                '${course.name} ${course.defaultDurationMin}m',
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVisualTimetableGrid({
    required NestController controller,
    required List<int> dayOrder,
    required Map<int, List<TimeSlot>> slotsByDay,
    required int maxPeriods,
  }) {
    const periodWidth = 120.0;
    const dayColumnWidth = 238.0;
    var minWidth = periodWidth + (dayOrder.length * dayColumnWidth);
    if (minWidth < 940) {
      minWidth = 940;
    }

    return RepaintBoundary(
      key: _timetableRepaintKey,
      child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: minWidth,
          child: Column(
            children: [
              Row(
                children: [
                  _GridHeaderCell(
                    width: periodWidth,
                    title: '교시',
                    subtitle: '시간',
                  ),
                  ...dayOrder.map(
                    (day) => _GridHeaderCell(
                      width: dayColumnWidth,
                      title: _dayLabel(day),
                      subtitle: '$day요일',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...List.generate(maxPeriods, (periodIndex) {
                TimeSlot? fallbackSlot;
                for (final day in dayOrder) {
                  final rows = slotsByDay[day] ?? const <TimeSlot>[];
                  if (periodIndex < rows.length) {
                    fallbackSlot = rows[periodIndex];
                    break;
                  }
                }

                final timeLabel = fallbackSlot == null
                    ? '-'
                    : '${_shortTime(fallbackSlot.startTime)}-${_shortTime(fallbackSlot.endTime)}';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: periodWidth,
                        constraints: const BoxConstraints(minHeight: 170),
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: NestColors.creamyWhite,
                          border: Border.all(color: NestColors.roseMist),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${periodIndex + 1}교시',
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              timeLabel,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      ...dayOrder.map((day) {
                        final rows = slotsByDay[day] ?? const <TimeSlot>[];
                        final slot = periodIndex < rows.length
                            ? rows[periodIndex]
                            : null;
                        if (slot == null) {
                          return Container(
                            width: dayColumnWidth,
                            constraints: const BoxConstraints(minHeight: 170),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.grey.shade100,
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Center(
                              child: Text(
                                '해당 슬롯 없음',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          );
                        }

                        final slotSessions = controller.sessionsForSlot(
                          slot.id,
                        );
                        return Container(
                          width: dayColumnWidth,
                          constraints: const BoxConstraints(minHeight: 170),
                          margin: const EdgeInsets.only(right: 6),
                          child: _TimetableGridSlotCell(
                            controller: controller,
                            slot: slot,
                            sessions: slotSessions,
                            onManageTeachers: _openTeacherAssignDialog,
                            onCreateOrMove: (payload) async {
                              if (payload.type == DragPayloadType.course) {
                                await _safeCall(() {
                                  return controller.createSessionByCourse(
                                    courseId: payload.id,
                                    slotId: slot.id,
                                  );
                                });
                                return;
                              }

                              await _safeCall(() {
                                return controller.moveSession(
                                  sessionId: payload.id,
                                  targetSlotId: slot.id,
                                );
                              });
                            },
                            onDeleteSession: (sessionId) async {
                              await _safeCall(
                                () => controller.cancelSession(sessionId),
                              );
                            },
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    ));
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

class _TeacherStatusRow {
  const _TeacherStatusRow({
    required this.teacherId,
    required this.teacherName,
    required this.mainCount,
    required this.assistantCount,
    required this.totalCount,
    required this.conflictCount,
    required this.blockedCount,
  });

  final String teacherId;
  final String teacherName;
  final int mainCount;
  final int assistantCount;
  final int totalCount;
  final int conflictCount;
  final int blockedCount;

  _TeacherStatusRow copyWith({
    int? mainCount,
    int? assistantCount,
    int? totalCount,
    int? conflictCount,
    int? blockedCount,
  }) {
    return _TeacherStatusRow(
      teacherId: teacherId,
      teacherName: teacherName,
      mainCount: mainCount ?? this.mainCount,
      assistantCount: assistantCount ?? this.assistantCount,
      totalCount: totalCount ?? this.totalCount,
      conflictCount: conflictCount ?? this.conflictCount,
      blockedCount: blockedCount ?? this.blockedCount,
    );
  }
}

class _GridHeaderCell extends StatelessWidget {
  const _GridHeaderCell({
    required this.width,
    required this.title,
    required this.subtitle,
  });

  final double width;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.roseMist.withValues(alpha: 0.72),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TimetableGridSlotCell extends StatelessWidget {
  const _TimetableGridSlotCell({
    required this.controller,
    required this.slot,
    required this.sessions,
    required this.onCreateOrMove,
    required this.onManageTeachers,
    required this.onDeleteSession,
  });

  final NestController controller;
  final TimeSlot slot;
  final List<ClassSession> sessions;
  final Future<void> Function(DragPayload payload) onCreateOrMove;
  final Future<void> Function({required String sessionId}) onManageTeachers;
  final Future<void> Function(String sessionId) onDeleteSession;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (_) =>
          controller.isAdminLike && !controller.isBusy,
      onAcceptWithDetails: (details) async {
        await onCreateOrMove(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: hovering
                ? NestColors.roseMist.withValues(alpha: 0.6)
                : Colors.white,
            border: Border.all(
              color: hovering ? NestColors.clay : NestColors.roseMist,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_shortTime(slot.startTime)}-${_shortTime(slot.endTime)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.75),
                ),
              ),
              const SizedBox(height: 8),
              if (sessions.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: NestColors.creamyWhite,
                    border: Border.all(color: NestColors.roseMist),
                  ),
                  child: Text(
                    controller.isAdminLike ? '과목을 드래그해 배치' : '배정된 수업 없음',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                )
              else
                ...sessions.map((session) {
                  final title = session.title.isEmpty
                      ? controller.findCourseName(session.courseId)
                      : session.title;
                  final subtitle =
                      '${controller.findCourseName(session.courseId)} · ${session.sourceType}';
                  final teacherBadges = controller
                      .teacherAssignmentsForSession(session.id)
                      .map(
                        (row) =>
                            '${row.assignmentRole == 'MAIN' ? '주' : '보조'} ${controller.findTeacherName(row.teacherProfileId)}',
                      )
                      .toList(growable: false);
                  final conflicts = controller
                      .teacherConflictMessagesForSession(session.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LongPressDraggable<DragPayload>(
                      data: DragPayload(
                        type: DragPayloadType.session,
                        id: session.id,
                      ),
                      feedback: Material(
                        color: Colors.transparent,
                        child: _SessionCard(
                          title: title,
                          subtitle: subtitle,
                          teacherBadges: teacherBadges,
                          conflictMessages: conflicts,
                          canManageTeachers: false,
                          onManageTeachers: null,
                          canDelete: false,
                          onDelete: null,
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.38,
                        child: _GridSessionTile(
                          title: title,
                          subtitle: subtitle,
                          teacherBadges: teacherBadges,
                          conflictMessages: conflicts,
                          canManageTeachers: false,
                          onManageTeachers: null,
                          canDelete: false,
                          onDelete: null,
                        ),
                      ),
                      child: _GridSessionTile(
                        title: title,
                        subtitle: subtitle,
                        teacherBadges: teacherBadges,
                        conflictMessages: conflicts,
                        canManageTeachers:
                            controller.canManageTeacherAssignments,
                        onManageTeachers: controller.canManageTeacherAssignments
                            ? () => onManageTeachers(sessionId: session.id)
                            : null,
                        canDelete: controller.isAdminLike,
                        onDelete: () => onDeleteSession(session.id),
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

class _GridSessionTile extends StatelessWidget {
  const _GridSessionTile({
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
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (canManageTeachers)
                IconButton(
                  onPressed: onManageTeachers,
                  icon: const Icon(Icons.person_add_alt_1, size: 16),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  tooltip: '교사 배정',
                ),
              if (canDelete)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close, size: 16),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(4),
                  tooltip: '세션 삭제',
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (teacherBadges.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: teacherBadges
                  .map(
                    (badge) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: NestColors.creamyWhite,
                        border: Border.all(color: NestColors.roseMist),
                      ),
                      child: Text(
                        badge,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
                    (text) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        text,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
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
