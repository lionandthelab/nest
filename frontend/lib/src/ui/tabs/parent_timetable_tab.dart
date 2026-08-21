import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/nest_repository.dart';
import '../../services/self_study_planner.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/nest_empty_state.dart';

class ParentTimetableTab extends StatefulWidget {
  const ParentTimetableTab({
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
  State<ParentTimetableTab> createState() => _ParentTimetableTabState();
}

class _ParentTimetableTabState extends State<ParentTimetableTab> {
  // false = 수업 시간표, true = 자습 시간표.
  bool _showSelfStudy = false;

  /// 요일별 "다음 회차 날짜" 캐시. 한 번의 빌드 안에서 셀마다 학기 전체를
  /// 다시 훑지 않도록 [_buildWeeklyScheduleBoard] 진입 시 비운다.
  final Map<int, DateTime> _referenceDateCache = <int, DateTime>{};

  /// 결석 신고 시트에 한 번에 보여줄 최대 회차 수(학기 전체는 너무 길다).
  static const int _absenceDateLimit = 12;

  @override
  Widget build(BuildContext context) {
    // 수업 변경·결석 신고는 컨트롤러 상태라, 신고/철회 직후 보드와 모달이 함께
    // 다시 그려지도록 컨트롤러에 바인딩한다.
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final controller = widget.controller;
    final bundles = widget.childClassBundles;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (widget.selectedChildId != null) ...[
          _buildModeToggle(context),
          const SizedBox(height: 12),
        ],
        if (widget.selectedChildId != null && _showSelfStudy)
          _buildSelfStudyView(context, controller)
        else if (widget.isLoadingChildClasses && bundles.isEmpty) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator()),
        ] else if (widget.selectedChildId == null)
          const NestEmptyState(
            icon: Icons.calendar_today,
            title: '아이를 먼저 선택하세요',
            subtitle: '상단에서 아이를 선택하면 시간표를 확인할 수 있습니다.',
          )
        else if (bundles.isEmpty)
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
                          '아이가 아직 반에 배정되지 않았습니다. '
                          '관리자가 반 배정을 완료하면 시간표를 확인할 수 있습니다.',
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
                return _buildWeeklyScheduleBoard(controller, bundles);
              } catch (e, st) {
                debugPrint('[ParentTimetable] board error: $e\n$st');
                return Card(
                  color: Colors.red.shade50,
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
  ) {
    final childId = widget.selectedChildId;
    if (childId == null) {
      return const NestEmptyState(
        icon: Icons.self_improvement,
        title: '아이를 먼저 선택하세요',
      );
    }
    if (controller.selfStudyPlans.isEmpty) {
      return const NestEmptyState(
        icon: Icons.menu_book_outlined,
        title: '자습 시간표가 아직 없습니다',
        subtitle: '관리자가 자습 시간표를 만들면 여기에 표시됩니다.',
      );
    }
    final slots = controller.selfStudySlotsForChild(childId);
    if (slots.isEmpty) {
      return const NestEmptyState(
        icon: Icons.event_available_outlined,
        title: '배정된 자습이 없습니다',
        subtitle: '이 아이는 현재 자습 배정이 없어요.',
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

  Widget _buildWeeklyScheduleBoard(
    NestController controller,
    Map<String, ChildClassBundle> bundles,
  ) {
    _referenceDateCache.clear();
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
    final byPeriodDay = <String, Map<int, List<_ParentScheduleEntry>>>{};

    // Build the grid axes from the FULL term slot set, not just this child's
    // sessions. That way every child shares an identical day/period layout —
    // a child with no morning class still shows the (empty) morning rows
    // instead of starting the table partway down.
    for (final slot in controller.timeSlots) {
      days.add(slot.dayOfWeek);
      periodKeys.add('${slot.startTime}-${slot.endTime}');
    }

    for (final entry in entries) {
      final slot = slotById[entry.session.timeSlotId];
      if (slot == null) continue;

      final periodKey = '${slot.startTime}-${slot.endTime}';
      // Defensive: keep the cell visible even if the slot somehow isn't in the
      // term list (e.g. stale data).
      days.add(slot.dayOfWeek);
      periodKeys.add(periodKey);

      final perDay = byPeriodDay.putIfAbsent(
        periodKey,
        () => <int, List<_ParentScheduleEntry>>{},
      );
      final rows = perDay.putIfAbsent(
        slot.dayOfWeek,
        () => <_ParentScheduleEntry>[],
      );
      rows.add(entry);
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
        // 보드 Container의 Border.all(1px)이 자식을 좌우 1px씩 인셋하므로,
        // 테두리 두께를 뺀 내부 폭에 맞춰 컬럼을 스케일한다. 그렇지 않으면
        // 컬럼 폭 합이 내부 폭을 2px 넘겨 RenderFlex 오버플로가 난다.
        const borderWidth = 1.0;
        final contentWidth = availableWidth - borderWidth * 2;
        final naturalWidth =
            naturalTimeCol + naturalDayCol * sortedDays.length;
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
              // Header row: empty first cell + day labels
              Row(
                children: [
                  // Empty top-left cell (no "시간" label)
                  Container(
                    width: timeColWidth,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                    decoration: BoxDecoration(
                      color: NestColors.creamyWhite,
                      border: Border(
                        left: BorderSide(
                            color:
                                NestColors.roseMist.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                  ...sortedDays.map(
                    (day) => _ScheduleHeaderCell(
                      width: dayColWidth,
                      label: _dayLabel(day),
                      align: Alignment.center,
                    ),
                  ),
                ],
              ),
              const Divider(height: 1, thickness: 1),
              ...sortedPeriods.asMap().entries.map((rowEntry) {
                final periodKey = rowEntry.value;
                final segments = periodKey.split('-');
                final startTimeLabel = segments.isNotEmpty
                    ? _koreanTime(segments[0])
                    : periodKey;
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
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    fontSize: compactFont ? 10 : 12,
                                  ),
                            ),
                          ),
                        ),
                        ...sortedDays.map((day) {
                          final cells =
                              byPeriodDay[periodKey]?[day] ??
                              const <_ParentScheduleEntry>[];
                          // 주간 반복 템플릿이라 셀 자체에는 날짜가 없다.
                          // "다음 회차" 날짜를 기준으로 변경/결석을 표시한다.
                          final refDate = _referenceDateFor(controller, day);
                          return Container(
                            width: dayColWidth,
                            decoration: BoxDecoration(
                              border: Border(
                                left: BorderSide(
                                  color: NestColors.roseMist.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: cells.isEmpty
                                ? const SizedBox.shrink()
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: cells
                                        .map(
                                          (cell) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            child: _SubjectNameCell(
                                              courseName: controller
                                                  .findCourseName(
                                                    cell.session.courseId,
                                                  ),
                                              compact: compactFont,
                                              change: controller
                                                  .effectiveChangeFor(
                                                sessionId: cell.session.id,
                                                date: refDate,
                                              ),
                                              hasAbsence: _absenceForChild(
                                                    controller,
                                                    sessionId: cell.session.id,
                                                    childId:
                                                        widget.selectedChildId,
                                                    date: refDate,
                                                  ) !=
                                                  null,
                                              onTap: () =>
                                                  _showCellDetailModal(
                                                context,
                                                controller: controller,
                                                entry: cell,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
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

  /// Show detail modal when tapping a cell
  void _showCellDetailModal(
    BuildContext context, {
    required NestController controller,
    required _ParentScheduleEntry entry,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        // 결석 신고/철회 후 시트가 즉시 갱신되도록 컨트롤러에 바인딩한다.
        return AnimatedBuilder(
          animation: controller,
          builder: (innerContext, _) => _buildCellDetailSheet(
            innerContext,
            sheetContext: ctx,
            controller: controller,
            entry: entry,
          ),
        );
      },
    );
  }

  Widget _buildCellDetailSheet(
    BuildContext context, {
    required BuildContext sheetContext,
    required NestController controller,
    required _ParentScheduleEntry entry,
  }) {
    final courseName = controller.findCourseName(entry.session.courseId);
    final slot = controller.findTimeSlot(entry.session.timeSlotId);
    final timeLabel = slot == null
        ? '-'
        : '${_dayLabel(slot.dayOfWeek)} ${_shortTime(slot.startTime)} - ${_shortTime(slot.endTime)}';
    final teacherLabel = _teacherLabelForSession(
      controller: controller,
      sessionId: entry.session.id,
      assignments: entry.assignments,
    );
    final location = (entry.session.location ?? '').trim();
    final locationLabel = location.isEmpty ? '장소 미지정' : location;

    final refDate = slot == null
        ? null
        : _referenceDateFor(controller, slot.dayOfWeek);
    final effectiveChange = refDate == null
        ? null
        : controller.effectiveChangeFor(
            sessionId: entry.session.id,
            date: refDate,
          );
    final upcomingChanges = _upcomingChanges(controller, entry.session.id);
    final myAbsences = _upcomingAbsencesForSession(controller, entry.session.id);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
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
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                entry.className,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
              if (upcomingChanges.isNotEmpty) ...[
                const Divider(height: 24),
                _buildChangeSection(
                  context,
                  controller: controller,
                  changes: upcomingChanges,
                  effective: effectiveChange,
                  effectiveDate: refDate,
                ),
              ],
              if (controller.canReportAbsence) ...[
                const Divider(height: 24),
                _buildAbsenceSection(
                  context,
                  controller: controller,
                  entry: entry,
                  slot: slot,
                  reports: myAbsences,
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── 수업 변경 ──

  /// 오늘 이후까지 유효한 변경 공지만(이미 끝난 변경은 감춘다).
  List<ClassSessionChange> _upcomingChanges(
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
        .toList();
  }

  Widget _buildChangeSection(
    BuildContext context, {
    required NestController controller,
    required List<ClassSessionChange> changes,
    required ClassSessionChange? effective,
    required DateTime? effectiveDate,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.campaign_outlined, size: 20, color: NestColors.clay),
            const SizedBox(width: 10),
            Text(
              '수업 변경',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...changes.map(
          (change) => _buildChangeCard(
            context,
            controller: controller,
            change: change,
            isEffective: effective != null && effective.id == change.id,
            effectiveDate: effectiveDate,
          ),
        ),
      ],
    );
  }

  Widget _buildChangeCard(
    BuildContext context, {
    required NestController controller,
    required ClassSessionChange change,
    required bool isEffective,
    required DateTime? effectiveDate,
  }) {
    final isCanceled = change.changeType == 'CANCELED';
    final accent = isCanceled
        ? Theme.of(context).colorScheme.error
        : NestColors.clay;

    final details = <String>[];
    final newSlot = change.newTimeSlotId == null
        ? null
        : controller.findTimeSlot(change.newTimeSlotId!);
    if (newSlot != null) {
      details.add(
        '변경 시간 · ${_dayLabel(newSlot.dayOfWeek)} '
        '${_shortTime(newSlot.startTime)} - ${_shortTime(newSlot.endTime)}',
      );
    }
    if (change.newLocation.trim().isNotEmpty) {
      details.add('변경 장소 · ${change.newLocation.trim()}');
    }
    final substituteId = change.substituteTeacherId;
    if (substituteId != null && substituteId.isNotEmpty) {
      details.add('보강 교사 · ${controller.findTeacherName(substituteId)}');
    }
    if (change.reason.trim().isNotEmpty) {
      details.add('사유 · ${change.reason.trim()}');
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                change.changeTypeLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
              if (isEffective && effectiveDate != null)
                _MiniChip(
                  label: '${_dateLabel(effectiveDate)} 적용',
                  color: accent,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _changePeriodLabel(change),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.75),
            ),
          ),
          for (final line in details) ...[
            const SizedBox(height: 2),
            Text(line, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }

  String _changePeriodLabel(ClassSessionChange change) {
    final from = change.effectiveFrom;
    final to = change.effectiveTo;
    if (to == null) {
      return '${_dateLabel(from)}부터 학기 끝까지';
    }
    if (to.year == from.year && to.month == from.month && to.day == from.day) {
      return '${_dateLabel(from)} 하루';
    }
    return '${_dateLabel(from)} ~ ${_dateLabel(to)}';
  }

  // ── 결석 신고 ──

  Widget _buildAbsenceSection(
    BuildContext context, {
    required NestController controller,
    required _ParentScheduleEntry entry,
    required TimeSlot? slot,
    required List<AbsenceReport> reports,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_busy_outlined, size: 20, color: NestColors.clay),
            const SizedBox(width: 10),
            Text(
              '결석 신고',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          Text(
            '아직 신고한 결석이 없습니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.6),
            ),
          )
        else
          ...reports.map(
            (report) => _buildAbsenceRow(
              context,
              controller: controller,
              report: report,
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: slot == null
                ? null
                : () => _showAbsenceReportSheet(
                      context,
                      controller: controller,
                      entry: entry,
                      slot: slot,
                    ),
            icon: const Icon(Icons.event_busy_outlined, size: 18),
            label: const Text('결석 신고하기'),
          ),
        ),
      ],
    );
  }

  Widget _buildAbsenceRow(
    BuildContext context, {
    required NestController controller,
    required AbsenceReport report,
  }) {
    final childName = _childName(controller, report.childId);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: NestColors.creamyWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_dateLabel(report.occurrenceDate)} · $childName',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  report.reason.trim().isEmpty
                      ? report.statusLabel
                      : '${report.statusLabel} · ${report.reason.trim()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _cancelAbsence(controller, report.id),
            child: const Text('철회'),
          ),
        ],
      ),
    );
  }

  /// 이 수업에 대해 내가 볼 수 있는, 아직 지나지 않은 결석 신고.
  List<AbsenceReport> _upcomingAbsencesForSession(
    NestController controller,
    String sessionId,
  ) {
    final today = _today();
    final rows = controller
        .absencesForSession(sessionId)
        .where((report) {
          if (report.isCanceled) return false;
          final date = report.occurrenceDate;
          return !DateTime(date.year, date.month, date.day).isBefore(today);
        })
        .toList()
      ..sort((a, b) => a.occurrenceDate.compareTo(b.occurrenceDate));
    return rows;
  }

  /// (수업, 학생, 날짜)에 해당하는 살아 있는 결석 신고.
  /// 컨트롤러의 [NestController.absenceFor] 는 학생을 구분하지 않으므로
  /// 한 반에 형제가 함께 있는 가정을 위해 여기서 직접 추린다.
  AbsenceReport? _absenceForChild(
    NestController controller, {
    required String sessionId,
    required String? childId,
    required DateTime date,
  }) {
    if (childId == null || childId.isEmpty) return null;
    final day = DateTime(date.year, date.month, date.day);
    for (final report in controller.absencesForSession(sessionId)) {
      if (report.isCanceled || report.childId != childId) continue;
      final occurrence = report.occurrenceDate;
      if (DateTime(occurrence.year, occurrence.month, occurrence.day) == day) {
        return report;
      }
    }
    return null;
  }

  /// 이 수업에 대해 결석을 신고할 수 있는 학생 후보.
  /// 학부모 뷰는 내 자녀, 학생 뷰는 내 계정에 연결된 자녀가 기준이며,
  /// 반 명부(class_enrollments)로 한 번 더 좁힌다.
  List<ChildProfile> _absenceCandidateChildren(
    NestController controller,
    String classGroupId,
  ) {
    final byId = <String, ChildProfile>{};
    for (final child in controller.myChildren) {
      byId[child.id] = child;
    }
    for (final child in controller.currentUserChildProfiles) {
      byId[child.id] = child;
    }
    final selectedId = widget.selectedChildId;
    if (selectedId != null && !byId.containsKey(selectedId)) {
      for (final child in controller.children) {
        if (child.id == selectedId) {
          byId[child.id] = child;
          break;
        }
      }
    }

    final enrolled = controller
        .enrolledChildIdsForClassGroup(classGroupId)
        .toSet();
    final rows = byId.values
        .where((child) => enrolled.isEmpty || enrolled.contains(child.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  String _childName(NestController controller, String childId) {
    for (final child in controller.children) {
      if (child.id == childId) return child.name;
    }
    return '학생';
  }

  Future<void> _showAbsenceReportSheet(
    BuildContext context, {
    required NestController controller,
    required _ParentScheduleEntry entry,
    required TimeSlot slot,
  }) async {
    final candidates = _absenceCandidateChildren(
      controller,
      entry.session.classGroupId,
    );
    if (candidates.isEmpty) {
      _showMessage('결석을 신고할 수 있는 학생이 없습니다.');
      return;
    }
    final dates = _upcomingDatesFor(controller, slot.dayOfWeek);
    if (dates.isEmpty) {
      _showMessage('남은 수업 회차가 없습니다.');
      return;
    }

    final selectedId = widget.selectedChildId;
    var childId = candidates.any((child) => child.id == selectedId)
        ? selectedId!
        : candidates.first.id;
    DateTime? pickedDate;
    final reasonController = TextEditingController();
    final visibleDates = dates.take(_absenceDateLimit).toList();

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (builderContext, setSheetState) {
              return AnimatedBuilder(
                animation: controller,
                builder: (innerContext, _) {
                  return SafeArea(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight:
                            MediaQuery.of(innerContext).size.height * 0.85,
                      ),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 20,
                          bottom:
                              20 + MediaQuery.of(innerContext).viewInsets.bottom,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.event_busy_outlined,
                                  color: NestColors.clay,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '결석 신고',
                                    style: Theme.of(innerContext)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => Navigator.pop(sheetContext),
                                  icon: const Icon(Icons.close),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${controller.findCourseName(entry.session.courseId)}'
                              ' · ${entry.className}',
                              style: Theme.of(innerContext)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: NestColors.deepWood.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                            ),
                            if (candidates.length > 1) ...[
                              const SizedBox(height: 16),
                              Text(
                                '학생',
                                style: Theme.of(innerContext)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                children: candidates
                                    .map(
                                      (child) => ChoiceChip(
                                        label: Text(child.name),
                                        selected: child.id == childId,
                                        onSelected: (_) => setSheetState(() {
                                          childId = child.id;
                                          pickedDate = null;
                                        }),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              '결석할 날짜',
                              style: Theme.of(innerContext)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 6),
                            ...visibleDates.map(
                              (date) => _buildAbsenceDateRow(
                                innerContext,
                                controller: controller,
                                sessionId: entry.session.id,
                                childId: childId,
                                date: date,
                                isPicked: pickedDate == date,
                                onPick: () =>
                                    setSheetState(() => pickedDate = date),
                              ),
                            ),
                            if (dates.length > visibleDates.length)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '가까운 ${visibleDates.length}회차만 표시합니다.',
                                  style: Theme.of(innerContext)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: NestColors.deepWood.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                ),
                              ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: reasonController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: '사유 (선택)',
                                hintText: '예: 병원 진료',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: pickedDate == null
                                    ? null
                                    : () => _submitAbsence(
                                          sheetContext,
                                          controller: controller,
                                          sessionId: entry.session.id,
                                          childId: childId,
                                          date: pickedDate!,
                                          reason: reasonController.text,
                                        ),
                                icon: const Icon(Icons.send_outlined, size: 18),
                                label: const Text('신고하고 담당 교사에게 알리기'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } finally {
      reasonController.dispose();
    }
  }

  Widget _buildAbsenceDateRow(
    BuildContext context, {
    required NestController controller,
    required String sessionId,
    required String childId,
    required DateTime date,
    required bool isPicked,
    required VoidCallback onPick,
  }) {
    final existing = _absenceForChild(
      controller,
      sessionId: sessionId,
      childId: childId,
      date: date,
    );
    final reported = existing != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isPicked
            ? NestColors.roseMist.withValues(alpha: 0.5)
            : NestColors.creamyWhite,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isPicked ? NestColors.dustyRose : NestColors.roseMist,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: reported ? null : onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                reported
                    ? Icons.check_circle
                    : (isPicked
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked),
                size: 20,
                color: reported ? NestColors.mutedSage : NestColors.clay,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _dateLabel(date),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: reported
                        ? NestColors.deepWood.withValues(alpha: 0.6)
                        : NestColors.deepWood,
                  ),
                ),
              ),
              if (reported) ...[
                _MiniChip(label: '신고됨', color: NestColors.mutedSage),
                TextButton(
                  onPressed: () => _cancelAbsence(controller, existing.id),
                  child: const Text('철회'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitAbsence(
    BuildContext sheetContext, {
    required NestController controller,
    required String sessionId,
    required String childId,
    required DateTime date,
    required String reason,
  }) async {
    final navigator = Navigator.of(sheetContext);
    try {
      final report = await controller.reportAbsence(
        classSessionId: sessionId,
        childId: childId,
        occurrenceDate: date,
        reason: reason,
      );
      if (navigator.canPop()) {
        navigator.pop();
      }
      if (!mounted) return;

      try {
        final result = await controller.notifyAbsence(reportId: report.id);
        _showMessage(_absenceNotifyMessage(result));
      } catch (error) {
        _showMessage(
          '결석은 신고했지만 담당 교사 알림 발송에 실패했습니다. '
          '${error is StateError ? error.message : controller.statusMessage}',
        );
      }
    } catch (error) {
      _showMessage(
        error is StateError ? error.message : controller.statusMessage,
      );
    }
  }

  /// 발송 결과를 부풀리지 않고 그대로 알린다(0명 발송을 성공처럼 쓰지 않는다).
  String _absenceNotifyMessage(NotifyResult result) {
    final sent = result.sent;
    final noPhone = result.skippedNoPhone;
    final noAccount = result.skippedNoAccount;
    final alreadyNotified = result.alreadyNotified;

    if (sent > 0) {
      final skipped = <String>[];
      if (noPhone > 0) skipped.add('전화번호 미등록 $noPhone명');
      if (noAccount > 0) skipped.add('앱 미가입 $noAccount명');
      final suffix = skipped.isEmpty ? '' : ' (${skipped.join(', ')} 제외)';
      return '결석을 신고하고 담당 교사 $sent명에게 문자를 보냈습니다.$suffix';
    }
    if (alreadyNotified) {
      return '결석을 신고했습니다. 담당 교사에게는 이미 알림을 보낸 상태입니다.';
    }
    return '결석을 신고했지만, 담당 교사의 전화번호가 없어 문자는 보내지 못했습니다.';
  }

  Future<void> _cancelAbsence(
    NestController controller,
    String reportId,
  ) async {
    try {
      await controller.cancelAbsenceReport(id: reportId);
      _showMessage('결석 신고를 철회했습니다.');
    } catch (error) {
      _showMessage(
        error is StateError ? error.message : controller.statusMessage,
      );
    }
  }

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // ── 날짜 헬퍼 ──

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// 학기 안에서 [dayOfWeek] 에 해당하는, 오늘 포함 이후 날짜들.
  /// 서버 RPC 도 `occurrence_date < current_date` 만 거부하므로 오늘은 포함한다.
  List<DateTime> _upcomingDatesFor(NestController controller, int dayOfWeek) {
    final term = controller.selectedTerm;
    final start = term?.startDate;
    final end = term?.endDate;
    if (start == null || end == null) {
      return const [];
    }
    final today = _today();
    return datesForWeekday(start, end, dayOfWeek)
        .where((date) => !date.isBefore(today))
        .toList();
  }

  /// 시간표 셀이 가리키는 "다음 회차" 날짜.
  /// 학기가 이미 끝났으면 마지막 회차를, 학기 정보가 없으면 이번 주 해당 요일을
  /// 쓴다. 변경/결석 배지의 기준 날짜이며 화면을 비우지 않기 위한 폴백이다.
  DateTime _referenceDateFor(NestController controller, int dayOfWeek) {
    final cached = _referenceDateCache[dayOfWeek];
    if (cached != null) {
      return cached;
    }

    DateTime resolved;
    final upcoming = _upcomingDatesFor(controller, dayOfWeek);
    if (upcoming.isNotEmpty) {
      resolved = upcoming.first;
    } else {
      final term = controller.selectedTerm;
      final start = term?.startDate;
      final end = term?.endDate;
      final all = (start == null || end == null)
          ? const <DateTime>[]
          : datesForWeekday(start, end, dayOfWeek);
      if (all.isNotEmpty) {
        resolved = all.last;
      } else {
        final today = _today();
        final target = dayOfWeek == 0 ? 7 : dayOfWeek;
        resolved = today.add(Duration(days: (target - today.weekday) % 7));
      }
    }

    _referenceDateCache[dayOfWeek] = resolved;
    return resolved;
  }

  /// '9월 3일 (목)'.
  String _dateLabel(DateTime date) {
    return '${date.month}월 ${date.day}일 (${_dayLabel(date.weekday % 7)})';
  }

  List<_ParentScheduleEntry> _collectScheduleEntries(
    NestController controller,
    Map<String, ChildClassBundle> bundles,
  ) {
    final rows = <_ParentScheduleEntry>[];
    final sorted = bundles.values.toList()
      ..sort((a, b) => a.classGroup.name.compareTo(b.classGroup.name));

    for (final bundle in sorted) {
      for (final session in bundle.sessions) {
        if (controller.findTimeSlot(session.timeSlotId) == null) continue;
        rows.add(
          _ParentScheduleEntry(
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
    final source = value.trim();
    final parts = source.split(':');
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

    return rows
        .map((row) {
          final name = controller.findTeacherName(row.teacherProfileId);
          return row.assignmentRole == 'MAIN' ? '주강사 $name' : '보조 $name';
        })
        .join(', ');
  }

  String _dayLabel(int dayOfWeek) {
    const labels = <int, String>{
      0: '일', 1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토',
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

  /// Convert "HH:mm:ss" or "HH:mm" to Korean style: "9시", "9시반", "10시"
  String _koreanTime(String value) {
    final minutes = _clockToMinute(value);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '$h시';
    if (m == 30) return '$h시반';
    return '$h:${m.toString().padLeft(2, '0')}';
  }
}

// ── Private helper classes ──

class _ParentScheduleEntry {
  const _ParentScheduleEntry({
    required this.className,
    required this.session,
    required this.assignments,
  });

  final String className;
  final ClassSession session;
  final List<SessionTeacherAssignment> assignments;
}

class _ScheduleHeaderCell extends StatelessWidget {
  const _ScheduleHeaderCell({
    required this.width,
    required this.label,
    required this.align,
  });

  final double width;
  final String label;
  final Alignment align;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      alignment: align,
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

/// Simplified cell showing only the subject name; tappable for detail.
/// [change] 가 있으면 다음 회차에 적용될 수업 변경을, [hasAbsence] 가 true 면
/// 선택된 아이의 결석 신고를 한눈에 보이게 표시한다.
class _SubjectNameCell extends StatelessWidget {
  const _SubjectNameCell({
    required this.courseName,
    required this.onTap,
    this.compact = false,
    this.change,
    this.hasAbsence = false,
  });

  final String courseName;
  final VoidCallback onTap;
  final bool compact;
  final ClassSessionChange? change;
  final bool hasAbsence;

  @override
  Widget build(BuildContext context) {
    final activeChange = change;
    final isCanceled = activeChange?.changeType == 'CANCELED';
    final accent = isCanceled
        ? Theme.of(context).colorScheme.error
        : NestColors.clay;
    final badgeFontSize = compact ? 9.0 : 10.0;

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
          color: activeChange == null
              ? NestColors.roseMist.withValues(alpha: 0.26)
              : accent.withValues(alpha: 0.12),
          border: Border.all(
            color: activeChange == null
                ? NestColors.roseMist
                : accent.withValues(alpha: 0.55),
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
                    color: isCanceled ? accent : null,
                    decoration:
                        isCanceled ? TextDecoration.lineThrough : null,
                    decorationColor: isCanceled ? accent : null,
                  ),
            ),
            if (activeChange != null) ...[
              const SizedBox(height: 2),
              Text(
                activeChange.changeTypeLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: badgeFontSize,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
            if (hasAbsence) ...[
              const SizedBox(height: 2),
              Text(
                '결석 신고',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: badgeFontSize,
                  fontWeight: FontWeight.w700,
                  color: NestColors.mutedSage,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 작은 상태 칩('신고됨', '9월 3일 적용' 등).
class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
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
