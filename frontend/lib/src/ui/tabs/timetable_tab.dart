import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/download_helper.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/search_select_field.dart';

class TimetableTab extends StatefulWidget {
  const TimetableTab({
    super.key,
    required this.controller,
    this.onDirtyChanged,
  });

  final NestController controller;
  final ValueChanged<bool>? onDirtyChanged;

  @override
  State<TimetableTab> createState() => _TimetableTabState();
}

class _TimetableTabState extends State<TimetableTab> {
  final _timetableRepaintKey = GlobalKey();
  final _timetableExportRepaintKey = GlobalKey();
  final _roomUtilizationRepaintKey = GlobalKey();

  String? _draftClassGroupId;
  String _controllerSignature = '';
  bool _isDraftDirty = false;
  bool _isApplyingDraft = false;
  bool _paletteOpen = true;

  List<_EditableSession> _draftSessions = const [];
  Map<String, List<_EditableAssignment>> _draftAssignments = const {};
  Set<String> _roomPalette = const {};

  @override
  void dispose() {
    widget.onDirtyChanged?.call(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    _syncDraftWithController(controller);

    if (!controller.isAdminLike) {
      return _buildReadOnlyView(controller);
    }

    return ListView(
      children: [
        _buildClassContextCard(controller),
        const SizedBox(height: 12),
        _buildBoardCard(controller),
      ],
    );
  }

  Widget _buildReadOnlyView(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('시간표', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '현재 뷰에서는 열람만 가능합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            _buildReadOnlyGrid(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildClassContextCard(NestController controller) {
    final classGroups = controller.classGroups.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    final selectedClassId = controller.selectedClassGroupId;
    final selectedClass = classGroups
        .where((row) => row.id == selectedClassId)
        .firstOrNull;

    final sessionCount = _draftSessions.length;
    final teacherCount = _draftAssignments.values
        .expand((rows) => rows)
        .map((row) => row.teacherProfileId)
        .toSet()
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '시간표 관리',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy
                      ? null
                      : _openTimetableExportDialog,
                  icon: const Icon(Icons.image_outlined, size: 18),
                  label: const Text('시간표 내보내기'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '반을 전환하면 해당 반 시간표를 바로 편집할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            SelectFieldCard(
              label: '편집 중인 반',
              hintText: '반 선택',
              icon: Icons.groups_2_outlined,
              enabled: !controller.isBusy,
              value: selectedClass?.name,
              helpText: selectedClass == null
                  ? '반을 선택하세요.'
                  : '수업 $sessionCount개 · 배정 교사 $teacherCount명',
              onTap: () => _openClassPicker(controller, classGroups),
            ),
            if (classGroups.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: classGroups
                    .take(8)
                    .map(
                      (group) => ChoiceChip(
                        label: Text(group.name),
                        selected: group.id == selectedClassId,
                        onSelected: controller.isBusy
                            ? null
                            : (_) => _switchClassGroup(controller, group.id),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBoardCard(NestController controller) {
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
    for (final slots in slotsByDay.values) {
      if (slots.length > maxPeriods) {
        maxPeriods = slots.length;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final compact = headerConstraints.maxWidth < 600;
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '시간표 메인 보드',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _paletteOpen
                                  ? Icons.view_sidebar_outlined
                                  : Icons.view_sidebar,
                            ),
                            tooltip: _paletteOpen ? '팔레트 접기' : '팔레트 열기',
                            onPressed: () =>
                                setState(() => _paletteOpen = !_paletteOpen),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: !_isDraftDirty ||
                                    controller.isBusy ||
                                    _isApplyingDraft
                                ? null
                                : _commitDraftChanges,
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('수정 확정'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: controller.isBusy || _isApplyingDraft
                                ? null
                                : () => _openRoomUtilizationExportDialog(
                                    controller),
                            icon: const Icon(Icons.meeting_room_outlined, size: 18),
                            label: const Text('교실 상황표 내보내기'),
                          ),
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        '시간표 메인 보드',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed:
                          !_isDraftDirty || controller.isBusy || _isApplyingDraft
                          ? null
                          : _commitDraftChanges,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('수정 확정'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy || _isApplyingDraft
                          ? null
                          : () => _openRoomUtilizationExportDialog(controller),
                      icon: const Icon(Icons.meeting_room_outlined),
                      label: const Text('교실 상황표 내보내기'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _paletteOpen
                            ? Icons.view_sidebar_outlined
                            : Icons.view_sidebar,
                      ),
                      tooltip: _paletteOpen ? '팔레트 접기' : '팔레트 열기',
                      onPressed: () =>
                          setState(() => _paletteOpen = !_paletteOpen),
                    ),
                  ],
                );
              },
            ),
            if (_isApplyingDraft) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 6),
            if (sortedSlots.isEmpty)
              const Text('시간 슬롯이 없습니다. Dashboard에서 초기 세팅을 먼저 진행하세요.')
            else if (dayOrder.isEmpty || maxPeriods == 0)
              const Text('시간표를 표시할 수 있는 슬롯 구성이 없습니다.')
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final showSidePalette =
                      _paletteOpen && constraints.maxWidth >= 1220;
                  if (showSidePalette) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 290,
                          child: _buildPalettePanel(controller),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildEditableGrid(
                            controller: controller,
                            dayOrder: dayOrder,
                            slotsByDay: slotsByDay,
                            maxPeriods: maxPeriods,
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    children: [
                      if (_paletteOpen) ...[
                        _buildPalettePanel(controller),
                        const SizedBox(height: 12),
                      ],
                      _buildEditableGrid(
                        controller: controller,
                        dayOrder: dayOrder,
                        slotsByDay: slotsByDay,
                        maxPeriods: maxPeriods,
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTimetableExportDialog() async {
    final controller = widget.controller;
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
    for (final slots in slotsByDay.values) {
      if (slots.length > maxPeriods) {
        maxPeriods = slots.length;
      }
    }

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('시간표 이미지 내보내기'),
          content: SizedBox(
            width: 1280,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child:
                    sortedSlots.isEmpty || dayOrder.isEmpty || maxPeriods == 0
                    ? Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: NestColors.creamyWhite,
                          border: Border.all(color: NestColors.roseMist),
                        ),
                        child: const Text('내보낼 시간표 데이터가 없습니다.'),
                      )
                    : _buildEditableGrid(
                        controller: controller,
                        dayOrder: dayOrder,
                        slotsByDay: slotsByDay,
                        maxPeriods: maxPeriods,
                        forExport: true,
                        repaintKey: _timetableExportRepaintKey,
                      ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            ElevatedButton.icon(
              onPressed: sortedSlots.isEmpty ? null : _exportTimetableImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('PNG 저장'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openRoomUtilizationExportDialog(
    NestController controller,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('교실 배정 상황표'),
          content: SizedBox(
            width: 1280,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: RepaintBoundary(
                  key: _roomUtilizationRepaintKey,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildRoomUtilizationBoard(
                      controller: controller,
                      forExport: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
            ElevatedButton.icon(
              onPressed: _exportRoomUtilizationImage,
              icon: const Icon(Icons.image_outlined),
              label: const Text('PNG 저장'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoomUtilizationBoard({
    required NestController controller,
    required bool forExport,
  }) {
    final sortedSlots = controller.timeSlots.toList(growable: false)
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) {
          return day;
        }
        return a.startTime.compareTo(b.startTime);
      });

    if (sortedSlots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: NestColors.creamyWhite,
          border: Border.all(color: NestColors.roseMist),
        ),
        child: const Text('시간 슬롯이 없습니다.'),
      );
    }

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

    final sessionsBySlotId = <String, List<ClassSession>>{};
    for (final session in controller.allTermSessions) {
      sessionsBySlotId.putIfAbsent(session.timeSlotId, () => <ClassSession>[]);
      sessionsBySlotId[session.timeSlotId]!.add(session);
    }
    for (final rows in sessionsBySlotId.values) {
      rows.sort((a, b) {
        final leftLocation = (a.location ?? '').trim();
        final rightLocation = (b.location ?? '').trim();
        final locationOrder = leftLocation.compareTo(rightLocation);
        if (locationOrder != 0) {
          return locationOrder;
        }
        return controller
            .findClassGroupName(a.classGroupId)
            .compareTo(controller.findClassGroupName(b.classGroupId));
      });
    }

    const periodWidth = 112.0;
    const gap = 6.0;
    const targetExportWidth = 1260.0;
    final baseDayWidth = dayOrder.isEmpty
        ? 210.0
        : ((targetExportWidth - periodWidth - (dayOrder.length + 1) * gap) /
                  dayOrder.length)
              .clamp(145.0, 220.0);
    final dayWidth = forExport ? baseDayWidth : 220.0;
    final boardWidth =
        periodWidth +
        (dayOrder.length * dayWidth) +
        (dayOrder.length + 1) * gap;
    final boardPadding = forExport ? 18.0 : 10.0;
    final renderWidth = forExport ? boardWidth + (boardPadding * 2) : null;

    return Container(
      width: renderWidth,
      padding: EdgeInsets.all(boardPadding),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '요일/교시별 교실 배정 상황표 (전체 반)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _GridHeaderCell(width: periodWidth, title: '교시', subtitle: '시간'),
              ...dayOrder.map(
                (day) => _GridHeaderCell(
                  width: dayWidth,
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
                    final sessions = slot == null
                        ? const <ClassSession>[]
                        : (sessionsBySlotId[slot.id] ?? const <ClassSession>[]);

                    return Container(
                      width: dayWidth,
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        border: Border.all(color: NestColors.roseMist),
                      ),
                      child: sessions.isEmpty
                          ? (forExport
                                ? const SizedBox(height: 8)
                                : Text(
                                    '배정 없음',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: sessions
                                  .map((session) {
                                    final className = controller
                                        .findClassGroupName(
                                          session.classGroupId,
                                        );
                                    final courseName = controller
                                        .findCourseName(session.courseId);
                                    final location = (session.location ?? '')
                                        .trim();
                                    final locationLabel = location.isEmpty
                                        ? '교실 미지정'
                                        : location;
                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 6),
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        color: NestColors.creamyWhite,
                                        border: Border.all(
                                          color: NestColors.roseMist,
                                        ),
                                      ),
                                      child: Text(
                                        '$locationLabel · $className · $courseName',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    );
                                  })
                                  .toList(growable: false),
                            ),
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPalettePanel(NestController controller) {
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
          _buildCoursePalette(controller),
          const SizedBox(height: 14),
          _buildTeacherPalette(controller),
          const SizedBox(height: 14),
          _buildRoomPalette(controller),
        ],
      ),
    );
  }

  Widget _buildCoursePalette(NestController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('과목 팔레트', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              onPressed: controller.isBusy
                  ? null
                  : () => _openQuickCourseDialog(controller),
              tooltip: '과목 추가',
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '과목을 슬롯으로 드래그해 수업을 생성합니다. 칩의 ×로 과목을 삭제할 수 있습니다.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (controller.courses.isEmpty)
          const Text('과목이 없습니다. 우측 + 버튼으로 바로 추가하세요.')
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
                      child: _PaletteChip(
                        label: '${course.name} ${course.defaultDurationMin}m',
                        tone: _PaletteTone.course,
                        dragging: true,
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: _PaletteChip(
                        label: '${course.name} ${course.defaultDurationMin}m',
                        tone: _PaletteTone.course,
                      ),
                    ),
                    child: _PaletteChip(
                      label: '${course.name} ${course.defaultDurationMin}m',
                      tone: _PaletteTone.course,
                      onDelete: controller.isBusy
                          ? null
                          : () => _deleteCourseFromPalette(controller, course),
                      deleteTooltip: '과목 삭제',
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildTeacherPalette(NestController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('선생님 팔레트', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              onPressed: controller.isBusy
                  ? null
                  : () => _openQuickTeacherDialog(controller),
              tooltip: '선생님 추가',
              icon: const Icon(Icons.person_add_alt_1_outlined),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '교사를 슬롯/수업 카드로 드래그해 주강사로 지정합니다. 칩의 ×로 삭제할 수 있습니다.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (controller.teacherProfiles.isEmpty)
          const Text('등록된 교사가 없습니다. 우측 + 버튼으로 바로 추가하세요.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.teacherProfiles
                .map(
                  (teacher) => LongPressDraggable<DragPayload>(
                    data: DragPayload(
                      type: DragPayloadType.teacher,
                      id: teacher.id,
                    ),
                    feedback: Material(
                      color: Colors.transparent,
                      child: _PaletteChip(
                        label: teacher.displayName,
                        tone: _PaletteTone.teacher,
                        dragging: true,
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: _PaletteChip(
                        label: teacher.displayName,
                        tone: _PaletteTone.teacher,
                      ),
                    ),
                    child: _PaletteChip(
                      label: teacher.displayName,
                      tone: _PaletteTone.teacher,
                      onDelete: controller.isBusy
                          ? null
                          : () =>
                                _deleteTeacherFromPalette(controller, teacher),
                      deleteTooltip: '선생님 삭제',
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildRoomPalette(NestController controller) {
    final rooms = _roomPalette.toList(growable: false)..sort();
    final classroomByName = {
      for (final classroom in controller.classrooms)
        classroom.name.trim().toLowerCase(): classroom,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('교실 팔레트', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            IconButton(
              onPressed: controller.isBusy
                  ? null
                  : () => _openQuickClassroomDialog(controller),
              tooltip: '교실 추가',
              icon: const Icon(Icons.add_home_work_outlined),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '교실을 슬롯/수업 카드로 드래그해 배정합니다. 칩의 ×로 삭제/정리할 수 있습니다.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        if (rooms.isEmpty)
          const Text('등록된 교실이 없습니다. 우측 + 버튼으로 바로 추가하세요.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rooms
                .map((room) {
                  final linkedClassroom = classroomByName[room.toLowerCase()];
                  return LongPressDraggable<DragPayload>(
                    data: DragPayload(type: DragPayloadType.room, id: room),
                    feedback: Material(
                      color: Colors.transparent,
                      child: _PaletteChip(
                        label: room,
                        tone: _PaletteTone.room,
                        dragging: true,
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.35,
                      child: _PaletteChip(label: room, tone: _PaletteTone.room),
                    ),
                    child: _PaletteChip(
                      label: room,
                      tone: _PaletteTone.room,
                      onDelete: controller.isBusy
                          ? null
                          : () => _deleteRoomFromPalette(
                              controller,
                              room,
                              linkedClassroom,
                            ),
                      deleteTooltip: linkedClassroom == null
                          ? '팔레트에서 제거'
                          : '교실 삭제',
                    ),
                  );
                })
                .toList(growable: false),
          ),
        if (controller.classrooms.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '연동 교실 ${controller.classrooms.length}개',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.7),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openQuickCourseDialog(NestController controller) async {
    final nameController = TextEditingController();
    final durationController = TextEditingController(text: '50');
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> saveCourse() async {
                if (isSaving) {
                  return;
                }
                final trimmedName = nameController.text.trim();
                final duration = int.tryParse(durationController.text.trim());
                if (trimmedName.isEmpty) {
                  _showMessage('과목 이름을 입력하세요.');
                  return;
                }
                if (duration == null) {
                  _showMessage('기본 수업 시간을 숫자로 입력하세요.');
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });

                final ok = await _tryAction(
                  () => controller.createCourse(
                    name: trimmedName,
                    defaultDurationMin: duration,
                  ),
                );
                if (!context.mounted) {
                  return;
                }
                if (!ok) {
                  setDialogState(() {
                    isSaving = false;
                  });
                  return;
                }

                _showMessage(controller.statusMessage);
                Navigator.of(context).pop();
              }

              return AlertDialog(
                title: const Text('과목 추가'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: '과목 이름'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '기본 수업 시간(분)',
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : saveCourse,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('생성'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      durationController.dispose();
    }
  }

  Future<void> _deleteCourseFromPalette(
    NestController controller,
    Course course,
  ) async {
    final confirmed = await _confirmDeleteDialog(
      title: '과목 삭제',
      message: '"${course.name}" 과목을 삭제할까요?',
    );
    if (confirmed != true) {
      return;
    }

    final ok = await _tryAction(
      () => controller.deleteCourse(courseId: course.id),
    );
    if (!ok || !mounted) {
      return;
    }

    final removedSessionIds = _draftSessions
        .where((row) => row.courseId == course.id)
        .map((row) => row.id)
        .toSet();
    if (removedSessionIds.isNotEmpty) {
      setState(() {
        _draftSessions = _draftSessions
            .where((row) => !removedSessionIds.contains(row.id))
            .toList(growable: false);
        _draftAssignments = {
          for (final entry in _draftAssignments.entries)
            if (!removedSessionIds.contains(entry.key)) entry.key: entry.value,
        };
        _setDirty(true);
      });
    }
    _showMessage(controller.statusMessage);
  }

  Future<void> _openQuickTeacherDialog(NestController controller) async {
    final nameController = TextEditingController();
    var teacherType = 'GUEST_TEACHER';
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> saveTeacher() async {
                if (isSaving) {
                  return;
                }
                final trimmedName = nameController.text.trim();
                if (trimmedName.isEmpty) {
                  _showMessage('선생님 이름을 입력하세요.');
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });

                final ok = await _tryAction(
                  () => controller.createTeacherProfile(
                    displayName: trimmedName,
                    teacherType: teacherType,
                  ),
                );
                if (!context.mounted) {
                  return;
                }
                if (!ok) {
                  setDialogState(() {
                    isSaving = false;
                  });
                  return;
                }

                _showMessage(controller.statusMessage);
                Navigator.of(context).pop();
              }

              return AlertDialog(
                title: const Text('선생님 추가'),
                content: SizedBox(
                  width: 460,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: '표시 이름'),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'PARENT_TEACHER',
                            label: Text('부모 교사'),
                            icon: Icon(Icons.family_restroom, size: 16),
                          ),
                          ButtonSegment(
                            value: 'GUEST_TEACHER',
                            label: Text('초청 교사'),
                            icon: Icon(Icons.badge_outlined, size: 16),
                          ),
                        ],
                        selected: {teacherType},
                        onSelectionChanged: isSaving
                            ? null
                            : (values) {
                                if (values.isEmpty) {
                                  return;
                                }
                                setDialogState(() {
                                  teacherType = values.first;
                                });
                              },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : saveTeacher,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('생성'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _deleteTeacherFromPalette(
    NestController controller,
    TeacherProfile teacher,
  ) async {
    final confirmed = await _confirmDeleteDialog(
      title: '선생님 삭제',
      message:
          '"${teacher.displayName}" 선생님을 삭제할까요?\n시간표/기록에서 사용 중이면 삭제할 수 없습니다.',
    );
    if (confirmed != true) {
      return;
    }

    final ok = await _tryAction(
      () => controller.deleteTeacherProfile(teacherProfileId: teacher.id),
    );
    if (!ok || !mounted) {
      return;
    }

    var changed = false;
    final nextAssignments = <String, List<_EditableAssignment>>{};
    for (final entry in _draftAssignments.entries) {
      final filtered = entry.value
          .where((row) => row.teacherProfileId != teacher.id)
          .toList(growable: false);
      if (filtered.length != entry.value.length) {
        changed = true;
      }
      nextAssignments[entry.key] = filtered;
    }
    if (changed) {
      setState(() {
        _draftAssignments = nextAssignments;
        _setDirty(true);
      });
    }
    _showMessage(controller.statusMessage);
  }

  Future<void> _openQuickClassroomDialog(NestController controller) async {
    final nameController = TextEditingController();
    final capacityController = TextEditingController(text: '20');
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> saveClassroom() async {
                if (isSaving) {
                  return;
                }
                final trimmedName = nameController.text.trim();
                final capacity = int.tryParse(capacityController.text.trim());
                if (trimmedName.isEmpty) {
                  _showMessage('교실 이름을 입력하세요.');
                  return;
                }
                if (capacity == null) {
                  _showMessage('수용 인원을 숫자로 입력하세요.');
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });

                final ok = await _tryAction(
                  () => controller.createClassroom(
                    name: trimmedName,
                    capacity: capacity,
                    note: '',
                  ),
                );
                if (!context.mounted) {
                  return;
                }
                if (!ok) {
                  setDialogState(() {
                    isSaving = false;
                  });
                  return;
                }

                if (mounted) {
                  setState(() {
                    _ensureRoomPaletteFromController(controller);
                  });
                }
                _showMessage(controller.statusMessage);
                Navigator.of(context).pop();
              }

              return AlertDialog(
                title: const Text('교실 추가'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: '교실 이름'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: capacityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '수용 인원'),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : saveClassroom,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('생성'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      capacityController.dispose();
    }
  }

  Future<void> _deleteRoomFromPalette(
    NestController controller,
    String room,
    Classroom? linkedClassroom,
  ) async {
    final normalizedRoom = room.trim();
    if (normalizedRoom.isEmpty) {
      return;
    }

    if (linkedClassroom == null) {
      final confirmed = await _confirmDeleteDialog(
        title: '교실 정리',
        message: '"$normalizedRoom" 항목은 교실 리소스에 연결되지 않았습니다. 팔레트에서 제거할까요?',
        confirmLabel: '정리',
      );
      if (confirmed != true || !mounted) {
        return;
      }
      setState(() {
        _roomPalette = {..._roomPalette}..remove(normalizedRoom);
      });
      _showMessage('팔레트에서 "$normalizedRoom" 항목을 제거했습니다.');
      return;
    }

    final confirmed = await _confirmDeleteDialog(
      title: '교실 삭제',
      message: '"${linkedClassroom.name}" 교실을 삭제할까요?\n시간표에서 사용 중이면 삭제할 수 없습니다.',
    );
    if (confirmed != true) {
      return;
    }

    final ok = await _tryAction(
      () => controller.deleteClassroom(classroomId: linkedClassroom.id),
    );
    if (!ok || !mounted) {
      return;
    }

    var removedFromDraft = false;
    final nextDraftSessions = _draftSessions
        .map((row) {
          final location = (row.location ?? '').trim();
          if (location.toLowerCase() != normalizedRoom.toLowerCase()) {
            return row;
          }
          removedFromDraft = true;
          return row.copyWith(clearLocation: true);
        })
        .toList(growable: false);

    setState(() {
      _ensureRoomPaletteFromController(controller);
      if (removedFromDraft) {
        _draftSessions = nextDraftSessions;
        _setDirty(true);
      }
    });
    _showMessage(controller.statusMessage);
  }

  Future<bool?> _confirmDeleteDialog({
    required String title,
    required String message,
    String confirmLabel = '삭제',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyGrid(NestController controller) {
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
    for (final slots in slotsByDay.values) {
      if (slots.length > maxPeriods) {
        maxPeriods = slots.length;
      }
    }

    if (sortedSlots.isEmpty || dayOrder.isEmpty || maxPeriods == 0) {
      return const Text('표시할 시간표 데이터가 없습니다.');
    }

    return _buildGridScaffold(
      dayOrder: dayOrder,
      slotsByDay: slotsByDay,
      maxPeriods: maxPeriods,
      slotCellBuilder: (slot) {
        final sessions = controller.sessionsForSlot(slot.id);
        return _ReadOnlySlotCell(
          controller: controller,
          slot: slot,
          sessions: sessions,
        );
      },
    );
  }

  Widget _buildEditableGrid({
    required NestController controller,
    required List<int> dayOrder,
    required Map<int, List<TimeSlot>> slotsByDay,
    required int maxPeriods,
    bool forExport = false,
    GlobalKey? repaintKey,
  }) {
    return RepaintBoundary(
      key: repaintKey ?? _timetableRepaintKey,
      child: _buildGridScaffold(
        dayOrder: dayOrder,
        slotsByDay: slotsByDay,
        maxPeriods: maxPeriods,
        forExport: forExport,
        slotCellBuilder: (slot) {
          final slotSessions = _draftSessionsForSlot(slot.id);
          return _EditableSlotCell(
            slot: slot,
            sessions: slotSessions,
            assignmentsBySessionId: _draftAssignments,
            teacherNameById: {
              for (final teacher in controller.teacherProfiles)
                teacher.id: teacher.displayName,
            },
            conflictMessagesForSession: _draftTeacherConflictsForSession,
            onDropPayload: (payload) => _handleDropOnSlot(slot.id, payload),
            onTapSession: _openSessionSettingDialog,
            onDeleteSession: _deleteDraftSession,
            forExport: forExport,
          );
        },
      ),
    );
  }

  Widget _buildGridScaffold({
    required List<int> dayOrder,
    required Map<int, List<TimeSlot>> slotsByDay,
    required int maxPeriods,
    required Widget Function(TimeSlot slot) slotCellBuilder,
    bool forExport = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final periodWidth = forExport ? 102.0 : 108.0;
        final minDayColumnWidth = forExport ? 72.0 : 188.0;
        final maxDayColumnWidth = forExport ? 240.0 : 320.0;
        final slotMinHeight = forExport ? 132.0 : 156.0;
        final boardPadding = forExport ? 16.0 : 10.0;

        final availableWidth = constraints.maxWidth;
        final usable =
            (availableWidth - periodWidth - (dayOrder.length + 1) * gap).clamp(
              0.0,
              double.infinity,
            );

        final dynamicDayWidth = dayOrder.isEmpty
            ? minDayColumnWidth
            : (usable / dayOrder.length).clamp(
                minDayColumnWidth,
                maxDayColumnWidth,
              );

        final gridWidth =
            periodWidth +
            (dayOrder.length * dynamicDayWidth) +
            (dayOrder.length + 1) * gap;
        final shouldScroll = !forExport && gridWidth > availableWidth;
        final renderWidth = forExport
            ? gridWidth + (boardPadding * 2)
            : (shouldScroll
                ? gridWidth + (boardPadding * 2)
                : availableWidth);

        Widget grid = Container(
          width: renderWidth,
          padding: EdgeInsets.all(boardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
            border: Border.all(color: NestColors.roseMist),
          ),
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
                      width: dynamicDayWidth,
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
                        constraints: BoxConstraints(minHeight: slotMinHeight),
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
                            width: dynamicDayWidth,
                            constraints: BoxConstraints(
                              minHeight: slotMinHeight,
                            ),
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

                        return Container(
                          width: dynamicDayWidth,
                          constraints: BoxConstraints(minHeight: slotMinHeight),
                          margin: const EdgeInsets.only(right: 6),
                          child: slotCellBuilder(slot),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        );

        if (shouldScroll) {
          grid = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: grid,
          );
        }

        return grid;
      },
    );
  }

  Future<void> _openClassPicker(
    NestController controller,
    List<ClassGroup> classGroups,
  ) async {
    final options = classGroups
        .map(
          (group) => SelectSheetOption<String>(
            value: group.id,
            title: group.name,
            subtitle: '정원 ${group.capacity}명',
            keywords: group.name,
          ),
        )
        .toList(growable: false);

    final selected = await showSelectSheet<String>(
      context: context,
      title: '반 선택',
      helpText: '편집할 반을 선택하세요.',
      options: options,
      currentValue: controller.selectedClassGroupId,
    );

    if (selected == null) {
      return;
    }

    await _switchClassGroup(controller, selected);
  }

  Future<void> _switchClassGroup(
    NestController controller,
    String classGroupId,
  ) async {
    if (classGroupId == controller.selectedClassGroupId) {
      return;
    }

    if (_isDraftDirty) {
      final discard = await _confirmDiscardDialog(
        title: '반 전환',
        message: '저장되지 않은 시간표 수정사항이 있습니다. 롤백 후 반을 전환할까요?',
      );
      if (discard != true) {
        return;
      }
      _rollbackDraftLocal(controller);
    }

    await _safeCall(() => controller.changeClassGroup(classGroupId));
  }

  Future<void> _commitDraftChanges() async {
    if (_isApplyingDraft) {
      return;
    }

    final controller = widget.controller;
    final classGroupId = controller.selectedClassGroupId;
    if (classGroupId == null || classGroupId.isEmpty) {
      _showMessage('반을 먼저 선택하세요.');
      return;
    }

    setState(() {
      _isApplyingDraft = true;
    });

    try {
      final initialSessions = controller.sessions.toList(growable: false);
      final initialIds = initialSessions.map((row) => row.id).toSet();

      final existingDraftRows = _draftSessions
          .where((row) => !row.isNew && initialIds.contains(row.id))
          .toList(growable: false);
      final existingDraftIds = existingDraftRows.map((row) => row.id).toSet();

      final deleteIds = initialSessions
          .where((row) => !existingDraftIds.contains(row.id))
          .map((row) => row.id)
          .toList(growable: false);

      for (final sessionId in deleteIds) {
        await controller.cancelSession(sessionId);
      }

      for (final draftRow in existingDraftRows) {
        final current = controller.sessions
            .where((row) => row.id == draftRow.id)
            .firstOrNull;
        if (current == null) {
          continue;
        }

        if (current.timeSlotId != draftRow.timeSlotId) {
          await controller.moveSession(
            sessionId: current.id,
            targetSlotId: draftRow.timeSlotId,
          );
        }

        final currentLocation = (current.location ?? '').trim();
        final nextLocation = (draftRow.location ?? '').trim();
        if (currentLocation != nextLocation) {
          await controller.updateSessionLocation(
            sessionId: current.id,
            location: nextLocation,
          );
        }
      }

      final tempIdToRealId = <String, String>{};
      final createdIds = <String>{};

      for (final draftRow in _draftSessions.where((row) => row.isNew)) {
        await controller.createSessionByCourse(
          courseId: draftRow.courseId,
          slotId: draftRow.timeSlotId,
        );

        final created = controller.sessions
            .where(
              (row) =>
                  row.timeSlotId == draftRow.timeSlotId &&
                  row.courseId == draftRow.courseId &&
                  !createdIds.contains(row.id),
            )
            .toList(growable: false)
            .lastOrNull;

        if (created == null) {
          continue;
        }

        createdIds.add(created.id);
        tempIdToRealId[draftRow.id] = created.id;

        final location = (draftRow.location ?? '').trim();
        if (location.isNotEmpty) {
          await controller.updateSessionLocation(
            sessionId: created.id,
            location: location,
          );
        }
      }

      for (final draftRow in _draftSessions) {
        final resolvedSessionId = draftRow.isNew
            ? tempIdToRealId[draftRow.id]
            : draftRow.id;
        if (resolvedSessionId == null || resolvedSessionId.isEmpty) {
          continue;
        }

        final currentRows = controller.teacherAssignmentsForSession(
          resolvedSessionId,
        );
        for (final row in currentRows) {
          await controller.removeTeacherFromSession(
            classSessionId: resolvedSessionId,
            teacherProfileId: row.teacherProfileId,
          );
        }

        final desiredRows = (_draftAssignments[draftRow.id] ?? const []).toList(
          growable: false,
        );

        final desiredMain = desiredRows
            .where((row) => row.assignmentRole == 'MAIN')
            .map((row) => row.teacherProfileId)
            .firstOrNull;

        if (desiredMain != null) {
          await controller.assignTeacherToSession(
            classSessionId: resolvedSessionId,
            teacherProfileId: desiredMain,
            assignmentRole: 'MAIN',
          );
        }

        final assistantIds = desiredRows
            .where((row) => row.assignmentRole == 'ASSISTANT')
            .map((row) => row.teacherProfileId)
            .where((id) => id != desiredMain)
            .toSet();

        for (final teacherId in assistantIds) {
          await controller.assignTeacherToSession(
            classSessionId: resolvedSessionId,
            teacherProfileId: teacherId,
            assignmentRole: 'ASSISTANT',
          );
        }
      }

      // Ensure parent tab guard state is cleared immediately after successful commit.
      _setDirty(false, forceNotify: true);
      _loadDraftFromController(controller);
      _showMessage('시간표 수정을 확정했습니다.');
    } catch (error) {
      _showMessage(
        error is StateError ? error.message : widget.controller.statusMessage,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isApplyingDraft = false;
        });
      }
    }
  }

  void _rollbackDraftLocal(NestController controller) {
    _loadDraftFromController(controller);
  }

  Future<void> _handleDropOnSlot(String slotId, DragPayload payload) async {
    switch (payload.type) {
      case DragPayloadType.course:
        _addCourseToSlot(courseId: payload.id, slotId: slotId);
        return;
      case DragPayloadType.session:
        _moveDraftSession(sessionId: payload.id, targetSlotId: slotId);
        return;
      case DragPayloadType.teacher:
        await _applyTeacherToSlot(slotId: slotId, teacherProfileId: payload.id);
        return;
      case DragPayloadType.room:
        await _applyRoomToSlot(slotId: slotId, roomName: payload.id);
        return;
    }
  }

  void _addCourseToSlot({required String courseId, required String slotId}) {
    final occupied = _draftSessions.any((row) => row.timeSlotId == slotId);
    if (occupied) {
      _showMessage('해당 슬롯에는 이미 수업이 있습니다.');
      return;
    }

    final next = _EditableSession(
      id: 'tmp-manual-${DateTime.now().microsecondsSinceEpoch}',
      courseId: courseId,
      timeSlotId: slotId,
      title: '${widget.controller.findCourseName(courseId)} 수업',
      isNew: true,
      location: null,
    );

    setState(() {
      _draftSessions = [..._draftSessions, next];
      _setDirty(true);
    });
  }

  void _moveDraftSession({
    required String sessionId,
    required String targetSlotId,
  }) {
    final targetOccupied = _draftSessions.any(
      (row) => row.timeSlotId == targetSlotId && row.id != sessionId,
    );
    if (targetOccupied) {
      _showMessage('대상 슬롯이 이미 사용 중입니다.');
      return;
    }

    setState(() {
      _draftSessions = _draftSessions
          .map(
            (row) => row.id == sessionId
                ? row.copyWith(timeSlotId: targetSlotId)
                : row,
          )
          .toList(growable: false);
      _setDirty(true);
    });
  }

  Future<void> _applyTeacherToSlot({
    required String slotId,
    required String teacherProfileId,
  }) async {
    final slotSessions = _draftSessionsForSlot(slotId);
    if (slotSessions.isEmpty) {
      _showMessage('먼저 과목을 배치하세요.');
      return;
    }

    final session = slotSessions.length == 1
        ? slotSessions.first
        : await _pickSessionForSlot(slotSessions, '교사를 배정할 수업 선택');

    if (session == null) {
      return;
    }

    _setMainTeacher(session.id, teacherProfileId);
  }

  Future<void> _applyRoomToSlot({
    required String slotId,
    required String roomName,
  }) async {
    final slotSessions = _draftSessionsForSlot(slotId);
    if (slotSessions.isEmpty) {
      _showMessage('먼저 과목을 배치하세요.');
      return;
    }

    final session = slotSessions.length == 1
        ? slotSessions.first
        : await _pickSessionForSlot(slotSessions, '교실을 지정할 수업 선택');

    if (session == null) {
      return;
    }

    _setSessionLocation(session.id, roomName);
  }

  Future<_EditableSession?> _pickSessionForSlot(
    List<_EditableSession> candidates,
    String title,
  ) async {
    return showDialog<_EditableSession>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: candidates
                .map(
                  (session) => ListTile(
                    dense: true,
                    title: Text(
                      widget.controller.findCourseName(session.courseId),
                    ),
                    subtitle: Text(_slotLabel(session.timeSlotId)),
                    onTap: () => Navigator.of(context).pop(session),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSessionSettingDialog(String sessionId) async {
    final controller = widget.controller;
    final session = _draftSessions
        .where((row) => row.id == sessionId)
        .firstOrNull;
    if (session == null) {
      return;
    }

    String? selectedClassroom = (session.location ?? '').trim().isEmpty
        ? null
        : (session.location ?? '').trim();
    String? mainTeacherId = (_draftAssignments[sessionId] ?? const [])
        .where((row) => row.assignmentRole == 'MAIN')
        .map((row) => row.teacherProfileId)
        .firstOrNull;
    var assistantIds = (_draftAssignments[sessionId] ?? const [])
        .where((row) => row.assignmentRole == 'ASSISTANT')
        .map((row) => row.teacherProfileId)
        .toSet();

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final roomOptions = _roomPalette.toList(growable: false)..sort();
            if (selectedClassroom != null &&
                selectedClassroom!.isNotEmpty &&
                !roomOptions.contains(selectedClassroom)) {
              roomOptions.add(selectedClassroom!);
              roomOptions.sort();
            }

            return AlertDialog(
              title: const Text('수업 설정'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.controller.findCourseName(session.courseId),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(_slotLabel(session.timeSlotId)),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: mainTeacherId,
                        decoration: const InputDecoration(labelText: '주강사'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('미지정'),
                          ),
                          ...controller.teacherProfiles.map(
                            (teacher) => DropdownMenuItem<String>(
                              value: teacher.id,
                              child: Text(teacher.displayName),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setLocalState(() {
                            mainTeacherId = value;
                            if (value != null) {
                              assistantIds.remove(value);
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '보조강사',
                        style: Theme.of(context).textTheme.titleSmall,
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
                                final selected = assistantIds.contains(
                                  teacher.id,
                                );
                                final disabled = mainTeacherId == teacher.id;
                                return FilterChip(
                                  label: Text(teacher.displayName),
                                  selected: selected,
                                  onSelected: disabled
                                      ? null
                                      : (value) {
                                          setLocalState(() {
                                            if (value) {
                                              assistantIds.add(teacher.id);
                                            } else {
                                              assistantIds.remove(teacher.id);
                                            }
                                          });
                                        },
                                );
                              })
                              .toList(growable: false),
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedClassroom,
                        decoration: const InputDecoration(labelText: '교실'),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('미지정'),
                          ),
                          ...roomOptions.map(
                            (room) => DropdownMenuItem<String>(
                              value: room,
                              child: Text(room),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setLocalState(() {
                            selectedClassroom = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      if (roomOptions.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: roomOptions
                              .map(
                                (room) => ActionChip(
                                  label: Text(room),
                                  onPressed: () {
                                    setLocalState(() {
                                      selectedClassroom = room;
                                    });
                                  },
                                ),
                              )
                              .toList(growable: false),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _replaceAssignments(
                      sessionId,
                      mainTeacherId: mainTeacherId,
                      assistantIds: assistantIds,
                    );
                    _setSessionLocation(sessionId, selectedClassroom ?? '');
                    Navigator.of(context).pop();
                  },
                  child: const Text('적용'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _replaceAssignments(
    String sessionId, {
    required String? mainTeacherId,
    required Set<String> assistantIds,
  }) {
    final rows = <_EditableAssignment>[];
    if (mainTeacherId != null && mainTeacherId.isNotEmpty) {
      rows.add(
        _EditableAssignment(
          teacherProfileId: mainTeacherId,
          assignmentRole: 'MAIN',
        ),
      );
    }
    for (final teacherId in assistantIds) {
      if (teacherId == mainTeacherId) {
        continue;
      }
      rows.add(
        _EditableAssignment(
          teacherProfileId: teacherId,
          assignmentRole: 'ASSISTANT',
        ),
      );
    }

    setState(() {
      _draftAssignments = {..._draftAssignments, sessionId: rows};
      _setDirty(true);
    });
  }

  void _setMainTeacher(String sessionId, String teacherProfileId) {
    final current = (_draftAssignments[sessionId] ?? const [])
        .where(
          (row) =>
              row.assignmentRole == 'ASSISTANT' &&
              row.teacherProfileId != teacherProfileId,
        )
        .toList(growable: false);

    final next = [
      _EditableAssignment(
        teacherProfileId: teacherProfileId,
        assignmentRole: 'MAIN',
      ),
      ...current,
    ];

    setState(() {
      _draftAssignments = {..._draftAssignments, sessionId: next};
      _setDirty(true);
    });
  }

  void _setSessionLocation(String sessionId, String location) {
    final normalized = location.trim();
    setState(() {
      _draftSessions = _draftSessions
          .map(
            (row) => row.id == sessionId
                ? row.copyWith(location: normalized.isEmpty ? null : normalized)
                : row,
          )
          .toList(growable: false);
      if (normalized.isNotEmpty) {
        _roomPalette = {..._roomPalette, normalized};
      }
      _setDirty(true);
    });
  }

  void _deleteDraftSession(String sessionId) {
    setState(() {
      _draftSessions = _draftSessions
          .where((row) => row.id != sessionId)
          .toList(growable: false);
      _draftAssignments = {
        for (final entry in _draftAssignments.entries)
          if (entry.key != sessionId) entry.key: entry.value,
      };
      _setDirty(true);
    });
  }

  List<_EditableSession> _draftSessionsForSlot(String slotId) {
    final rows =
        _draftSessions
            .where((row) => row.timeSlotId == slotId)
            .toList(growable: false)
          ..sort((a, b) => a.title.compareTo(b.title));
    return rows;
  }

  List<String> _draftTeacherConflictsForSession(String sessionId) {
    final session = _draftSessions
        .where((row) => row.id == sessionId)
        .firstOrNull;
    if (session == null) {
      return const [];
    }

    final myTeachers = (_draftAssignments[sessionId] ?? const [])
        .map((row) => row.teacherProfileId)
        .toSet();
    if (myTeachers.isEmpty) {
      return const [];
    }

    final conflicts = <String>[];
    for (final other in _draftSessions) {
      if (other.id == sessionId || other.timeSlotId != session.timeSlotId) {
        continue;
      }
      final otherTeachers = (_draftAssignments[other.id] ?? const [])
          .map((row) => row.teacherProfileId)
          .toSet();
      final overlap = myTeachers.intersection(otherTeachers);
      for (final teacherId in overlap) {
        conflicts.add('교사 충돌: ${widget.controller.findTeacherName(teacherId)}');
      }
    }

    return conflicts.toSet().toList(growable: false);
  }

  Future<void> _exportTimetableImage() async {
    final boundary =
        _timetableExportRepaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      _showMessage('내보낼 시간표를 먼저 열어주세요.');
      return;
    }

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return;
    }

    final bytes = byteData.buffer.asUint8List();
    final helper = createDownloadHelper();
    helper.downloadBytes(
      bytes: bytes,
      filename: 'timetable_${DateTime.now().millisecondsSinceEpoch}.png',
      mimeType: 'image/png',
    );
  }

  Future<void> _exportRoomUtilizationImage() async {
    final boundary =
        _roomUtilizationRepaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) {
      _showMessage('내보낼 교실 상황표를 먼저 열어주세요.');
      return;
    }

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) {
      return;
    }

    final bytes = byteData.buffer.asUint8List();
    final helper = createDownloadHelper();
    helper.downloadBytes(
      bytes: bytes,
      filename:
          'classroom_utilization_${DateTime.now().millisecondsSinceEpoch}.png',
      mimeType: 'image/png',
    );
  }

  Future<bool?> _confirmDiscardDialog({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('롤백'),
          ),
        ],
      ),
    );
  }

  void _syncDraftWithController(NestController controller) {
    final classId = controller.selectedClassGroupId;
    if (classId == null || classId.isEmpty) {
      if (_draftClassGroupId != null ||
          _draftSessions.isNotEmpty ||
          _isDraftDirty) {
        _draftClassGroupId = null;
        _draftSessions = const [];
        _draftAssignments = const {};
        _roomPalette = const {};
        _controllerSignature = '';
        _setDirty(false, forceNotify: true);
      }
      return;
    }

    final signature = _buildControllerSignature(controller, classId);
    final classChanged = _draftClassGroupId != classId;

    if (classChanged && _isDraftDirty) {
      _loadDraftFromController(controller);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showMessage('반이 변경되어 미확정 수정사항을 롤백했습니다.');
      });
      return;
    }

    if (!_isDraftDirty && (classChanged || signature != _controllerSignature)) {
      _loadDraftFromController(controller);
    }
  }

  String _buildControllerSignature(NestController controller, String classId) {
    final sessions =
        controller.sessions
            .where((row) => row.classGroupId == classId)
            .toList(growable: false)
          ..sort((a, b) => a.id.compareTo(b.id));

    final sessionIds = sessions.map((row) => row.id).toSet();
    final assignments =
        controller.sessionTeacherAssignments
            .where((row) => sessionIds.contains(row.classSessionId))
            .toList(growable: false)
          ..sort((a, b) {
            final bySession = a.classSessionId.compareTo(b.classSessionId);
            if (bySession != 0) {
              return bySession;
            }
            final byTeacher = a.teacherProfileId.compareTo(b.teacherProfileId);
            if (byTeacher != 0) {
              return byTeacher;
            }
            return a.assignmentRole.compareTo(b.assignmentRole);
          });

    final sessionSig = sessions
        .map(
          (row) =>
              '${row.id}/${row.courseId}/${row.timeSlotId}/${row.title}/${(row.location ?? '').trim()}',
        )
        .join('|');
    final assignmentSig = assignments
        .map(
          (row) =>
              '${row.classSessionId}/${row.teacherProfileId}/${row.assignmentRole}',
        )
        .join('|');
    final classroomSig = controller.classrooms.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    final classroomMerged = classroomSig
        .map((row) => '${row.id}/${row.name}/${row.capacity}/${row.note}')
        .join('|');

    return '$classId::$sessionSig::$assignmentSig::$classroomMerged';
  }

  void _loadDraftFromController(NestController controller) {
    final classId = controller.selectedClassGroupId;
    if (classId == null || classId.isEmpty) {
      _draftClassGroupId = null;
      _draftSessions = const [];
      _draftAssignments = const {};
      _roomPalette = const {};
      _controllerSignature = '';
      _setDirty(false, forceNotify: true);
      return;
    }

    final sessions =
        controller.sessions
            .where((row) => row.classGroupId == classId)
            .toList(growable: false)
          ..sort((a, b) {
            final leftSlot = controller.findTimeSlot(a.timeSlotId);
            final rightSlot = controller.findTimeSlot(b.timeSlotId);
            if (leftSlot == null || rightSlot == null) {
              return a.timeSlotId.compareTo(b.timeSlotId);
            }
            final day = leftSlot.dayOfWeek.compareTo(rightSlot.dayOfWeek);
            if (day != 0) {
              return day;
            }
            return leftSlot.startTime.compareTo(rightSlot.startTime);
          });

    final assignments = <String, List<_EditableAssignment>>{};
    for (final session in sessions) {
      final rows = controller
          .teacherAssignmentsForSession(session.id)
          .map(
            (row) => _EditableAssignment(
              teacherProfileId: row.teacherProfileId,
              assignmentRole: row.assignmentRole,
            ),
          )
          .toList(growable: false);
      assignments[session.id] = rows;
    }

    _draftClassGroupId = classId;
    _draftSessions = sessions
        .map(
          (row) => _EditableSession(
            id: row.id,
            courseId: row.courseId,
            timeSlotId: row.timeSlotId,
            title: row.title,
            location: row.location,
            isNew: false,
          ),
        )
        .toList(growable: false);
    _draftAssignments = assignments;
    _ensureRoomPaletteFromController(controller);
    _controllerSignature = _buildControllerSignature(controller, classId);
    _setDirty(false);
  }

  void _ensureRoomPaletteFromController(NestController controller) {
    final rooms = <String>{};
    for (final classroom in controller.classrooms) {
      final name = classroom.name.trim();
      if (name.isNotEmpty) {
        rooms.add(name);
      }
    }
    for (final session in controller.allTermSessions) {
      final location = session.location?.trim();
      if (location != null && location.isNotEmpty) {
        rooms.add(location);
      }
    }
    for (final session in _draftSessions) {
      final location = session.location?.trim();
      if (location != null && location.isNotEmpty) {
        rooms.add(location);
      }
    }
    _roomPalette = rooms;
  }

  void _setDirty(bool value, {bool forceNotify = false}) {
    final changed = _isDraftDirty != value;
    if (!changed && !forceNotify) {
      return;
    }
    _isDraftDirty = value;
    widget.onDirtyChanged?.call(value);
  }

  String _slotLabel(String slotId) {
    final slot = widget.controller.findTimeSlot(slotId);
    if (slot == null) {
      return slotId;
    }
    return '${_dayLabel(slot.dayOfWeek)} ${_shortTime(slot.startTime)}-${_shortTime(slot.endTime)}';
  }

  Future<bool> _tryAction(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      final message = error is StateError
          ? error.message
          : widget.controller.statusMessage;
      _showMessage(message);
      return false;
    }
  }

  Future<void> _safeCall(Future<void> Function() action) async {
    await _tryAction(action);
  }

  void _showMessage(String text) {
    if (!mounted || text.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _EditableSlotCell extends StatelessWidget {
  const _EditableSlotCell({
    required this.slot,
    required this.sessions,
    required this.assignmentsBySessionId,
    required this.teacherNameById,
    required this.conflictMessagesForSession,
    required this.onDropPayload,
    required this.onTapSession,
    required this.onDeleteSession,
    required this.forExport,
  });

  final TimeSlot slot;
  final List<_EditableSession> sessions;
  final Map<String, List<_EditableAssignment>> assignmentsBySessionId;
  final Map<String, String> teacherNameById;
  final List<String> Function(String sessionId) conflictMessagesForSession;
  final Future<void> Function(DragPayload payload) onDropPayload;
  final void Function(String sessionId) onTapSession;
  final void Function(String sessionId) onDeleteSession;
  final bool forExport;

  @override
  Widget build(BuildContext context) {
    return DragTarget<DragPayload>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) async {
        await onDropPayload(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: hovering
                ? NestColors.roseMist.withValues(alpha: 0.58)
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
                  child: forExport
                      ? const SizedBox(height: 16)
                      : Text(
                          '과목/교사/교실을 드래그',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                )
              else
                ...sessions.map((session) {
                  final title = session.title.isEmpty
                      ? session.courseId
                      : session.title;
                  final rows = assignmentsBySessionId[session.id] ?? const [];
                  final teacherBadges = rows
                      .map(
                        (row) =>
                            '${row.assignmentRole == 'MAIN' ? '주' : '보조'} ${teacherNameById[row.teacherProfileId] ?? row.teacherProfileId}',
                      )
                      .toList(growable: false);
                  final conflictRows = conflictMessagesForSession(session.id);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: LongPressDraggable<DragPayload>(
                      data: DragPayload(
                        type: DragPayloadType.session,
                        id: session.id,
                      ),
                      feedback: Material(
                        color: Colors.transparent,
                        child: _GridSessionTile(
                          title: title,
                          subtitle: session.courseId,
                          location: session.location,
                          teacherBadges: teacherBadges,
                          conflictMessages: conflictRows,
                          canDelete: false,
                          onDelete: null,
                          onTap: null,
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.36,
                        child: _GridSessionTile(
                          title: title,
                          subtitle: session.courseId,
                          location: session.location,
                          teacherBadges: teacherBadges,
                          conflictMessages: conflictRows,
                          canDelete: false,
                          onDelete: null,
                          onTap: null,
                        ),
                      ),
                      child: _GridSessionTile(
                        title: title,
                        subtitle: session.courseId,
                        location: session.location,
                        teacherBadges: teacherBadges,
                        conflictMessages: conflictRows,
                        canDelete: !forExport,
                        onDelete: forExport
                            ? null
                            : () => onDeleteSession(session.id),
                        onTap: forExport
                            ? null
                            : () => onTapSession(session.id),
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

class _ReadOnlySlotCell extends StatelessWidget {
  const _ReadOnlySlotCell({
    required this.controller,
    required this.slot,
    required this.sessions,
  });

  final NestController controller;
  final TimeSlot slot;
  final List<ClassSession> sessions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: NestColors.roseMist),
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
            Text('배정 없음', style: Theme.of(context).textTheme.bodySmall)
          else
            ...sessions.map((session) {
              final courseName = controller.findCourseName(session.courseId);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
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
                      Text(
                        courseName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if ((session.location ?? '').trim().isNotEmpty)
                        Text(
                          '교실: ${session.location!.trim()}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
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

class _GridSessionTile extends StatelessWidget {
  const _GridSessionTile({
    required this.title,
    required this.subtitle,
    required this.teacherBadges,
    required this.conflictMessages,
    required this.canDelete,
    required this.onDelete,
    required this.onTap,
    this.location,
  });

  final String title;
  final String subtitle;
  final String? location;
  final List<String> teacherBadges;
  final List<String> conflictMessages;
  final bool canDelete;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (canDelete)
                    IconButton(
                      onPressed: onDelete,
                      icon: const Icon(Icons.close, size: 16),
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      tooltip: '삭제',
                    ),
                ],
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (location != null && location!.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.room_outlined, size: 12),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        location!.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
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
                        (message) => Container(
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
                            message,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _PaletteTone { course, teacher, room }

class _PaletteChip extends StatelessWidget {
  const _PaletteChip({
    required this.label,
    required this.tone,
    this.dragging = false,
    this.onDelete,
    this.deleteTooltip,
  });

  final String label;
  final _PaletteTone tone;
  final bool dragging;
  final VoidCallback? onDelete;
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final toneColor = switch (tone) {
      _PaletteTone.course => NestColors.dustyRose,
      _PaletteTone.teacher => NestColors.mutedSage,
      _PaletteTone.room => NestColors.clay,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: dragging
            ? toneColor.withValues(alpha: 0.92)
            : toneColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: toneColor.withValues(alpha: 0.48)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: dragging ? Colors.white : NestColors.deepWood,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (onDelete != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: deleteTooltip ?? '삭제',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onDelete,
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: dragging
                      ? Colors.white
                      : NestColors.deepWood.withValues(alpha: 0.74),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EditableSession {
  const _EditableSession({
    required this.id,
    required this.courseId,
    required this.timeSlotId,
    required this.title,
    required this.location,
    required this.isNew,
  });

  final String id;
  final String courseId;
  final String timeSlotId;
  final String title;
  final String? location;
  final bool isNew;

  _EditableSession copyWith({
    String? courseId,
    String? timeSlotId,
    String? title,
    String? location,
    bool? clearLocation,
    bool? isNew,
  }) {
    return _EditableSession(
      id: id,
      courseId: courseId ?? this.courseId,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      title: title ?? this.title,
      location: clearLocation == true ? null : (location ?? this.location),
      isNew: isNew ?? this.isNew,
    );
  }
}

class _EditableAssignment {
  const _EditableAssignment({
    required this.teacherProfileId,
    required this.assignmentRole,
  });

  final String teacherProfileId;
  final String assignmentRole;
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
