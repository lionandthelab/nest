import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/download_helper.dart';
import '../../services/nest_repository.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/search_select_field.dart';
import 'self_study/supervision_schedule_view.dart';
import 'timetable/empty_room_finder.dart';
import 'timetable/family_enrollment_panel.dart';
import 'timetable/object_inspector_rail.dart';
import 'timetable/room_normalizer.dart';
import 'timetable/whole_school_overlay_board.dart';

/// Board view mode: per-class editable build, read-only whole-school overlay,
/// or the read-only "빈 강의실 찾기" picker.
enum _TimetableViewMode { perClass, wholeSchool, emptyRoom }

/// 교사 열람 뷰 모드: 내 수업 / 내 감독 / 빈 강의실.
enum _ReadOnlyMode { schedule, supervision, emptyRoom }

/// 뷰 토글 공용 스타일. 세그먼트 패딩/폰트를 줄여 '빈 강의실'(아이콘+4글자)
/// 같은 라벨이 좁은 화면에서도 한 줄에 들어가게 한다.
const ButtonStyle _kViewToggleStyle = ButtonStyle(
  visualDensity: VisualDensity.compact,
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 5)),
  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 13)),
);

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

  // Read-only view (teachers / non-admin): toggle between the schedule grid and
  // the "빈 강의실 찾기" picker.
  _ReadOnlyMode _readOnlyMode = _ReadOnlyMode.schedule;

  // Phase 2 "한눈에" view-mode toggle + whole-school pivot axis.
  _TimetableViewMode _viewMode = _TimetableViewMode.perClass;
  WholeSchoolAxis _wholeSchoolAxis = WholeSchoolAxis.byClass;
  // Optional column reference surfaced from the whole-school board header tap;
  // drives the inspector rail's initial selection.
  WholeSchoolColumnRef? _pendingInspect;

  List<_EditableSession> _draftSessions = const [];
  Map<String, List<_EditableAssignment>> _draftAssignments = const {};
  Set<String> _roomPalette = const {};

  // "수업 카드 조립" composer state.
  String? _composeCourseId;
  String? _composeTeacherId;
  String? _composeRoom;
  ComposedSessionPayload? _composedCard;

  // Live drag feedback: non-null while a Draggable from palette/grid is active.
  _ActiveDrag? _activeDrag;

  // Client-only undo/redo stacks (capped at 30 entries each).
  static const int _historyLimit = 30;
  final List<_DraftSnapshot> _undoStack = [];
  final List<_DraftSnapshot> _redoStack = [];

  // Keyboard focus for Ctrl+Z / Ctrl+Shift+Z shortcuts on the board card.
  final FocusNode _boardFocusNode = FocusNode();

  @override
  void dispose() {
    _boardFocusNode.dispose();
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
        const SizedBox(height: 8),
        _buildTimeSlotManagerBar(controller),
        const SizedBox(height: 8),
        _buildBoardCard(controller),
      ],
    );
  }

  Widget _buildReadOnlyView(NestController controller) {
    // 교사(교사 프로필 보유)면 "내 감독" 탭을 노출한다.
    final myProfileId = controller.currentUserTeacherProfiles.firstOrNull?.id;
    final canSupervise = myProfileId != null && myProfileId.isNotEmpty;

    var mode = _readOnlyMode;
    if (mode == _ReadOnlyMode.supervision && !canSupervise) {
      mode = _ReadOnlyMode.schedule;
    }

    final modeToggle = SegmentedButton<_ReadOnlyMode>(
      segments: [
        const ButtonSegment(
          value: _ReadOnlyMode.schedule,
          label: Text('수업'),
          icon: Icon(Icons.calendar_view_week_outlined, size: 16),
        ),
        if (canSupervise)
          const ButtonSegment(
            value: _ReadOnlyMode.supervision,
            label: Text('감독'),
            icon: Icon(Icons.assignment_ind_outlined, size: 16),
          ),
        const ButtonSegment(
          value: _ReadOnlyMode.emptyRoom,
          label: Text('빈 강의실', maxLines: 1, softWrap: false),
          icon: Icon(Icons.meeting_room_outlined, size: 16),
        ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      style: _kViewToggleStyle,
      onSelectionChanged: (values) {
        if (values.isEmpty) return;
        setState(() => _readOnlyMode = values.first);
      },
    );

    late final Widget body;
    switch (mode) {
      case _ReadOnlyMode.emptyRoom:
        body = EmptyRoomFinder(controller: controller);
        break;
      case _ReadOnlyMode.supervision:
        body = SupervisionScheduleView(
          controller: controller,
          teacherProfileId: myProfileId!,
          showHeader: false,
        );
        break;
      case _ReadOnlyMode.schedule:
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '현재 뷰에서는 열람만 가능합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
            ),
            const SizedBox(height: 12),
            _buildReadOnlyGrid(controller),
          ],
        );
        break;
    }

    return SingleChildScrollView(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode == _ReadOnlyMode.supervision ? '내 감독 시간표' : '시간표',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              modeToggle,
              const SizedBox(height: 12),
              body,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlotManagerBar(NestController controller) {
    final slots = controller.timeSlots.toList()
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) return day;
        return a.startTime.compareTo(b.startTime);
      });
    final daySet = slots.map((s) => s.dayOfWeek).toSet();
    final periodSet = slots.map((s) => '${s.startTime}-${s.endTime}').toSet();
    final locked = controller.isBusy || controller.isSelectedTermReadOnly;

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.grid_on_outlined,
              size: 20,
              color: NestColors.clay,
            ),
            const SizedBox(width: 8),
            Text(
              '교시 설정',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Chip(
              label: Text('${daySet.length}요일 · ${periodSet.length}교시'),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const Spacer(),
            // 교시를 잘못 설정(예: 29교시)했을 때, 현재 상태에서 값을 추론하지 않고
            // 깨끗한 기본값(평일 09:00~15:00 · 50분)으로 편집기를 열어 재설정한다.
            if (slots.isNotEmpty)
              TextButton.icon(
                onPressed: locked
                    ? null
                    : () => _openTimeSlotEditorDialog(controller,
                        resetToDefaults: true),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('초기화'),
                style: TextButton.styleFrom(foregroundColor: NestColors.clay),
              ),
            TextButton.icon(
              onPressed:
                  locked ? null : () => _openTimeSlotEditorDialog(controller),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('편집'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTimeSlotEditorDialog(
    NestController controller, {
    bool resetToDefaults = false,
  }) async {
    // Infer current settings from existing slots
    final slots = controller.timeSlots.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final activeDays = slots.map((s) => s.dayOfWeek).toSet();
    final uniquePeriods = <String>{};
    for (final s in slots) {
      uniquePeriods.add('${s.startTime}|${s.endTime}');
    }

    // 기본값(초기화 시엔 현재 상태를 무시하고 이 값으로 시작).
    String inferredStart = '09:00';
    String inferredEnd = '15:00';
    int inferredDuration = 50;
    int inferredBreak = 10;

    // 초기화 모드에서는 망가진 현재 교시에서 값을 추론하지 않는다.
    if (!resetToDefaults && uniquePeriods.isNotEmpty) {
      final sortedPeriods = uniquePeriods.toList()..sort();

      // First period start
      final firstStart = sortedPeriods.first.split('|')[0];
      inferredStart = _shortTime(firstStart);

      // Last period end
      final lastEnd = sortedPeriods.last.split('|')[1];
      inferredEnd = _shortTime(lastEnd);

      // Duration from first period
      final firstEnd = sortedPeriods.first.split('|')[1];
      final startParts = _shortTime(firstStart).split(':');
      final endParts = _shortTime(firstEnd).split(':');
      inferredDuration = (int.parse(endParts[0]) * 60 + int.parse(endParts[1])) -
          (int.parse(startParts[0]) * 60 + int.parse(startParts[1]));

      // Break from gap between first and second period
      if (sortedPeriods.length >= 2) {
        final secondStart = sortedPeriods[1].split('|')[0];
        final secondParts = _shortTime(secondStart).split(':');
        inferredBreak = (int.parse(secondParts[0]) * 60 + int.parse(secondParts[1])) -
            (int.parse(endParts[0]) * 60 + int.parse(endParts[1]));
        if (inferredBreak < 0) inferredBreak = 10;
      }
    }

    final dayStartCtrl = TextEditingController(text: inferredStart);
    final dayEndCtrl = TextEditingController(text: inferredEnd);
    final durationCtrl =
        TextEditingController(text: inferredDuration.toString());
    final breakCtrl = TextEditingController(text: inferredBreak.toString());
    var selectedDays = (!resetToDefaults && activeDays.isNotEmpty)
        ? Set<int>.from(activeDays)
        : <int>{1, 2, 3, 4, 5}; // Default: Mon-Fri

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              // Preview generated periods
              final previewPeriods = <(String, String)>[];
              final startText = dayStartCtrl.text.trim();
              final endText = dayEndCtrl.text.trim();
              final dur = int.tryParse(durationCtrl.text.trim()) ?? 0;
              final brk = int.tryParse(breakCtrl.text.trim()) ?? 0;

              if (startText.contains(':') && endText.contains(':') && dur > 0) {
                final sParts = startText.split(':');
                final eParts = endText.split(':');
                if (sParts.length >= 2 && eParts.length >= 2) {
                  var cursor = (int.tryParse(sParts[0]) ?? 0) * 60 +
                      (int.tryParse(sParts[1]) ?? 0);
                  final endMin = (int.tryParse(eParts[0]) ?? 0) * 60 +
                      (int.tryParse(eParts[1]) ?? 0);
                  while (cursor + dur <= endMin) {
                    final slotEnd = cursor + dur;
                    final s =
                        '${(cursor ~/ 60).toString().padLeft(2, '0')}:${(cursor % 60).toString().padLeft(2, '0')}';
                    final e =
                        '${(slotEnd ~/ 60).toString().padLeft(2, '0')}:${(slotEnd % 60).toString().padLeft(2, '0')}';
                    previewPeriods.add((s, e));
                    cursor = slotEnd + brk;
                  }
                }
              }

              return AlertDialog(
                title: Text(resetToDefaults ? '교시 설정 초기화' : '교시/요일 설정'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resetToDefaults
                              ? '기본값(평일 09:00~15:00 · 50분 교시)으로 되돌립니다. '
                                  '적용하면 현재 교시가 모두 지워지고 아래 미리보기대로 다시 만들어집니다.'
                              : '시간 범위와 교시 길이를 설정하면 자동으로 교시가 생성됩니다. '
                                  '적용하면 기존 교시는 새 설정으로 교체됩니다.',
                          style: Theme.of(dialogContext)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: NestColors.deepWood
                                    .withValues(alpha: 0.72),
                              ),
                        ),
                        const SizedBox(height: 16),

                        // Time range
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: dayStartCtrl,
                                decoration: const InputDecoration(
                                  labelText: '시작 시간',
                                  hintText: '09:00',
                                  isDense: true,
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text('~'),
                            ),
                            Expanded(
                              child: TextField(
                                controller: dayEndCtrl,
                                decoration: const InputDecoration(
                                  labelText: '종료 시간',
                                  hintText: '15:00',
                                  isDense: true,
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Duration & break
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: durationCtrl,
                                decoration: const InputDecoration(
                                  labelText: '교시 길이 (분)',
                                  hintText: '50',
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: breakCtrl,
                                decoration: const InputDecoration(
                                  labelText: '쉬는 시간 (분)',
                                  hintText: '10',
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Active days
                        Text(
                          '수업 요일',
                          style: Theme.of(dialogContext)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [1, 2, 3, 4, 5, 6, 0].map((day) {
                            final active = selectedDays.contains(day);
                            return FilterChip(
                              label: Text(_dayLabel(day)),
                              selected: active,
                              onSelected: (selected) {
                                setDialogState(() {
                                  if (selected) {
                                    selectedDays.add(day);
                                  } else {
                                    selectedDays.remove(day);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // Preview
                        const Divider(),
                        Text(
                          '미리보기 (${previewPeriods.length}교시)',
                          style: Theme.of(dialogContext)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        if (previewPeriods.isEmpty)
                          Text(
                            '설정을 입력하면 교시가 표시됩니다.',
                            style: Theme.of(dialogContext)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: NestColors.deepWood
                                      .withValues(alpha: 0.6),
                                ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: previewPeriods
                                .asMap()
                                .entries
                                .map((entry) {
                              return Chip(
                                avatar: CircleAvatar(
                                  radius: 12,
                                  child: Text(
                                    '${entry.key + 1}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                label: Text(
                                    '${entry.value.$1} - ${entry.value.$2}'),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('취소'),
                  ),
                  FilledButton(
                    onPressed: controller.isBusy ||
                            previewPeriods.isEmpty ||
                            selectedDays.isEmpty
                        ? null
                        : () async {
                            try {
                              await controller.regenerateTimeSlots(
                                dayStartTime: dayStartCtrl.text.trim(),
                                dayEndTime: dayEndCtrl.text.trim(),
                                slotDurationMinutes:
                                    int.parse(durationCtrl.text.trim()),
                                breakDurationMinutes:
                                    int.parse(breakCtrl.text.trim()),
                                activeDays: selectedDays,
                              );
                              _showMessage(controller.statusMessage);
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                              setState(() {});
                            } catch (e) {
                              _showMessage(e
                                  .toString()
                                  .replaceFirst('Exception: ', ''));
                            }
                          },
                    child: const Text('적용'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      dayStartCtrl.dispose();
      dayEndCtrl.dispose();
      durationCtrl.dispose();
      breakCtrl.dispose();
    }
  }

  Widget _buildClassContextCard(NestController controller) {
    final classGroups = controller.classGroups.toList()
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
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBoardCard(NestController controller) {
    final sortedSlots = controller.timeSlots.toList()
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

    final dayOrder = slotsByDay.keys.toList()..sort();
    var maxPeriods = 0;
    for (final slots in slotsByDay.values) {
      if (slots.length > maxPeriods) {
        maxPeriods = slots.length;
      }
    }

    // 읽기 전용 잠금: ARCHIVED(하드) + 지난 학기(소프트, 관리자 해제 가능).
    // 아래 잠금 UI(버튼 비활성/프로스트 오버레이)는 이 플래그로 일괄 제어된다.
    final archived = controller.isSelectedTermReadOnly;

    final boardContent = Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBoardHeader(controller, archived),
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
              _buildBoardBody(
                controller: controller,
                dayOrder: dayOrder,
                slotsByDay: slotsByDay,
                maxPeriods: maxPeriods,
                archived: archived,
              ),
          ],
        ),
      ),
    );

    // Keyboard shortcuts: Ctrl+Z (undo) / Ctrl+Shift+Z (redo) on the board.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyZ, control: true): () {
          if (!archived && !_isApplyingDraft && _canUndo) {
            _undo();
          }
        },
        const SingleActivator(
          LogicalKeyboardKey.keyZ,
          control: true,
          shift: true,
        ): () {
          if (!archived && !_isApplyingDraft && _canRedo) {
            _redo();
          }
        },
      },
      child: Focus(
        focusNode: _boardFocusNode,
        autofocus: true,
        child: Listener(
          // Re-acquire focus on any board interaction so the Ctrl+Z/Ctrl+Shift+Z
          // shortcuts keep working after focus moves elsewhere (dialogs etc.).
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) {
            if (!_boardFocusNode.hasFocus) {
              _boardFocusNode.requestFocus();
            }
          },
          child: boardContent,
        ),
      ),
    );
  }

  Widget _buildBoardHeader(NestController controller, bool archived) {
    final canCommit =
        _isDraftDirty && !controller.isBusy && !_isApplyingDraft && !archived;
    final historyEnabled = !controller.isBusy && !_isApplyingDraft && !archived;
    final wholeSchool = _viewMode == _TimetableViewMode.wholeSchool;
    // Per-class editing controls (undo/redo/commit/palette/exports) only make
    // sense in the editable build mode — both read-only modes hide them.
    final perClass = _viewMode == _TimetableViewMode.perClass;

    final undoButton = IconButton(
      icon: const Icon(Icons.undo),
      tooltip: '실행 취소 (Ctrl+Z)',
      onPressed: historyEnabled && _canUndo ? _undo : null,
    );
    final redoButton = IconButton(
      icon: const Icon(Icons.redo),
      tooltip: '다시 실행 (Ctrl+Shift+Z)',
      onPressed: historyEnabled && _canRedo ? _redo : null,
    );
    final paletteButton = IconButton(
      icon: Icon(
        _paletteOpen ? Icons.view_sidebar_outlined : Icons.view_sidebar,
      ),
      tooltip: _paletteOpen ? '팔레트 접기' : '팔레트 열기',
      onPressed: () => setState(() => _paletteOpen = !_paletteOpen),
    );

    final viewModeToggle = SegmentedButton<_TimetableViewMode>(
      segments: const [
        ButtonSegment(
          value: _TimetableViewMode.perClass,
          label: Text('반 빌드'),
          icon: Icon(Icons.dashboard_customize_outlined, size: 16),
        ),
        ButtonSegment(
          value: _TimetableViewMode.wholeSchool,
          label: Text('전교 보기'),
          icon: Icon(Icons.school_outlined, size: 16),
        ),
        ButtonSegment(
          value: _TimetableViewMode.emptyRoom,
          label: Text('빈 강의실', maxLines: 1, softWrap: false),
          icon: Icon(Icons.meeting_room_outlined, size: 16),
        ),
      ],
      selected: {_viewMode},
      showSelectedIcon: false,
      style: _kViewToggleStyle,
      onSelectionChanged: (values) {
        if (values.isEmpty) return;
        setState(() => _viewMode = values.first);
      },
    );

    final axisToggle = SegmentedButton<WholeSchoolAxis>(
      segments: const [
        ButtonSegment(value: WholeSchoolAxis.byClass, label: Text('반')),
        ButtonSegment(value: WholeSchoolAxis.byRoom, label: Text('장소')),
        ButtonSegment(value: WholeSchoolAxis.byTeacher, label: Text('선생')),
      ],
      selected: {_wholeSchoolAxis},
      showSelectedIcon: false,
      style: const ButtonStyle(visualDensity: VisualDensity.compact),
      onSelectionChanged: (values) {
        if (values.isEmpty) return;
        setState(() => _wholeSchoolAxis = values.first);
      },
    );

    return LayoutBuilder(
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
                  // Per-class-only controls hidden in the read-only modes.
                  if (perClass) ...[
                    undoButton,
                    redoButton,
                    paletteButton,
                  ],
                ],
              ),
              const SizedBox(height: 8),
              viewModeToggle,
              if (wholeSchool) ...[
                const SizedBox(height: 8),
                axisToggle,
              ] else if (perClass) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: canCommit ? _commitDraftChanges : null,
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('수정 확정'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy || _isApplyingDraft
                          ? null
                          : () => _openRoomUtilizationExportDialog(controller),
                      icon: const Icon(Icons.meeting_room_outlined, size: 18),
                      label: const Text('교실 상황표 내보내기'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy
                          ? null
                          : () => showFamilyEnrollmentDialog(
                                context,
                                widget.controller,
                              ),
                      icon: const Icon(Icons.family_restroom, size: 18),
                      label: const Text('가정·학생 배정'),
                    ),
                  ],
                ),
              ],
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
            viewModeToggle,
            const SizedBox(width: 8),
            if (wholeSchool)
              axisToggle
            else if (perClass) ...[
              undoButton,
              redoButton,
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: canCommit ? _commitDraftChanges : null,
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
              FilledButton.tonalIcon(
                onPressed: controller.isBusy
                    ? null
                    : () => showFamilyEnrollmentDialog(
                          context,
                          widget.controller,
                        ),
                icon: const Icon(Icons.family_restroom),
                label: const Text('가정·학생 배정'),
              ),
              const SizedBox(width: 8),
              paletteButton,
            ],
          ],
        );
      },
    );
  }

  Widget _buildBoardBody({
    required NestController controller,
    required List<int> dayOrder,
    required Map<int, List<TimeSlot>> slotsByDay,
    required int maxPeriods,
    required bool archived,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // "빈 강의실 찾기" is a self-contained read-only picker.
        if (_viewMode == _TimetableViewMode.emptyRoom) {
          return EmptyRoomFinder(controller: controller);
        }

        final wholeSchool = _viewMode == _TimetableViewMode.wholeSchool;
        // Read-only inspector rail shows on wide layouts in BOTH modes.
        final showInspector = constraints.maxWidth >= 1500;

        if (wholeSchool) {
          // Whole-school overlay is STRICTLY READ-ONLY: no palette, no trash
          // zone, and the ARCHIVED edit lock does NOT apply.
          final board = WholeSchoolOverlayBoard(
            controller: controller,
            axis: _wholeSchoolAxis,
            onColumnTap: (ref) => setState(() => _pendingInspect = ref),
          );

          if (showInspector) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: board),
                const SizedBox(width: 12),
                SizedBox(
                  width: 290,
                  child: _buildInspectorRail(controller),
                ),
              ],
            );
          }
          return board;
        }

        final showSidePalette =
            _paletteOpen && constraints.maxWidth >= 1220;

        final Widget editableArea;
        if (showSidePalette) {
          editableArea = Row(
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
        } else {
          editableArea = Column(
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
        }

        final showTrash =
            !archived && _activeDrag?.kind == DragPayloadType.session;

        // The editable grid + drag/trash/archived overlay only covers the
        // per-class editing surface, keeping the inspector rail outside the
        // ARCHIVED frosted lock.
        final editableStack = Stack(
          children: [
            editableArea,
            // Drag-to-delete trash zone (bottom-right) while dragging a session.
            Positioned(
              right: 12,
              bottom: 12,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: showTrash ? 1 : 0,
                child: IgnorePointer(
                  ignoring: !showTrash,
                  child: _buildTrashZone(),
                ),
              ),
            ),
            // ARCHIVED lock overlay (per-class edit mode only).
            if (archived)
              Positioned.fill(
                child: _buildArchivedOverlay(),
              ),
          ],
        );

        if (showInspector) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: editableStack),
              const SizedBox(width: 12),
              SizedBox(
                width: 290,
                child: _buildInspectorRail(controller),
              ),
            ],
          );
        }
        return editableStack;
      },
    );
  }

  Widget _buildInspectorRail(NestController controller) {
    // Tapping a CLASS column header in the whole-school board pins the rail to
    // that class (re-keyed so initState re-seeds the selection). Room/teacher
    // column taps are left to the rail's own segmented picker, so they don't
    // disrupt manual inspector navigation.
    final pending = _pendingInspect;
    final pinnedClassId =
        pending != null && pending.axis == WholeSchoolAxis.byClass
            ? pending.id
            : null;
    final initialClassId = pinnedClassId ?? controller.selectedClassGroupId;
    return ObjectInspectorRail(
      key: ValueKey('inspector-${pinnedClassId ?? 'self'}'),
      controller: controller,
      initialClassGroupId: initialClassId,
    );
  }

  Widget _buildTrashZone() {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) => details.data is DragPayload &&
          (details.data as DragPayload).type == DragPayloadType.session,
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data is DragPayload && data.type == DragPayloadType.session) {
          _deleteDraftSession(data.id);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: hovering
                ? Colors.red.shade400
                : NestColors.clay.withValues(alpha: 0.9),
            border: Border.all(
              color: hovering ? Colors.red.shade700 : NestColors.clay,
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.delete_outline, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                '여기로 드래그하여 삭제',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildArchivedOverlay() {
    final controller = widget.controller;
    final message = controller.isSelectedTermArchived
        ? '이 학기는 보관됨(ARCHIVED) 상태입니다. 시간표를 수정할 수 없습니다.'
        : '지난 학기입니다(읽기 전용). 상단 학기 바에서 편집 잠금을 해제하면 수정할 수 있습니다.';
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Container(
        color: Colors.white.withValues(alpha: 0.6),
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
            border: Border.all(color: NestColors.clay),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, color: NestColors.clay),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTimetableExportDialog() async {
    final controller = widget.controller;
    final sortedSlots = controller.timeSlots.toList()
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
    final dayOrder = slotsByDay.keys.toList()..sort();
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
    final sortedSlots = controller.timeSlots.toList()
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) return day;
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

    // Collect all sessions and group by location
    final sessionsBySlotId = <String, List<ClassSession>>{};
    for (final session in controller.allTermSessions) {
      sessionsBySlotId.putIfAbsent(session.timeSlotId, () => []);
      sessionsBySlotId[session.timeSlotId]!.add(session);
    }

    // Collect all room names from sessions + classrooms
    final roomNames = <String>{};
    for (final session in controller.allTermSessions) {
      final loc = (session.location ?? '').trim();
      if (loc.isNotEmpty) roomNames.add(loc);
    }
    for (final classroom in controller.classrooms) {
      roomNames.add(classroom.name.trim());
    }
    final roomOrder = roomNames.toList()..sort();

    if (roomOrder.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: NestColors.creamyWhite,
          border: Border.all(color: NestColors.roseMist),
        ),
        child: const Text('배정된 교실이 없습니다.'),
      );
    }

    // Collect unique time periods across all days
    final periodSet = <String>{};
    final slotsByPeriodDay = <String, Map<int, TimeSlot>>{};
    for (final slot in sortedSlots) {
      final key = '${slot.startTime}\t${slot.endTime}';
      periodSet.add(key);
      slotsByPeriodDay.putIfAbsent(key, () => {});
      slotsByPeriodDay[key]![slot.dayOfWeek] = slot;
    }
    final uniquePeriods = periodSet.toList()..sort();

    // Collect days
    final daySet = <int>{};
    for (final slot in sortedSlots) {
      daySet.add(slot.dayOfWeek);
    }
    final dayOrder = daySet.toList()..sort();

    const timeWidth = 112.0;
    const gap = 6.0;
    const targetExportWidth = 1260.0;
    final baseRoomWidth = roomOrder.isEmpty
        ? 140.0
        : ((targetExportWidth - timeWidth - (roomOrder.length + 1) * gap) /
                  roomOrder.length)
              .clamp(120.0, 180.0);
    final roomWidth = forExport ? baseRoomWidth : 150.0;
    final boardWidth =
        timeWidth +
        (roomOrder.length * roomWidth) +
        (roomOrder.length + 1) * gap;
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '교실 상황표',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            // Header: 시간 | 교실1 | 교실2 | ...
            Row(
              children: [
                _GridHeaderCell(width: timeWidth, title: '시간'),
                ...roomOrder.map(
                  (room) => _GridHeaderCell(width: roomWidth, title: room),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // For each day, render a day-header row then time rows
            ...dayOrder.expand((day) {
              final periodsForDay = uniquePeriods.where((pk) {
                return slotsByPeriodDay[pk]?.containsKey(day) == true;
              }).toList();
              if (periodsForDay.isEmpty) return <Widget>[];

              return [
                // Day label row
                Container(
                  width: timeWidth +
                      roomOrder.length * roomWidth +
                      roomOrder.length * gap,
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: NestColors.roseMist.withValues(alpha: 0.35),
                  ),
                  child: Text(
                    '${_dayLabel(day)}요일',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                // Time rows for this day
                ...periodsForDay.map((periodKey) {
                  final parts = periodKey.split('\t');
                  final timeLabel =
                      '${_shortTime(parts[0])}-${_shortTime(parts[1])}';
                  final slot = slotsByPeriodDay[periodKey]![day]!;
                  final sessions = sessionsBySlotId[slot.id] ?? [];

                  // Group sessions by room for this slot
                  final sessionsByRoom = <String, List<ClassSession>>{};
                  for (final session in sessions) {
                    final loc = (session.location ?? '').trim();
                    if (loc.isEmpty) continue;
                    sessionsByRoom.putIfAbsent(loc, () => []);
                    sessionsByRoom[loc]!.add(session);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: timeWidth,
                          margin: const EdgeInsets.only(right: gap),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: NestColors.creamyWhite,
                            border: Border.all(color: NestColors.roseMist),
                          ),
                          child: Text(
                            timeLabel,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        ...roomOrder.map((room) {
                          final roomSessions = sessionsByRoom[room] ?? [];
                          return Container(
                            width: roomWidth,
                            margin: const EdgeInsets.only(right: gap),
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(minHeight: 38),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: roomSessions.isEmpty
                                  ? Colors.white
                                  : NestColors.creamyWhite,
                              border: Border.all(color: NestColors.roseMist),
                            ),
                            child: roomSessions.isEmpty
                                ? (forExport
                                    ? const SizedBox.shrink()
                                    : Text(
                                        '-',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: NestColors.deepWood
                                                  .withValues(alpha: 0.3),
                                            ),
                                      ))
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: roomSessions.map((session) {
                                      final className =
                                          controller.findClassGroupName(
                                        session.classGroupId,
                                      );
                                      final courseName =
                                          controller.findCourseName(
                                        session.courseId,
                                      );
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 2),
                                        child: Text(
                                          '$className\n$courseName',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                          );
                        }),
                      ],
                    ),
                  );
                }),
              ];
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPalettePanel(NestController controller) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        children: [
          _buildComposerSection(controller),
          const Divider(height: 1),
          _buildPaletteSection(
            title: '과목 팔레트',
            subtitle: '${controller.courses.length}개',
            icon: Icons.auto_stories_outlined,
            onAdd: controller.isBusy
                ? null
                : () => _openQuickCourseDialog(controller),
            addTooltip: '과목 추가',
            child: _buildCoursePaletteContent(controller),
          ),
          const Divider(height: 1),
          _buildPaletteSection(
            title: '선생님 팔레트',
            subtitle: '${controller.teacherProfiles.length}명',
            icon: Icons.person_outline,
            onAdd: controller.isBusy
                ? null
                : () => _openQuickTeacherDialog(controller),
            addTooltip: '선생님 추가',
            child: _buildTeacherPaletteContent(controller),
          ),
          const Divider(height: 1),
          _buildPaletteSection(
            title: '교실 팔레트',
            subtitle: '${_roomPalette.length}개',
            icon: Icons.meeting_room_outlined,
            onAdd: controller.isBusy
                ? null
                : () => _openQuickClassroomDialog(controller),
            addTooltip: '교실 추가',
            child: _buildRoomPaletteContent(controller),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerSection(NestController controller) {
    final courses = controller.courses.toList();
    final teachers = controller.teacherProfiles.toList();
    final rooms = _roomPalette.toList()..sort();
    final locked = _dragsLocked;

    // Keep selection valid if the underlying lists changed.
    final courseValue =
        courses.any((c) => c.id == _composeCourseId) ? _composeCourseId : null;
    final teacherValue = teachers.any((t) => t.id == _composeTeacherId)
        ? _composeTeacherId
        : null;
    final roomValue = rooms.contains(_composeRoom) ? _composeRoom : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dashboard_customize_outlined,
                  size: 20, color: NestColors.dustyRose),
              const SizedBox(width: 8),
              Text(
                '수업 카드 조립',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String?>(
            initialValue: courseValue,
            isDense: true,
            decoration: const InputDecoration(
              labelText: '과목',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('과목 선택'),
              ),
              ...courses.map(
                (course) => DropdownMenuItem<String?>(
                  value: course.id,
                  child: Text(course.name),
                ),
              ),
            ],
            onChanged: locked
                ? null
                : (value) {
                    setState(() {
                      _composeCourseId = value;
                      _composedCard = null;
                    });
                  },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: teacherValue,
            isDense: true,
            decoration: const InputDecoration(
              labelText: '주강사 (선택)',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('미지정'),
              ),
              ...teachers.map(
                (teacher) => DropdownMenuItem<String?>(
                  value: teacher.id,
                  child: Text(teacher.displayName),
                ),
              ),
            ],
            onChanged: locked
                ? null
                : (value) {
                    setState(() {
                      _composeTeacherId = value;
                      _composedCard = null;
                    });
                  },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: roomValue,
            isDense: true,
            decoration: const InputDecoration(
              labelText: '장소 (선택)',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('미지정'),
              ),
              ...rooms.map(
                (room) => DropdownMenuItem<String?>(
                  value: room,
                  child: Text(room),
                ),
              ),
            ],
            onChanged: locked
                ? null
                : (value) {
                    setState(() {
                      _composeRoom = value;
                      _composedCard = null;
                    });
                  },
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: (locked || courseValue == null)
                  ? null
                  : () {
                      setState(() {
                        _composedCard = ComposedSessionPayload(
                          courseId: courseValue,
                          teacherProfileId: teacherValue,
                          location: roomValue,
                        );
                      });
                    },
              icon: const Icon(Icons.add_box_outlined, size: 18),
              label: const Text('카드 만들기'),
            ),
          ),
          if (_composedCard != null) ...[
            const SizedBox(height: 10),
            _buildComposedCardChip(controller, _composedCard!, locked),
          ],
        ],
      ),
    );
  }

  /// Renders the assembled card as a `Draggable<ComposedSessionPayload>` chip.
  Widget _buildComposedCardChip(
    NestController controller,
    ComposedSessionPayload card,
    bool locked,
  ) {
    final label = _composedCardLabel(controller, card);
    final chip = _ComposedCardChip(label: label);
    return Draggable<ComposedSessionPayload>(
      data: card,
      maxSimultaneousDrags: locked ? 0 : null,
      onDragStarted: () => _beginDrag(
        _ActiveDrag(
          kind: DragPayloadType.course,
          courseId: card.courseId,
          teacherProfileId: card.teacherProfileId,
        ),
      ),
      onDragEnd: (_) => _endDrag(),
      onDraggableCanceled: (velocity, offset) => _endDrag(),
      feedback: Material(
        color: Colors.transparent,
        child: _ComposedCardChip(label: label, dragging: true),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: chip),
      child: chip,
    );
  }

  String _composedCardLabel(
    NestController controller,
    ComposedSessionPayload card,
  ) {
    final parts = <String>[controller.findCourseName(card.courseId)];
    if (card.hasTeacher) {
      parts.add(controller.findTeacherName(card.teacherProfileId!.trim()));
    }
    if (card.hasLocation) {
      parts.add(card.location!.trim());
    }
    return parts.join(' · ');
  }

  Widget _buildPaletteSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onAdd,
    required String addTooltip,
    required Widget child,
  }) {
    return ExpansionTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: Theme.of(context).textTheme.titleSmall),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onAdd,
            icon: const Icon(Icons.add_circle_outline, size: 20),
            tooltip: addTooltip,
            visualDensity: VisualDensity.compact,
          ),
          const Icon(Icons.expand_more, size: 20),
        ],
      ),
      tilePadding: const EdgeInsets.symmetric(horizontal: 12),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      children: [child],
    );
  }

  Widget _buildCoursePaletteContent(NestController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.courses.isEmpty)
          const Text('과목이 없습니다. 우측 + 버튼으로 바로 추가하세요.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.courses
                .map(
                  (course) => Draggable<DragPayload>(
                    data: DragPayload(
                      type: DragPayloadType.course,
                      id: course.id,
                    ),
                    maxSimultaneousDrags: _dragsLocked ? 0 : null,
                    onDragStarted: () => _beginDrag(
                      _ActiveDrag(
                        kind: DragPayloadType.course,
                        courseId: course.id,
                      ),
                    ),
                    onDragEnd: (_) => _endDrag(),
                    onDraggableCanceled: (velocity, offset) => _endDrag(),
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
                .toList(),
          ),
      ],
    );
  }

  Widget _buildTeacherPaletteContent(NestController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (controller.teacherProfiles.isEmpty)
          const Text('등록된 교사가 없습니다. 우측 + 버튼으로 바로 추가하세요.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: controller.teacherProfiles
                .map(
                  (teacher) => Draggable<DragPayload>(
                    data: DragPayload(
                      type: DragPayloadType.teacher,
                      id: teacher.id,
                    ),
                    maxSimultaneousDrags: _dragsLocked ? 0 : null,
                    onDragStarted: () => _beginDrag(
                      _ActiveDrag(
                        kind: DragPayloadType.teacher,
                        teacherProfileId: teacher.id,
                      ),
                    ),
                    onDragEnd: (_) => _endDrag(),
                    onDraggableCanceled: (velocity, offset) => _endDrag(),
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
                .toList(),
          ),
      ],
    );
  }

  Widget _buildRoomPaletteContent(NestController controller) {
    final rooms = _roomPalette.toList()..sort();
    final classroomByName = {
      for (final classroom in controller.classrooms)
        classroom.name.trim().toLowerCase(): classroom,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (rooms.isEmpty)
          const Text('등록된 교실이 없습니다. 우측 + 버튼으로 바로 추가하세요.')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: rooms
                .map((room) {
                  final linkedClassroom = classroomByName[room.toLowerCase()];
                  return Draggable<DragPayload>(
                    data: DragPayload(type: DragPayloadType.room, id: room),
                    maxSimultaneousDrags: _dragsLocked ? 0 : null,
                    onDragStarted: () => _beginDrag(
                      const _ActiveDrag(kind: DragPayloadType.room),
                    ),
                    onDragEnd: (_) => _endDrag(),
                    onDraggableCanceled: (velocity, offset) => _endDrag(),
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
                .toList(),
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
            .toList();
        _draftAssignments = {
          for (final entry in _draftAssignments.entries)
            if (!removedSessionIds.contains(entry.key)) entry.key: entry.value,
        };
        _setDirty(true);
      });
    }
    // A server-side delete is irreversible; drop draft history so undo cannot
    // restore sessions that reference the now-deleted course.
    _clearHistory();
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
          .toList();
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
    // Irreversible server delete → clear draft history (undo must not restore
    // assignments referencing the now-deleted teacher).
    _clearHistory();
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
        .toList();

    setState(() {
      _ensureRoomPaletteFromController(controller);
      if (removedFromDraft) {
        _draftSessions = nextDraftSessions;
        _setDirty(true);
      }
    });
    // Irreversible server delete → clear draft history.
    _clearHistory();
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
    final sortedSlots = controller.timeSlots.toList()
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
    final dayOrder = slotsByDay.keys.toList()..sort();
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
          // Export renders are static snapshots: no live drag feedback.
          final activeDrag = forExport ? null : _activeDrag;
          final conflictState = activeDrag == null
              ? DropConflictState.none
              : _evaluateDropConflict(
                  slot.id,
                  kind: activeDrag.kind,
                  courseId: activeDrag.courseId,
                  teacherProfileId: activeDrag.teacherProfileId,
                  movingSessionId: activeDrag.sessionId,
                );
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
            onComposedDrop: (payload) => _handleComposedDrop(slot.id, payload),
            onTapSession: _openSessionSettingDialog,
            onDeleteSession: _deleteDraftSession,
            onSessionMenu: _openSessionMenu,
            sessionMenuEnabled: !forExport &&
                !controller.isSelectedTermReadOnly &&
                !controller.isBusy,
            onSessionDragStarted: (sessionId) => _beginDrag(
              _ActiveDrag(
                kind: DragPayloadType.session,
                sessionId: sessionId,
              ),
            ),
            onSessionDragEnded: _endDrag,
            dragsLocked: _dragsLocked,
            activeDrag: activeDrag,
            conflictState: conflictState,
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
                    title: '시간',
                  ),
                  ...dayOrder.map(
                    (day) => _GridHeaderCell(
                      width: dynamicDayWidth,
                      title: '${_dayLabel(day)}요일',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...() {
                // Time-based alignment: collect unique periods across all days
                final periodSet = <String>{};
                final slotByPeriodDay = <String, Map<int, TimeSlot>>{};
                for (final dayEntry in slotsByDay.entries) {
                  for (final slot in dayEntry.value) {
                    final key = '${slot.startTime}\t${slot.endTime}';
                    periodSet.add(key);
                    slotByPeriodDay
                        .putIfAbsent(key, () => <int, TimeSlot>{});
                    slotByPeriodDay[key]![dayEntry.key] = slot;
                  }
                }
                final uniquePeriods = periodSet.toList()
                  ..sort();

                return uniquePeriods.map((periodKey) {
                  final parts = periodKey.split('\t');
                  final timeLabel =
                      '${_shortTime(parts[0])}-${_shortTime(parts[1])}';
                  final slotsForPeriod =
                      slotByPeriodDay[periodKey] ?? const <int, TimeSlot>{};

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: periodWidth,
                          constraints:
                              BoxConstraints(minHeight: slotMinHeight),
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: NestColors.creamyWhite,
                            border: Border.all(color: NestColors.roseMist),
                          ),
                          child: Text(
                            timeLabel,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        ...dayOrder.map((day) {
                          final slot = slotsForPeriod[day];
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
                                border:
                                    Border.all(color: Colors.grey.shade300),
                              ),
                              child: Center(
                                child: Text(
                                  '해당 슬롯 없음',
                                  style:
                                      Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            );
                          }

                          return Container(
                            width: dynamicDayWidth,
                            constraints:
                                BoxConstraints(minHeight: slotMinHeight),
                            margin: const EdgeInsets.only(right: 6),
                            child: slotCellBuilder(slot),
                          );
                        }),
                      ],
                    ),
                  );
                });
              }(),
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
        .toList();

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
      // Prefer the atomic batch RPC; fall back to the per-call loop when the
      // optional `apply_timetable_draft` function is not deployed.
      final didBatch = await _tryCommitViaBatch(controller, classGroupId);
      if (!didBatch) {
        await _commitDraftViaIndividualCalls(controller);
      }

      // Ensure parent tab guard state is cleared immediately after successful commit.
      _setDirty(false, forceNotify: true);
      _clearHistory();
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

  /// Attempts the atomic batch commit via the optional `apply_timetable_draft`
  /// RPC. Returns true when applied, or false when the RPC is unavailable so
  /// the caller falls back to [_commitDraftViaIndividualCalls]. Real errors
  /// (TEACHER_SLOT_CONFLICT, RLS denial, etc.) propagate to the caller.
  Future<bool> _tryCommitViaBatch(
    NestController controller,
    String classGroupId,
  ) async {
    final sessions = <Map<String, dynamic>>[];
    for (final row in _draftSessions) {
      final desiredRows = (_draftAssignments[row.id] ?? const []).toList(
        growable: false,
      );
      final mainTeacherId = desiredRows
          .where((assignment) => assignment.assignmentRole == 'MAIN')
          .map((assignment) => assignment.teacherProfileId)
          .firstOrNull;
      final assistantIds = desiredRows
          .where((assignment) => assignment.assignmentRole == 'ASSISTANT')
          .map((assignment) => assignment.teacherProfileId)
          .where((id) => id != mainTeacherId)
          .toSet()
          .toList(growable: false);

      final location = (row.location ?? '').trim();

      sessions.add(<String, dynamic>{
        'id': row.isNew ? null : row.id,
        'course_id': row.courseId,
        'time_slot_id': row.timeSlotId,
        'title': row.title.isEmpty
            ? '${controller.findCourseName(row.courseId)} 수업'
            : row.title,
        'location': location.isEmpty ? null : location,
        'main_teacher_id': mainTeacherId,
        'assistant_ids': assistantIds,
      });
    }

    final existingDraftIds = _draftSessions
        .where((row) => !row.isNew)
        .map((row) => row.id)
        .toSet();
    final deletedIds = controller.sessions
        .where((row) => !existingDraftIds.contains(row.id))
        .map((row) => row.id)
        .toList();

    try {
      await controller.applyTimetableDraft(
        classGroupId: classGroupId,
        sessions: sessions,
        deletedIds: deletedIds,
      );
      return true;
    } on TimetableBatchUnsupported {
      return false;
    }
  }

  /// Per-call commit path (legacy fallback). Logic is unchanged from the
  /// original inline loop in [_commitDraftChanges]; only relocated here.
  Future<void> _commitDraftViaIndividualCalls(NestController controller) async {
    final initialSessions = controller.sessions.toList();
    final initialIds = initialSessions.map((row) => row.id).toSet();

    final existingDraftRows = _draftSessions
        .where((row) => !row.isNew && initialIds.contains(row.id))
        .toList();
    final existingDraftIds = existingDraftRows.map((row) => row.id).toSet();

    final deleteIds = initialSessions
        .where((row) => !existingDraftIds.contains(row.id))
        .map((row) => row.id)
        .toList();

    for (final sessionId in deleteIds) {
      await controller.deleteSession(sessionId);
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
          .toList()
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
      case DragPayloadType.child:
        // Child drags are not valid drop targets on slots in Phase 1.
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

    _pushUndo();
    setState(() {
      _draftSessions = [..._draftSessions, next];
      _setDirty(true);
    });
  }

  /// Handles dropping a fully-assembled "수업 카드 조립" card on an EMPTY cell:
  /// creates the session and applies the main teacher + location in one gesture.
  void _handleComposedDrop(String slotId, ComposedSessionPayload payload) {
    final controller = widget.controller;
    final occupied = _draftSessions.any((row) => row.timeSlotId == slotId);
    if (occupied) {
      _showMessage('이미 수업이 있는 슬롯입니다.');
      return;
    }

    final slot = controller.findTimeSlot(slotId);
    if (slot == null) {
      _showMessage('슬롯 정보를 찾을 수 없습니다.');
      return;
    }
    if (payload.hasTeacher) {
      final conflict = _hasTeacherSlotConflict(
        teacherProfileId: payload.teacherProfileId!.trim(),
        timeSlotId: slot.id,
        courseId: payload.courseId,
      );
      if (conflict) {
        _showMessage(
          '교사 충돌: ${controller.findTeacherName(payload.teacherProfileId!.trim())} 같은 시간 다른 수업에 배정됨',
        );
        return;
      }
    }

    final sessionId = 'tmp-manual-${DateTime.now().microsecondsSinceEpoch}';
    final location = payload.hasLocation ? payload.location!.trim() : null;
    final next = _EditableSession(
      id: sessionId,
      courseId: payload.courseId,
      timeSlotId: slotId,
      title: '${controller.findCourseName(payload.courseId)} 수업',
      isNew: true,
      location: location,
    );

    final assignments = <_EditableAssignment>[];
    if (payload.hasTeacher) {
      assignments.add(
        _EditableAssignment(
          teacherProfileId: payload.teacherProfileId!.trim(),
          assignmentRole: 'MAIN',
        ),
      );
    }

    _pushUndo();
    setState(() {
      _draftSessions = [..._draftSessions, next];
      if (assignments.isNotEmpty) {
        _draftAssignments = {..._draftAssignments, sessionId: assignments};
      }
      if (location != null && location.isNotEmpty) {
        _roomPalette = {..._roomPalette, location};
      }
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

    _pushUndo();
    setState(() {
      _draftSessions = _draftSessions
          .map(
            (row) => row.id == sessionId
                ? row.copyWith(timeSlotId: targetSlotId)
                : row,
          )
          .toList();
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

    // One-session-per-slot holds within a class, so a single session applies
    // directly. The picker remains for safety if more than one ever appears.
    final session = slotSessions.length <= 1
        ? slotSessions.first
        : await _pickSessionForSlot(slotSessions, '교사를 배정할 수업 선택');

    if (session == null) {
      return;
    }

    // Mirror the DB guard before applying: reject hard teacher conflicts.
    final slot = widget.controller.findTimeSlot(slotId);
    if (slot != null &&
        _hasTeacherSlotConflict(
          teacherProfileId: teacherProfileId,
          timeSlotId: slot.id,
          courseId: session.courseId,
          excludeSessionId: session.id,
        )) {
      _showMessage(
        '교사 충돌: ${widget.controller.findTeacherName(teacherProfileId)} 같은 시간 다른 수업에 배정됨',
      );
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

    // One-session-per-slot holds within a class, so a single session applies
    // directly. The picker remains for safety if more than one ever appears.
    final session = slotSessions.length <= 1
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
                .toList(),
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
    // 읽기 전용(지난/보관) 학기에서는 세션 편집 다이얼로그를 열지 않는다
    // (_openSessionMenu와 동일한 방어선).
    if (controller.isSelectedTermReadOnly || controller.isBusy) {
      return;
    }
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
            final roomOptions = _roomPalette.toList()..sort();
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
                      DropdownButtonFormField<String?>(
                        initialValue: mainTeacherId,
                        decoration: const InputDecoration(labelText: '주강사'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('미지정'),
                          ),
                          ...controller.teacherProfiles.map(
                            (teacher) => DropdownMenuItem<String?>(
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
                              .toList(),
                        ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedClassroom,
                        decoration: const InputDecoration(labelText: '교실'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('미지정'),
                          ),
                          ...roomOptions.map(
                            (room) => DropdownMenuItem<String?>(
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
                              .toList(),
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

    _pushUndo();
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
        .toList();

    final next = [
      _EditableAssignment(
        teacherProfileId: teacherProfileId,
        assignmentRole: 'MAIN',
      ),
      ...current,
    ];

    _pushUndo();
    setState(() {
      _draftAssignments = {..._draftAssignments, sessionId: next};
      _setDirty(true);
    });
  }

  void _setSessionLocation(String sessionId, String location) {
    final normalized = RoomNormalizer.normalize(location);
    _pushUndo();
    setState(() {
      _draftSessions = _draftSessions
          .map(
            (row) => row.id == sessionId
                ? row.copyWith(location: normalized.isEmpty ? null : normalized)
                : row,
          )
          .toList();
      if (normalized.isNotEmpty) {
        _roomPalette = {..._roomPalette, normalized};
      }
      _setDirty(true);
    });
  }

  void _deleteDraftSession(String sessionId) {
    _pushUndo();
    setState(() {
      _draftSessions = _draftSessions
          .where((row) => row.id != sessionId)
          .toList();
      _draftAssignments = {
        for (final entry in _draftAssignments.entries)
          if (entry.key != sessionId) entry.key: entry.value,
      };
      _setDirty(true);
    });
  }

  // ---------------------------------------------------------------------------
  // Bulk power-moves (session context menu → draft-only replication)
  // ---------------------------------------------------------------------------

  /// Opens the per-session context menu at [globalPosition] and routes the
  /// chosen [_BulkAction] to its draft-only handler. Gated by the caller, but
  /// re-checked here so the menu never mutates a read-only/archived board.
  Future<void> _openSessionMenu(
    String sessionId,
    Offset globalPosition,
  ) async {
    final controller = widget.controller;
    if (controller.isSelectedTermReadOnly || controller.isBusy) {
      return;
    }
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) {
      return;
    }

    final selected = await showMenu<_BulkAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: const [
        PopupMenuItem<_BulkAction>(
          value: _BulkAction.fillDay,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.calendar_view_day_outlined),
            title: Text('이 요일 전체에 적용'),
          ),
        ),
        PopupMenuItem<_BulkAction>(
          value: _BulkAction.fillPeriod,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.view_week_outlined),
            title: Text('이 교시 모든 요일에 적용'),
          ),
        ),
        PopupMenuItem<_BulkAction>(
          value: _BulkAction.fillWeek,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.grid_view_outlined),
            title: Text('주 전체 채우기'),
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem<_BulkAction>(
          value: _BulkAction.duplicateToComposer,
          child: ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.dashboard_customize_outlined),
            title: Text('수업 복제(카드로)'),
          ),
        ),
      ],
    );

    if (selected == null || !mounted) {
      return;
    }

    switch (selected) {
      case _BulkAction.fillDay:
        _bulkFillDay(sessionId);
        break;
      case _BulkAction.fillPeriod:
        _bulkFillPeriod(sessionId);
        break;
      case _BulkAction.fillWeek:
        _bulkFillWeek(sessionId);
        break;
      case _BulkAction.duplicateToComposer:
        _replicateToComposer(sessionId);
        break;
    }
  }

  /// Replicates the source session into every EMPTY time slot on the same day
  /// of the week. Occupied or teacher-conflicting slots are skipped.
  void _bulkFillDay(String sessionId) {
    final source = _draftSessions
        .where((row) => row.id == sessionId)
        .firstOrNull;
    if (source == null) {
      return;
    }
    final sourceSlot = widget.controller.findTimeSlot(source.timeSlotId);
    if (sourceSlot == null) {
      _showMessage('슬롯 정보를 찾을 수 없습니다.');
      return;
    }
    final targets = widget.controller.timeSlots
        .where(
          (slot) =>
              slot.dayOfWeek == sourceSlot.dayOfWeek &&
              slot.id != source.timeSlotId,
        )
        .toList();
    _applyBulkFill(source, targets);
  }

  /// Replicates the source session into the same period (start/end time) on
  /// every day of the week. Occupied or teacher-conflicting slots are skipped.
  void _bulkFillPeriod(String sessionId) {
    final source = _draftSessions
        .where((row) => row.id == sessionId)
        .firstOrNull;
    if (source == null) {
      return;
    }
    final sourceSlot = widget.controller.findTimeSlot(source.timeSlotId);
    if (sourceSlot == null) {
      _showMessage('슬롯 정보를 찾을 수 없습니다.');
      return;
    }
    final targets = widget.controller.timeSlots
        .where(
          (slot) =>
              slot.startTime == sourceSlot.startTime &&
              slot.endTime == sourceSlot.endTime &&
              slot.id != source.timeSlotId,
        )
        .toList();
    _applyBulkFill(source, targets);
  }

  /// Replicates the source session into EVERY time slot of the week. Occupied
  /// or teacher-conflicting slots are skipped.
  void _bulkFillWeek(String sessionId) {
    final source = _draftSessions
        .where((row) => row.id == sessionId)
        .firstOrNull;
    if (source == null) {
      return;
    }
    final targets = widget.controller.timeSlots
        .where((slot) => slot.id != source.timeSlotId)
        .toList();
    _applyBulkFill(source, targets);
  }

  /// Shared engine for the three fill actions. For each [targetSlots] entry,
  /// creates a draft session copying [source]'s course + location + teacher
  /// assignments when the slot is EMPTY and the source's MAIN teacher (if any)
  /// would not introduce a HARD teacher conflict for the source course. Slots
  /// that are occupied or would conflict are skipped and counted.
  void _applyBulkFill(
    _EditableSession source,
    List<TimeSlot> targetSlots,
  ) {
    final sourceAssignments = (_draftAssignments[source.id] ?? const [])
        .toList(growable: false);
    final mainTeacherId = sourceAssignments
        .where((row) => row.assignmentRole == 'MAIN')
        .map((row) => row.teacherProfileId)
        .firstOrNull;
    final location = (source.location ?? '').trim();
    final normalizedLocation =
        location.isEmpty ? null : RoomNormalizer.normalize(location);

    final newSessions = <_EditableSession>[];
    final newAssignments = <String, List<_EditableAssignment>>{};
    var skipped = 0;

    for (final slot in targetSlots) {
      final occupied = _draftSessions.any((row) => row.timeSlotId == slot.id) ||
          newSessions.any((row) => row.timeSlotId == slot.id);
      if (occupied) {
        skipped++;
        continue;
      }
      if (mainTeacherId != null &&
          _hasTeacherSlotConflict(
            teacherProfileId: mainTeacherId,
            timeSlotId: slot.id,
            courseId: source.courseId,
          )) {
        skipped++;
        continue;
      }

      final newId =
          'tmp-manual-${DateTime.now().microsecondsSinceEpoch}-${newSessions.length}';
      newSessions.add(
        _EditableSession(
          id: newId,
          courseId: source.courseId,
          timeSlotId: slot.id,
          title: '${widget.controller.findCourseName(source.courseId)} 수업',
          location: normalizedLocation,
          isNew: true,
        ),
      );
      if (sourceAssignments.isNotEmpty) {
        newAssignments[newId] = sourceAssignments
            .map(
              (row) => _EditableAssignment(
                teacherProfileId: row.teacherProfileId,
                assignmentRole: row.assignmentRole,
              ),
            )
            .toList();
      }
    }

    if (newSessions.isEmpty) {
      _showMessage('적용할 빈 칸이 없습니다.');
      return;
    }

    _pushUndo();
    setState(() {
      _draftSessions = [..._draftSessions, ...newSessions];
      if (newAssignments.isNotEmpty) {
        _draftAssignments = {..._draftAssignments, ...newAssignments};
      }
      if (normalizedLocation != null && normalizedLocation.isNotEmpty) {
        _roomPalette = {..._roomPalette, normalizedLocation};
      }
      _setDirty(true);
    });
    _showMessage('${newSessions.length}개 칸에 적용했습니다. ($skipped개 건너뜀)');
  }

  /// Loads the source session's course + MAIN teacher + location into the
  /// composer state and assembles the draggable card, so the user can drop it
  /// wherever they like.
  void _replicateToComposer(String sessionId) {
    final source = _draftSessions
        .where((row) => row.id == sessionId)
        .firstOrNull;
    if (source == null) {
      return;
    }
    final mainTeacherId = (_draftAssignments[sessionId] ?? const [])
        .where((row) => row.assignmentRole == 'MAIN')
        .map((row) => row.teacherProfileId)
        .firstOrNull;
    final location = (source.location ?? '').trim();
    final normalizedLocation =
        location.isEmpty ? null : RoomNormalizer.normalize(location);

    setState(() {
      _composeCourseId = source.courseId;
      _composeTeacherId = mainTeacherId;
      _composeRoom = normalizedLocation;
      _composedCard = ComposedSessionPayload(
        courseId: source.courseId,
        teacherProfileId: mainTeacherId,
        location: normalizedLocation,
      );
    });
    _showMessage('수업 카드로 복제했습니다. 원하는 칸에 드래그하세요.');
  }

  // ---------------------------------------------------------------------------
  // Undo / redo (client-only)
  // ---------------------------------------------------------------------------

  _DraftSnapshot _captureSnapshot() {
    return _DraftSnapshot(
      sessions: List<_EditableSession>.from(_draftSessions),
      assignments: {
        for (final entry in _draftAssignments.entries)
          entry.key: List<_EditableAssignment>.from(entry.value),
      },
      roomPalette: Set<String>.from(_roomPalette),
      isDirty: _isDraftDirty,
    );
  }

  void _restoreSnapshot(_DraftSnapshot snapshot) {
    _draftSessions = List<_EditableSession>.from(snapshot.sessions);
    _draftAssignments = {
      for (final entry in snapshot.assignments.entries)
        entry.key: List<_EditableAssignment>.from(entry.value),
    };
    _roomPalette = Set<String>.from(snapshot.roomPalette);
    _setDirty(snapshot.isDirty);
  }

  /// Records the current draft state so it can be restored via [_undo].
  /// Invoked at the START of every draft-mutating action.
  void _pushUndo() {
    _undoStack.add(_captureSnapshot());
    if (_undoStack.length > _historyLimit) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _clearHistory() {
    _undoStack.clear();
    _redoStack.clear();
  }

  bool get _canUndo => _undoStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty;

  /// True when drags must be disabled (busy commit or read-only term lock:
  /// ARCHIVED hard-lock or past-term soft-lock).
  bool get _dragsLocked =>
      _isApplyingDraft || widget.controller.isSelectedTermReadOnly;

  void _beginDrag(_ActiveDrag drag) {
    setState(() {
      _activeDrag = drag;
    });
  }

  void _endDrag() {
    if (_activeDrag == null) {
      return;
    }
    setState(() {
      _activeDrag = null;
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) {
      return;
    }
    final snapshot = _undoStack.removeLast();
    _redoStack.add(_captureSnapshot());
    if (_redoStack.length > _historyLimit) {
      _redoStack.removeAt(0);
    }
    setState(() {
      _restoreSnapshot(snapshot);
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) {
      return;
    }
    final snapshot = _redoStack.removeLast();
    _undoStack.add(_captureSnapshot());
    if (_undoStack.length > _historyLimit) {
      _undoStack.removeAt(0);
    }
    setState(() {
      _restoreSnapshot(snapshot);
    });
  }

  // ---------------------------------------------------------------------------
  // Live drop-conflict evaluation (mirrors DB guards)
  // ---------------------------------------------------------------------------

  /// Evaluates the drop feedback state for [slotId] given the drag in progress.
  /// Mirrors the DB triggers so HARD states (occupied/teacherConflict) can be
  /// rejected before commit, while [warning] (unavailability) still allows drop.
  DropConflictState _evaluateDropConflict(
    String slotId, {
    required DragPayloadType kind,
    String? courseId,
    String? teacherProfileId,
    String? movingSessionId,
  }) {
    final controller = widget.controller;
    final slot = controller.findTimeSlot(slotId);
    if (slot == null) {
      return DropConflictState.none;
    }

    final isNewSession =
        kind == DragPayloadType.course || kind == DragPayloadType.child;
    final isComposed = courseId != null && kind == DragPayloadType.course;

    // Occupancy: a new session onto an already-occupied draft slot, or moving a
    // session onto a slot that holds a DIFFERENT draft session.
    if (kind == DragPayloadType.session) {
      final occupied = _draftSessions.any(
        (row) => row.timeSlotId == slotId && row.id != movingSessionId,
      );
      if (occupied) {
        return DropConflictState.occupied;
      }
    } else if (isNewSession) {
      final occupied = _draftSessions.any(
        (row) => row.timeSlotId == slotId && row.id != movingSessionId,
      );
      if (occupied) {
        return DropConflictState.occupied;
      }
    }

    // Teacher/room chips can only land on a cell that already holds a session.
    final targetSession = _draftSessionsForSlot(slotId).firstOrNull;
    if ((kind == DragPayloadType.teacher || kind == DragPayloadType.room) &&
        targetSession == null) {
      return DropConflictState.none;
    }

    // Teacher conflict / unavailability: only relevant when a teacher is part of
    // the drag (a teacher chip, or a composed card carrying a main teacher). The
    // course used for the conflict check is the composed/new course, or — for a
    // bare teacher chip — the course of the session already in the target cell,
    // so a legitimate combined-class assignment (same course) is NOT rejected.
    final draggedTeacherId = (teacherProfileId ?? '').trim();
    final hasTeacher =
        draggedTeacherId.isNotEmpty &&
        (kind == DragPayloadType.teacher || isComposed);
    if (hasTeacher) {
      final effectiveCourseId = courseId ?? targetSession?.courseId;
      if (_hasTeacherSlotConflict(
        teacherProfileId: draggedTeacherId,
        timeSlotId: slot.id,
        courseId: effectiveCourseId,
        excludeSessionId: movingSessionId ?? targetSession?.id,
      )) {
        return DropConflictState.teacherConflict;
      }
      if (_hasTeacherUnavailability(
        teacherProfileId: draggedTeacherId,
        slot: slot,
      )) {
        return DropConflictState.warning;
      }
    }

    return DropConflictState.valid;
  }

  /// HARD teacher conflict: another NON-canceled session anywhere in the term at
  /// the SAME time_slot_id assigned to [teacherProfileId] with a DIFFERENT
  /// course. Same course at same slot = combined class → allowed.
  bool _hasTeacherSlotConflict({
    required String teacherProfileId,
    required String timeSlotId,
    required String? courseId,
    String? excludeSessionId,
  }) {
    final controller = widget.controller;
    final normalizedCourse = (courseId ?? '').trim();

    // Cross-class sessions from the controller (other classes in the term).
    final draftClassId = controller.selectedClassGroupId;
    for (final session in controller.allTermSessions) {
      if (session.status == 'CANCELED') {
        continue;
      }
      if (session.timeSlotId != timeSlotId) {
        continue;
      }
      // Sessions belonging to the class currently being edited are represented
      // by the draft buffer instead, so skip them here to avoid double-count.
      if (draftClassId != null && session.classGroupId == draftClassId) {
        continue;
      }
      final assigned = controller.allTermSessionTeacherAssignments.any(
        (row) =>
            row.classSessionId == session.id &&
            row.teacherProfileId == teacherProfileId,
      );
      if (!assigned) {
        continue;
      }
      if (session.courseId.trim() != normalizedCourse) {
        return true;
      }
    }

    // Current draft (the class being edited).
    for (final draft in _draftSessions) {
      if (draft.id == excludeSessionId) {
        continue;
      }
      if (draft.timeSlotId != timeSlotId) {
        continue;
      }
      final assigned = (_draftAssignments[draft.id] ?? const [])
          .any((row) => row.teacherProfileId == teacherProfileId);
      if (!assigned) {
        continue;
      }
      if (draft.courseId.trim() != normalizedCourse) {
        return true;
      }
    }

    return false;
  }

  /// WARNING (not HARD): teacher has an unavailability block whose day matches
  /// the slot's day and whose [startTime,endTime) overlaps the slot range.
  bool _hasTeacherUnavailability({
    required String teacherProfileId,
    required TimeSlot slot,
  }) {
    for (final block in widget.controller.memberUnavailabilityBlocks) {
      if (block.ownerKind != 'TEACHER_PROFILE' ||
          block.ownerId != teacherProfileId) {
        continue;
      }
      if (block.dayOfWeek != slot.dayOfWeek) {
        continue;
      }
      // Overlap of half-open ranges [start, end): start < otherEnd && otherStart < end.
      if (slot.startTime.compareTo(block.endTime) < 0 &&
          block.startTime.compareTo(slot.endTime) < 0) {
        return true;
      }
    }
    return false;
  }

  List<_EditableSession> _draftSessionsForSlot(String slotId) {
    final rows =
        _draftSessions
            .where((row) => row.timeSlotId == slotId)
            .toList()
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

    return conflicts.toSet().toList();
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
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));

    final sessionIds = sessions.map((row) => row.id).toSet();
    final assignments =
        controller.sessionTeacherAssignments
            .where((row) => sessionIds.contains(row.classSessionId))
            .toList()
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
    final classroomSig = controller.classrooms.toList()
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
            .toList()
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
          .toList();
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
        .toList();
    _draftAssignments = assignments;
    _ensureRoomPaletteFromController(controller);
    _controllerSignature = _buildControllerSignature(controller, classId);
    _clearHistory();
    _setDirty(false);
  }

  void _ensureRoomPaletteFromController(NestController controller) {
    // Dedupe by RoomNormalizer.canonical so "A강의실" / "a강의실 " collapse to a
    // single palette entry while preserving the first display form seen.
    final byCanonical = <String, String>{};
    void addRoom(String? raw) {
      final display = RoomNormalizer.normalize(raw ?? '');
      if (display.isEmpty) {
        return;
      }
      byCanonical.putIfAbsent(RoomNormalizer.canonical(display), () => display);
    }

    for (final classroom in controller.classrooms) {
      addRoom(classroom.name);
    }
    for (final session in controller.allTermSessions) {
      addRoom(session.location);
    }
    for (final session in _draftSessions) {
      addRoom(session.location);
    }
    _roomPalette = byCanonical.values.toSet();
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
    required this.onComposedDrop,
    required this.onTapSession,
    required this.onDeleteSession,
    required this.onSessionMenu,
    required this.sessionMenuEnabled,
    required this.onSessionDragStarted,
    required this.onSessionDragEnded,
    required this.dragsLocked,
    required this.activeDrag,
    required this.conflictState,
    required this.forExport,
  });

  final TimeSlot slot;
  final List<_EditableSession> sessions;
  final Map<String, List<_EditableAssignment>> assignmentsBySessionId;
  final Map<String, String> teacherNameById;
  final List<String> Function(String sessionId) conflictMessagesForSession;
  final Future<void> Function(DragPayload payload) onDropPayload;
  final void Function(ComposedSessionPayload payload) onComposedDrop;
  final void Function(String sessionId) onTapSession;
  final void Function(String sessionId) onDeleteSession;
  final void Function(String sessionId, Offset globalPosition) onSessionMenu;
  final bool sessionMenuEnabled;
  final void Function(String sessionId) onSessionDragStarted;
  final VoidCallback onSessionDragEnded;
  final bool dragsLocked;
  final _ActiveDrag? activeDrag;
  final DropConflictState conflictState;
  final bool forExport;

  /// True when the current drag-time conflict state must block the drop.
  bool get _isHardReject =>
      conflictState == DropConflictState.occupied ||
      conflictState == DropConflictState.teacherConflict;

  @override
  Widget build(BuildContext context) {
    return DragTarget<Object>(
      onWillAcceptWithDetails: (details) {
        final data = details.data;
        if (data is! DragPayload && data is! ComposedSessionPayload) {
          return false;
        }
        // Reject HARD conflict states so the cell visibly refuses the drop.
        if (activeDrag != null && _isHardReject) {
          return false;
        }
        return true;
      },
      onAcceptWithDetails: (details) async {
        final data = details.data;
        if (data is ComposedSessionPayload) {
          onComposedDrop(data);
        } else if (data is DragPayload) {
          await onDropPayload(data);
        }
      },
      builder: (context, candidateData, rejectedData) {
        final hovering = candidateData.isNotEmpty;
        final showFeedback = !forExport && activeDrag != null;

        Color background = Colors.white;
        Color borderColor = NestColors.roseMist;
        double borderWidth = 1;
        double opacity = 1;
        List<BoxShadow>? shadow;

        if (showFeedback) {
          switch (conflictState) {
            case DropConflictState.valid:
              background = NestColors.roseMist.withValues(alpha: 0.45);
              borderColor = NestColors.dustyRose;
              borderWidth = 2;
              shadow = [
                BoxShadow(
                  color: NestColors.dustyRose.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ];
              break;
            case DropConflictState.occupied:
            case DropConflictState.teacherConflict:
              background = Colors.red.shade50;
              borderColor = Colors.red.shade400;
              borderWidth = 2;
              opacity = 0.5;
              break;
            case DropConflictState.warning:
              background = Colors.amber.shade50;
              borderColor = Colors.amber.shade600;
              borderWidth = 2;
              break;
            case DropConflictState.none:
              break;
          }
        } else if (hovering) {
          background = NestColors.roseMist.withValues(alpha: 0.58);
          borderColor = NestColors.clay;
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: background,
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: shadow,
          ),
          child: Opacity(
            opacity: opacity,
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
                        ? '수업'
                        : session.title;
                    final rows =
                        assignmentsBySessionId[session.id] ?? const [];
                    final teacherBadges = rows
                        .map(
                          (row) =>
                              '${row.assignmentRole == 'MAIN' ? '주' : '보조'} ${teacherNameById[row.teacherProfileId] ?? row.teacherProfileId}',
                        )
                        .toList();
                    final conflictRows =
                        conflictMessagesForSession(session.id);

                    final canMenu = !forExport && sessionMenuEnabled;
                    final tile = _GridSessionTile(
                      title: title,
                      subtitle: '',
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
                      canMenu: canMenu,
                      onMenu: canMenu
                          ? (position) => onSessionMenu(session.id, position)
                          : null,
                    );

                    final feedbackTile = _GridSessionTile(
                      title: title,
                      subtitle: '',
                      location: session.location,
                      teacherBadges: teacherBadges,
                      conflictMessages: conflictRows,
                      canDelete: false,
                      onDelete: null,
                      onTap: null,
                      canMenu: false,
                      onMenu: null,
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: forExport
                          ? tile
                          : Draggable<DragPayload>(
                              data: DragPayload(
                                type: DragPayloadType.session,
                                id: session.id,
                              ),
                              maxSimultaneousDrags: dragsLocked ? 0 : null,
                              onDragStarted: () =>
                                  onSessionDragStarted(session.id),
                              onDragEnd: (_) => onSessionDragEnded(),
                              onDraggableCanceled: (velocity, offset) =>
                                  onSessionDragEnded(),
                              feedback: Material(
                                color: Colors.transparent,
                                child: feedbackTile,
                              ),
                              childWhenDragging: Opacity(
                                opacity: 0.36,
                                child: feedbackTile,
                              ),
                              child: tile,
                            ),
                    );
                  }),
              ],
            ),
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
  });

  final double width;
  final String title;

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
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
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
    this.canMenu = false,
    this.onMenu,
  });

  final String title;
  final String subtitle;
  final String? location;
  final List<String> teacherBadges;
  final List<String> conflictMessages;
  final bool canDelete;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  /// When true, exposes the bulk-action menu (⋮ button + right-click).
  final bool canMenu;

  /// Opens the bulk-action context menu at the given global position.
  final void Function(Offset globalPosition)? onMenu;

  @override
  Widget build(BuildContext context) {
    final showMenuAffordance = canMenu && onMenu != null;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: showMenuAffordance
          ? (details) => onMenu!(details.globalPosition)
          : null,
      child: Material(
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
                    if (showMenuAffordance)
                      Builder(
                        builder: (buttonContext) => IconButton(
                          onPressed: () {
                            final box =
                                buttonContext.findRenderObject() as RenderBox?;
                            final position = box == null
                                ? Offset.zero
                                : box.localToGlobal(box.size.center(Offset.zero));
                            onMenu!(position);
                          },
                          icon: const Icon(Icons.more_vert, size: 16),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(4),
                          tooltip: '일괄 적용',
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
              if (subtitle.trim().isNotEmpty)
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
                      .toList(),
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
                      .toList(),
                ),
              ],
              ],
            ),
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

/// A draggable chip representing the assembled "수업 카드 조립" payload.
class _ComposedCardChip extends StatelessWidget {
  const _ComposedCardChip({
    required this.label,
    this.dragging = false,
  });

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.dustyRose),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.drag_indicator,
            size: 16,
            color: dragging ? Colors.white : NestColors.deepWood,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: dragging ? Colors.white : NestColors.deepWood,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
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

/// Live drop-target feedback state computed while a drag is in progress.
/// Mirrors the DB-level guards so the UI rejects invalid drops before commit.
enum DropConflictState { none, valid, occupied, teacherConflict, warning }

/// Bulk power-moves available from a session tile's context menu.
enum _BulkAction { fillDay, fillPeriod, fillWeek, duplicateToComposer }

/// Snapshot of the active drag, set on [Draggable.onDragStarted] and cleared
/// on drag end so each grid cell can evaluate its own drop feedback live.
class _ActiveDrag {
  const _ActiveDrag({
    required this.kind,
    this.courseId,
    this.teacherProfileId,
    this.sessionId,
  });

  final DragPayloadType kind;
  final String? courseId;
  final String? teacherProfileId;
  final String? sessionId;
}

/// Immutable copy of the draft buffer used for client-side undo/redo.
class _DraftSnapshot {
  const _DraftSnapshot({
    required this.sessions,
    required this.assignments,
    required this.roomPalette,
    required this.isDirty,
  });

  final List<_EditableSession> sessions;
  final Map<String, List<_EditableAssignment>> assignments;
  final Set<String> roomPalette;
  final bool isDirty;
}

String _dayLabel(int dayOfWeek) {
  const labels = <int, String>{
    0: '일',
    1: '월',
    2: '화',
    3: '수',
    4: '목',
    5: '금',
    6: '토',
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
