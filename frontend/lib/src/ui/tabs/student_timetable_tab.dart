import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/self_study_planner.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/nest_empty_state.dart';
import 'student_home_tab.dart' show StudentAbsenceBadge, StudentChangeBadge;

/// 학생 본인 계정의 시간표 탭.
///
/// ParentTimetableTab 의 주간 보드를 그대로 본떴고, 셀 상세 모달에서 본인
/// 결석 신고/철회를 할 수 있게 확장했다.
class StudentTimetableTab extends StatefulWidget {
  const StudentTimetableTab({
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
  State<StudentTimetableTab> createState() => _StudentTimetableTabState();
}

class _StudentTimetableTabState extends State<StudentTimetableTab> {
  // false = 수업 시간표, true = 자습 시간표.
  bool _showSelfStudy = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bundles = widget.childClassBundles;
    final childId = _resolveChildId(controller);

    if (childId == null) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          SizedBox(height: 24),
          NestEmptyState(
            icon: Icons.person_search_outlined,
            title: '아직 계정이 학생 정보와 연결되지 않았습니다.',
            subtitle: '관리 선생님께 문의해 주세요.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildModeToggle(context),
        const SizedBox(height: 12),
        if (_showSelfStudy)
          _buildSelfStudyView(context, controller, childId)
        else if (widget.isLoadingChildClasses && bundles.isEmpty) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ] else if (bundles.isEmpty)
          Card(
            color: NestColors.roseMist.withValues(alpha: 0.35),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: NestColors.clay),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '반 배정 대기 중',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '아직 반에 배정되지 않았어요. '
                          '관리 선생님이 반 배정을 마치면 시간표를 확인할 수 있습니다.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Builder(
            builder: (context) {
              try {
                return _buildWeeklyScheduleBoard(controller, bundles, childId);
              } catch (e, st) {
                debugPrint('[StudentTimetable] board error: $e\n$st');
                return Card(
                  color: NestColors.roseMist.withValues(alpha: 0.35),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('시간표 로딩 오류: $e',
                        style: const TextStyle(fontSize: 12)),
                  ),
                );
              }
            },
          ),
      ],
    );
  }

  // ── 데이터 해석 헬퍼 ──

  String? _resolveChildId(NestController controller) {
    final selected = widget.selectedChildId;
    if (selected != null && selected.isNotEmpty) {
      return selected;
    }
    final active = controller.activeStudentChildId;
    if (active != null && active.isNotEmpty) {
      return active;
    }
    return controller.currentUserChildProfiles.firstOrNull?.id;
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 이 수업에 걸린 변경 중 아직 끝나지 않은 것들(시작일 순).
  List<ClassSessionChange> _liveChanges(
    NestController controller,
    String sessionId,
  ) {
    final today = _today();
    return controller
        .changesForSession(sessionId)
        .where((change) {
          final to = change.effectiveTo;
          if (to == null) return true;
          return !DateTime(to.year, to.month, to.day).isBefore(today);
        })
        .toList(growable: false);
  }

  /// 이 수업에 걸린, 아직 남아 있는 본인 결석 신고.
  List<AbsenceReport> _liveAbsences(
    NestController controller,
    String sessionId,
    String childId,
  ) {
    final today = _today();
    return controller
        .absencesForSession(sessionId)
        .where((report) {
          if (report.childId != childId || report.isCanceled) return false;
          final date = report.occurrenceDate;
          return !DateTime(date.year, date.month, date.day).isBefore(today);
        })
        .toList(growable: false);
  }

  // ── 모드 토글 / 자습 ──

  Widget _buildModeToggle(BuildContext context) {
    return SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          label: Text('수업'),
          icon: Icon(Icons.school_outlined, size: 16),
        ),
        ButtonSegment(
          value: true,
          label: Text('자습'),
          icon: Icon(Icons.edit_note_outlined, size: 16),
        ),
      ],
      selected: {_showSelfStudy},
      showSelectedIcon: false,
      onSelectionChanged: (selection) =>
          setState(() => _showSelfStudy = selection.first),
    );
  }

  Widget _buildSelfStudyView(
    BuildContext context,
    NestController controller,
    String childId,
  ) {
    if (controller.selfStudyPlans.isEmpty) {
      return const NestEmptyState(
        icon: Icons.menu_book_outlined,
        title: '자습 시간표가 아직 없습니다',
        subtitle: '관리 선생님이 자습 시간표를 만들면 여기에 표시됩니다.',
      );
    }
    final slots = controller.selfStudySlotsForChild(childId);
    if (slots.isEmpty) {
      return const NestEmptyState(
        icon: Icons.event_available_outlined,
        title: '배정된 자습이 없습니다',
        subtitle: '지금은 자습 배정이 없어요.',
      );
    }

    final byDay = <int, List<SelfStudySlot>>{};
    for (final s in slots) {
      byDay.putIfAbsent(s.dayOfWeek, () => []).add(s);
    }
    const order = [1, 2, 3, 4, 5, 6, 0];
    final planName = controller.selectedSelfStudyPlan?.name ?? '자습';

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(
          planName,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    ];
    for (final day in order) {
      final ds = byDay[day];
      if (ds == null || ds.isEmpty) continue;
      ds.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      children.add(Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6, left: 2),
        child: Text(
          '${weekdayLabel(day)}요일',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ));
      for (final slot in ds) {
        children.add(_selfStudyCard(context, controller, slot));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _selfStudyCard(
    BuildContext context,
    NestController controller,
    SelfStudySlot slot,
  ) {
    final time = rangeLabel(
      minutesFromTime(slot.startTime),
      minutesFromTime(slot.endTime),
    );
    final room = slot.room.trim().isEmpty ? '장소 미정' : slot.room.trim();
    final supervisorId = slot.supervisorTeacherId;
    final supervisor = (supervisorId == null || supervisorId.isEmpty)
        ? null
        : controller.findTeacherName(supervisorId);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: NestColors.mutedSage.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              time,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: NestColors.deepWood,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.meeting_room_outlined,
                        size: 16, color: NestColors.clay),
                    const SizedBox(width: 4),
                    Text(
                      room,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                if (supervisor != null && supervisor.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '감독 · $supervisor',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 주간 시간표 보드 ──

  Widget _buildWeeklyScheduleBoard(
    NestController controller,
    Map<String, ChildClassBundle> bundles,
    String childId,
  ) {
    final entries = _collectScheduleEntries(controller, bundles);
    if (entries.isEmpty) {
      return const NestEmptyState(
        icon: Icons.calendar_today,
        title: '시간표 데이터가 없습니다',
      );
    }

    final slotById = {for (final slot in controller.timeSlots) slot.id: slot};
    final days = <int>{};
    final periodKeys = <String>{};
    final byPeriodDay = <String, Map<int, List<_StudentScheduleEntry>>>{};

    // 그리드 축은 학기 전체 슬롯 집합으로 만든다(부모 탭과 동일한 이유:
    // 오전 수업이 없어도 오전 행이 사라지지 않게).
    for (final slot in controller.timeSlots) {
      days.add(slot.dayOfWeek);
      periodKeys.add('${slot.startTime}-${slot.endTime}');
    }

    for (final entry in entries) {
      final slot = slotById[entry.session.timeSlotId];
      if (slot == null) continue;

      final periodKey = '${slot.startTime}-${slot.endTime}';
      days.add(slot.dayOfWeek);
      periodKeys.add(periodKey);

      byPeriodDay
          .putIfAbsent(periodKey, () => <int, List<_StudentScheduleEntry>>{})
          .putIfAbsent(slot.dayOfWeek, () => <_StudentScheduleEntry>[])
          .add(entry);
    }

    if (days.isEmpty || periodKeys.isEmpty) {
      return const NestEmptyState(
        icon: Icons.calendar_today,
        title: '시간표 슬롯 정보를 찾을 수 없습니다',
      );
    }

    final sortedDays = days.toList()..sort();
    final sortedPeriods = periodKeys.toList()
      ..sort((a, b) => _comparePeriodKey(a, b));

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        const naturalTimeCol = 50.0;
        const naturalDayCol = 110.0;
        const borderWidth = 1.0;
        final contentWidth = availableWidth - borderWidth * 2;
        final naturalWidth = naturalTimeCol + naturalDayCol * sortedDays.length;
        final scale =
            naturalWidth > contentWidth ? contentWidth / naturalWidth : 1.0;
        final timeColWidth = naturalTimeCol * scale;
        final dayColWidth = naturalDayCol * scale;
        final columnsWidth = timeColWidth + dayColWidth * sortedDays.length;
        final boardWidth = columnsWidth + borderWidth * 2;

        final board = Container(
          width: boardWidth,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NestColors.roseMist),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: timeColWidth,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: NestColors.creamyWhite,
                      border: Border(
                        left: BorderSide(
                          color: NestColors.roseMist.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                  ...sortedDays.map(
                    (day) => _ScheduleHeaderCell(
                      width: dayColWidth,
                      label: _dayLabel(day),
                    ),
                  ),
                ],
              ),
              const Divider(height: 1, thickness: 1),
              ...sortedPeriods.map((periodKey) {
                final segments = periodKey.split('-');
                final startTimeLabel =
                    segments.isNotEmpty ? _koreanTime(segments[0]) : periodKey;
                final compactFont = scale < 0.85;

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: NestColors.roseMist.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: timeColWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 10,
                          ),
                          child: Text(
                            startTimeLabel,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: compactFont ? 10 : 12,
                                ),
                          ),
                        ),
                      ),
                      ...sortedDays.map((day) {
                        final cells = byPeriodDay[periodKey]?[day] ??
                            const <_StudentScheduleEntry>[];
                        return Container(
                          width: dayColWidth,
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(
                                color: NestColors.roseMist
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: cells.isEmpty
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: cells.map((cell) {
                                    final changes = _liveChanges(
                                      controller,
                                      cell.session.id,
                                    );
                                    final absences = _liveAbsences(
                                      controller,
                                      cell.session.id,
                                      childId,
                                    );
                                    return Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4),
                                      child: _SubjectNameCell(
                                        courseName: controller.findCourseName(
                                          cell.session.courseId,
                                        ),
                                        compact: compactFont,
                                        changeLabel: changes.isEmpty
                                            ? null
                                            : changes.first.changeTypeLabel,
                                        canceled: changes.any(
                                          (c) => c.changeType == 'CANCELED',
                                        ),
                                        hasAbsence: absences.isNotEmpty,
                                        onTap: () => _showCellDetailModal(
                                          context,
                                          controller: controller,
                                          entry: cell,
                                          childId: childId,
                                        ),
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
            ],
          ),
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: board,
        );
      },
    );
  }

  // ── 셀 상세 모달 (+ 결석 신고) ──

  void _showCellDetailModal(
    BuildContext context, {
    required NestController controller,
    required _StudentScheduleEntry entry,
    required String childId,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: _buildDetailBody(
                    ctx,
                    controller: controller,
                    entry: entry,
                    childId: childId,
                    refresh: () {
                      setSheetState(() {});
                      if (mounted) setState(() {});
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailBody(
    BuildContext ctx, {
    required NestController controller,
    required _StudentScheduleEntry entry,
    required String childId,
    required VoidCallback refresh,
  }) {
    final courseName = controller.findCourseName(entry.session.courseId);
    final slot = controller.findTimeSlot(entry.session.timeSlotId);
    final timeLabel = slot == null
        ? '-'
        : '${_dayLabel(slot.dayOfWeek)} ${_shortTime(slot.startTime)} - '
            '${_shortTime(slot.endTime)}';
    final teacherLabel = _teacherLabelForSession(
      controller: controller,
      sessionId: entry.session.id,
      assignments: entry.assignments,
    );
    final location = (entry.session.location ?? '').trim();
    final locationLabel = location.isEmpty ? '장소 미지정' : location;
    final changes = _liveChanges(controller, entry.session.id);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_rounded, color: NestColors.clay),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                courseName,
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(ctx),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          entry.className,
          style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 16),
        _DetailRow(
          icon: Icons.schedule_outlined,
          label: '시간',
          value: timeLabel,
        ),
        const Divider(height: 24),
        _DetailRow(
          icon: Icons.school_outlined,
          label: '담당 교사',
          value: teacherLabel,
        ),
        const Divider(height: 24),
        _DetailRow(
          icon: Icons.meeting_room_outlined,
          label: '장소',
          value: locationLabel,
        ),
        if (changes.isNotEmpty) ...[
          const Divider(height: 24),
          Text(
            '변경 안내',
            style: Theme.of(ctx)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...changes.map(
            (change) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StudentChangeBadge(label: change.changeTypeLabel),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _changePeriodLabel(change),
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (change.reason.trim().isNotEmpty)
                          Text(
                            change.reason.trim(),
                            style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                  color: NestColors.deepWood
                                      .withValues(alpha: 0.7),
                                ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        if (controller.canReportAbsence && slot != null) ...[
          const Divider(height: 24),
          _buildAbsenceSection(
            ctx,
            controller: controller,
            entry: entry,
            slot: slot,
            childId: childId,
            refresh: refresh,
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAbsenceSection(
    BuildContext ctx, {
    required NestController controller,
    required _StudentScheduleEntry entry,
    required TimeSlot slot,
    required String childId,
    required VoidCallback refresh,
  }) {
    final dates = _upcomingDates(controller, slot.dayOfWeek);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_busy_outlined, size: 20, color: NestColors.clay),
            const SizedBox(width: 8),
            Text(
              '결석 신고',
              style: Theme.of(ctx)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '앞으로 있을 수업 중 못 오는 날을 미리 알려 주세요. 담당 선생님께 문자로 전달됩니다.',
          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.65),
              ),
        ),
        const SizedBox(height: 10),
        if (dates.isEmpty)
          Text(
            '남은 수업 회차가 없습니다.',
            style: Theme.of(ctx).textTheme.bodySmall,
          )
        else
          ...dates.map((date) {
            // childId 로 좁혀서 조회한다. 좁히지 않으면 같은 반 형제의 신고가
            // 먼저 매칭되어 본인 신고가 없는 것처럼 보이고 중복 신고로 이어진다.
            final report = controller.absenceFor(
              sessionId: entry.session.id,
              date: date,
              childId: childId,
            );
            final mine = report != null;
            final change = controller.effectiveChangeFor(
              sessionId: entry.session.id,
              date: date,
            );
            final canceledClass = change?.changeType == 'CANCELED';

            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            DateFormat('M월 d일 (E)', 'ko').format(date),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(ctx).textTheme.bodyMedium,
                          ),
                        ),
                        if (change != null) ...[
                          const SizedBox(width: 6),
                          StudentChangeBadge(label: change.changeTypeLabel),
                        ],
                        if (mine) ...[
                          const SizedBox(width: 6),
                          const StudentAbsenceBadge(),
                        ],
                      ],
                    ),
                  ),
                  if (mine)
                    TextButton(
                      onPressed: () => _cancelAbsence(report, refresh),
                      child: const Text('취소'),
                    )
                  else if (canceledClass)
                    Text(
                      '휴강',
                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                            color: NestColors.deepWood.withValues(alpha: 0.5),
                          ),
                    )
                  else
                    TextButton(
                      onPressed: () => _reportAbsence(
                        sessionId: entry.session.id,
                        childId: childId,
                        date: date,
                        refresh: refresh,
                      ),
                      child: const Text('결석 신고'),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  /// 이 요일의 학기 내 남은 회차(오늘 이후)를 최대 8개까지.
  List<DateTime> _upcomingDates(NestController controller, int dayOfWeek) {
    final term = controller.selectedTerm;
    final today = _today();
    final start = term?.startDate ?? today;
    final end = term?.endDate ?? today.add(const Duration(days: 90));
    final from = start.isBefore(today) ? today : start;
    if (end.isBefore(from)) return const [];

    return datesForWeekday(from, end, dayOfWeek)
        .where((date) => date.isAfter(today))
        .take(8)
        .toList(growable: false);
  }

  Future<void> _reportAbsence({
    required String sessionId,
    required String childId,
    required DateTime date,
    required VoidCallback refresh,
  }) async {
    final reason = await _askReason(date);
    if (reason == null) return;

    final controller = widget.controller;
    AbsenceReport created;
    try {
      created = await controller.reportAbsence(
        classSessionId: sessionId,
        childId: childId,
        occurrenceDate: date,
        reason: reason,
      );
    } catch (e) {
      _showMessage(e is StateError ? e.message : controller.statusMessage);
      refresh();
      return;
    }

    // 신고는 이미 저장됐다. 알림 발송 실패가 신고 실패처럼 보이면 안 되므로
    // 메시지를 분리해서 보여준다.
    try {
      final result = await controller.notifyAbsence(reportId: created.id);
      if (result.sent > 0) {
        _showMessage('결석을 신고했습니다. 담당 선생님께 문자로 알렸습니다.');
      } else if (result.alreadyNotified) {
        _showMessage('결석을 신고했습니다. 이미 알림을 보낸 신고입니다.');
      } else {
        _showMessage('결석을 신고했습니다. 선생님 연락처가 등록되어 있지 않아 문자는 보내지 못했습니다.');
      }
    } catch (e) {
      _showMessage(
        e is StateError
            ? '결석을 신고했습니다. ${e.message}'
            : '결석을 신고했습니다. 다만 알림 문자는 보내지 못했습니다.',
      );
    }
    refresh();
  }

  /// 사유 입력(선택). 취소하면 null.
  Future<String?> _askReason(DateTime date) async {
    final textController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('결석 신고'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${DateFormat('M월 d일 (E)', 'ko').format(date)} 수업을 결석한다고 알릴까요?',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '사유 (선택)',
                hintText: '예: 병원 진료',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, textController.text.trim()),
            child: const Text('신고하기'),
          ),
        ],
      ),
    );
    textController.dispose();
    return result;
  }

  Future<void> _cancelAbsence(AbsenceReport report, VoidCallback refresh) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('결석 신고 취소'),
        content: Text(
          '${DateFormat('M월 d일 (E)', 'ko').format(report.occurrenceDate)} '
          '결석 신고를 취소할까요?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('취소하기'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.controller.cancelAbsenceReport(id: report.id);
      _showMessage('결석 신고를 취소했습니다.');
    } catch (e) {
      _showMessage(
        e is StateError ? e.message : widget.controller.statusMessage,
      );
    }
    refresh();
  }

  // ── 보드 데이터 준비 ──

  List<_StudentScheduleEntry> _collectScheduleEntries(
    NestController controller,
    Map<String, ChildClassBundle> bundles,
  ) {
    final rows = <_StudentScheduleEntry>[];
    final sorted = bundles.values.toList()
      ..sort((a, b) => a.classGroup.name.compareTo(b.classGroup.name));

    for (final bundle in sorted) {
      for (final session in bundle.sessions) {
        if (controller.findTimeSlot(session.timeSlotId) == null) continue;
        rows.add(
          _StudentScheduleEntry(
            className: bundle.classGroup.name,
            session: session,
            assignments: bundle.assignments,
          ),
        );
      }
    }

    rows.sort((a, b) {
      final leftSlot = controller.findTimeSlot(a.session.timeSlotId);
      final rightSlot = controller.findTimeSlot(b.session.timeSlotId);
      if (leftSlot == null || rightSlot == null) {
        return a.className.compareTo(b.className);
      }
      final dayCompare = leftSlot.dayOfWeek.compareTo(rightSlot.dayOfWeek);
      if (dayCompare != 0) return dayCompare;
      final startCompare = leftSlot.startTime.compareTo(rightSlot.startTime);
      if (startCompare != 0) return startCompare;
      return a.className.compareTo(b.className);
    });
    return rows;
  }

  int _comparePeriodKey(String left, String right) {
    final leftParts = left.split('-');
    final rightParts = right.split('-');
    final leftStart = leftParts.firstOrNull ?? left;
    final rightStart = rightParts.firstOrNull ?? right;

    final startCompare =
        _clockToMinute(leftStart).compareTo(_clockToMinute(rightStart));
    if (startCompare != 0) return startCompare;

    final leftEnd = leftParts.length > 1 ? leftParts[1] : left;
    final rightEnd = rightParts.length > 1 ? rightParts[1] : right;
    return _clockToMinute(leftEnd).compareTo(_clockToMinute(rightEnd));
  }

  int _clockToMinute(String value) {
    final parts = value.trim().split(':');
    if (parts.length < 2) return 0;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  String _teacherLabelForSession({
    required NestController controller,
    required String sessionId,
    required List<SessionTeacherAssignment> assignments,
  }) {
    final rows = assignments
        .where((row) => row.classSessionId == sessionId)
        .toList()
      ..sort((a, b) {
        final left = a.assignmentRole == 'MAIN' ? 0 : 1;
        final right = b.assignmentRole == 'MAIN' ? 0 : 1;
        if (left != right) return left.compareTo(right);
        return controller
            .findTeacherName(a.teacherProfileId)
            .compareTo(controller.findTeacherName(b.teacherProfileId));
      });

    if (rows.isEmpty) return '담당교사 미지정';

    return rows.map((row) {
      final name = controller.findTeacherName(row.teacherProfileId);
      return row.assignmentRole == 'MAIN' ? '주강사 $name' : '보조 $name';
    }).join(', ');
  }

  String _changePeriodLabel(ClassSessionChange change) {
    final from = DateFormat('M월 d일').format(change.effectiveFrom);
    final to = change.effectiveTo;
    if (to == null) {
      return '$from부터 학기 끝까지';
    }
    if (to.year == change.effectiveFrom.year &&
        to.month == change.effectiveFrom.month &&
        to.day == change.effectiveFrom.day) {
      return '$from 하루';
    }
    return '$from ~ ${DateFormat('M월 d일').format(to)}';
  }

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _dayLabel(int dayOfWeek) {
    const labels = <int, String>{
      0: '일', 1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토',
    };
    return labels[dayOfWeek] ?? '$dayOfWeek';
  }

  String _shortTime(String value) {
    final parts = value.trim().split(':');
    if (parts.length < 2) return value.trim();
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  /// "HH:mm[:ss]" → '9시', '9시반', '10:20'.
  String _koreanTime(String value) {
    final minutes = _clockToMinute(value);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h시';
    if (m == 30) return '$h시반';
    return '$h:${m.toString().padLeft(2, '0')}';
  }
}

// ── Private helper widgets ──

class _StudentScheduleEntry {
  const _StudentScheduleEntry({
    required this.className,
    required this.session,
    required this.assignments,
  });

  final String className;
  final ClassSession session;
  final List<SessionTeacherAssignment> assignments;
}

class _ScheduleHeaderCell extends StatelessWidget {
  const _ScheduleHeaderCell({required this.width, required this.label});

  final double width;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: NestColors.creamyWhite,
        border: Border(
          left: BorderSide(color: NestColors.roseMist.withValues(alpha: 0.5)),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// 과목명 셀. 변경/결석 상태를 배지로 함께 보여준다.
class _SubjectNameCell extends StatelessWidget {
  const _SubjectNameCell({
    required this.courseName,
    required this.onTap,
    this.compact = false,
    this.changeLabel,
    this.canceled = false,
    this.hasAbsence = false,
  });

  final String courseName;
  final VoidCallback onTap;
  final bool compact;
  final String? changeLabel;
  final bool canceled;
  final bool hasAbsence;

  @override
  Widget build(BuildContext context) {
    final label = changeLabel;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 4 : 8,
          vertical: compact ? 6 : 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: hasAbsence
              ? NestColors.mutedSage.withValues(alpha: 0.18)
              : NestColors.roseMist.withValues(alpha: 0.26),
          border: Border.all(
            color: label == null ? NestColors.roseMist : NestColors.clay,
            width: label == null ? 1 : 1.4,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              courseName,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 11 : null,
                    decoration:
                        canceled ? TextDecoration.lineThrough : null,
                  ),
            ),
            if (label != null || hasAbsence) ...[
              const SizedBox(height: 3),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 3,
                runSpacing: 2,
                children: [
                  if (label != null)
                    StudentChangeBadge(label: label, compact: true),
                  if (hasAbsence) const StudentAbsenceBadge(compact: true),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: NestColors.clay),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
