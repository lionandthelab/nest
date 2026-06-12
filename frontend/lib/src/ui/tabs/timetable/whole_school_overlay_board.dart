import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/nest_models.dart';
import '../../../state/nest_controller.dart';
import '../../nest_theme.dart';
import '../../widgets/horizontal_mouse_scroll.dart';
import 'room_normalizer.dart';

/// Pivot axis for the whole-school overlay board.
enum WholeSchoolAxis { byClass, byRoom, byTeacher }

/// Reference to a tapped column header, surfaced to [WholeSchoolOverlayBoard]'s
/// `onColumnTap` so a parent can drive the inspector rail's selection.
class WholeSchoolColumnRef {
  const WholeSchoolColumnRef({required this.axis, required this.id});

  final WholeSchoolAxis axis;

  /// The entity id for the column: classGroupId (byClass), teacherProfileId
  /// (byTeacher), or the normalized room display name (byRoom).
  final String id;
}

/// A STRICTLY READ-ONLY whole-school ("한눈에") overlay board.
///
/// Rows = unique time periods grouped by day (mirrors the per-class grid's
/// period/day layout). Columns pivot on [axis]: each class / room / teacher.
/// It only reads [NestController] collections + helpers and never mutates.
/// Conflicts (room double-booking, teacher double-booking with different
/// courses) are highlighted in red. Teacher unavailability is shaded.
class WholeSchoolOverlayBoard extends StatelessWidget {
  const WholeSchoolOverlayBoard({
    super.key,
    required this.controller,
    required this.axis,
    this.onColumnTap,
  });

  final NestController controller;
  final WholeSchoolAxis axis;
  final void Function(WholeSchoolColumnRef ref)? onColumnTap;

  @override
  Widget build(BuildContext context) {
    final sortedSlots = controller.timeSlots.toList()
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) return day;
        return a.startTime.compareTo(b.startTime);
      });

    if (sortedSlots.isEmpty) {
      return _emptyNote(context, '시간 슬롯이 없습니다. 교시 설정을 먼저 진행하세요.');
    }

    final columns = _buildColumns();
    if (columns.isEmpty) {
      return _emptyNote(context, _emptyColumnMessage());
    }

    // Sessions grouped by slot id for fast cell lookup.
    final sessionsBySlotId = <String, List<ClassSession>>{};
    for (final session in controller.allTermSessions) {
      sessionsBySlotId.putIfAbsent(session.timeSlotId, () => []).add(session);
    }

    // Unique time periods across days + the slot that maps (period, day).
    final periodSet = <String>{};
    final slotByPeriodDay = <String, Map<int, TimeSlot>>{};
    for (final slot in sortedSlots) {
      final key = '${slot.startTime}\t${slot.endTime}';
      periodSet.add(key);
      slotByPeriodDay.putIfAbsent(key, () => <int, TimeSlot>{});
      slotByPeriodDay[key]![slot.dayOfWeek] = slot;
    }
    final uniquePeriods = periodSet.toList()..sort();

    final daySet = sortedSlots.map((s) => s.dayOfWeek).toSet();
    final dayOrder = daySet.toList()..sort();

    const timeWidth = 96.0;
    const columnWidth = 168.0;
    const gap = 6.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLegend(context),
        const SizedBox(height: 6),
        Text(
          '전교 보기는 읽기 전용입니다. 수정하려면 반을 선택해 편집 모드로 전환하세요.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: NestColors.deepWood.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 10),
        HorizontalMouseScroll(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              border: Border.all(color: NestColors.roseMist),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: 시간 | column labels.
                Row(
                  children: [
                    _headerCell(context, width: timeWidth, title: '시간'),
                    ...columns.map(
                      (column) => _columnHeaderCell(
                        context,
                        width: columnWidth,
                        column: column,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Day bands + their period rows.
                ...dayOrder.expand((day) {
                  final periodsForDay = uniquePeriods.where((pk) {
                    return slotByPeriodDay[pk]?.containsKey(day) == true;
                  }).toList();
                  if (periodsForDay.isEmpty) return <Widget>[];

                  return [
                    _dayBand(
                      context,
                      day: day,
                      width: timeWidth +
                          columns.length * columnWidth +
                          columns.length * gap,
                    ),
                    ...periodsForDay.map((periodKey) {
                      final parts = periodKey.split('\t');
                      final timeLabel =
                          '${_shortTime(parts[0])}-${_shortTime(parts[1])}';
                      final slot = slotByPeriodDay[periodKey]![day]!;
                      final slotSessions = sessionsBySlotId[slot.id] ?? const [];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _timeCell(
                              context,
                              width: timeWidth,
                              label: timeLabel,
                            ),
                            ...columns.map(
                              (column) => _buildCell(
                                context,
                                width: columnWidth,
                                column: column,
                                slot: slot,
                                slotSessions: slotSessions,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ];
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Column model
  // ---------------------------------------------------------------------------

  List<_OverlayColumn> _buildColumns() {
    switch (axis) {
      case WholeSchoolAxis.byClass:
        final groups = controller.classGroups.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return groups
            .map((g) => _OverlayColumn(id: g.id, label: g.name))
            .toList();
      case WholeSchoolAxis.byRoom:
        // Distinct rooms = classroom names ∪ non-empty session locations,
        // deduped by RoomNormalizer.canonical. Keep the first display form.
        final byCanonical = <String, String>{};
        for (final classroom in controller.classrooms) {
          final display = RoomNormalizer.normalize(classroom.name);
          if (display.isEmpty) continue;
          byCanonical.putIfAbsent(RoomNormalizer.canonical(display), () => display);
        }
        for (final session in controller.allTermSessions) {
          final raw = session.location ?? '';
          final display = RoomNormalizer.normalize(raw);
          if (display.isEmpty) continue;
          byCanonical.putIfAbsent(RoomNormalizer.canonical(display), () => display);
        }
        final rooms = byCanonical.values.toList()..sort();
        return rooms.map((r) => _OverlayColumn(id: r, label: r)).toList();
      case WholeSchoolAxis.byTeacher:
        final teachers = controller.teacherProfiles.toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));
        return teachers
            .map((t) => _OverlayColumn(id: t.id, label: t.displayName))
            .toList();
    }
  }

  // ---------------------------------------------------------------------------
  // Cell building
  // ---------------------------------------------------------------------------

  Widget _buildCell(
    BuildContext context, {
    required double width,
    required _OverlayColumn column,
    required TimeSlot slot,
    required List<ClassSession> slotSessions,
  }) {
    switch (axis) {
      case WholeSchoolAxis.byClass:
        return _buildClassCell(context,
            width: width, column: column, slotSessions: slotSessions);
      case WholeSchoolAxis.byRoom:
        return _buildRoomCell(context,
            width: width, column: column, slotSessions: slotSessions);
      case WholeSchoolAxis.byTeacher:
        return _buildTeacherCell(context,
            width: width, column: column, slot: slot, slotSessions: slotSessions);
    }
  }

  Widget _buildClassCell(
    BuildContext context, {
    required double width,
    required _OverlayColumn column,
    required List<ClassSession> slotSessions,
  }) {
    final matches =
        slotSessions.where((s) => s.classGroupId == column.id).toList();
    return _cellShell(
      context,
      width: width,
      conflict: false,
      empty: matches.isEmpty,
      children: matches
          .map((s) => _sessionLine(context, s, showClass: false))
          .toList(),
    );
  }

  Widget _buildRoomCell(
    BuildContext context, {
    required double width,
    required _OverlayColumn column,
    required List<ClassSession> slotSessions,
  }) {
    final columnKey = RoomNormalizer.canonical(column.id);
    final matches = slotSessions.where((s) {
      final loc = RoomNormalizer.canonical(s.location ?? '');
      return loc.isNotEmpty && loc == columnKey;
    }).toList();

    final conflict = matches.length >= 2;
    return _cellShell(
      context,
      width: width,
      conflict: conflict,
      empty: matches.isEmpty,
      badge: conflict ? '중복 ${matches.length}' : null,
      children: matches
          .map((s) => _sessionLine(context, s, showClass: true))
          .toList(),
    );
  }

  Widget _buildTeacherCell(
    BuildContext context, {
    required double width,
    required _OverlayColumn column,
    required TimeSlot slot,
    required List<ClassSession> slotSessions,
  }) {
    final teacherSessionIds = controller.allTermSessionTeacherAssignments
        .where((row) => row.teacherProfileId == column.id)
        .map((row) => row.classSessionId)
        .toSet();
    final matches =
        slotSessions.where((s) => teacherSessionIds.contains(s.id)).toList();

    // Conflict = 2+ sessions for this teacher at the same slot with DIFFERENT
    // courses (same course = combined class, allowed).
    final distinctCourses = matches.map((s) => s.courseId).toSet();
    final conflict = matches.length >= 2 && distinctCourses.length >= 2;

    final unavailable = _teacherUnavailable(column.id, slot);

    return _cellShell(
      context,
      width: width,
      conflict: conflict,
      empty: matches.isEmpty,
      unavailable: unavailable,
      badge: conflict ? '중복 ${matches.length}' : null,
      children: matches
          .map((s) => _sessionLine(context, s, showClass: true))
          .toList(),
    );
  }

  bool _teacherUnavailable(String teacherProfileId, TimeSlot slot) {
    for (final block in controller.memberUnavailabilityBlocks) {
      if (block.ownerKind != 'TEACHER_PROFILE' ||
          block.ownerId != teacherProfileId) {
        continue;
      }
      if (block.dayOfWeek != slot.dayOfWeek) continue;
      // Half-open overlap: start < otherEnd && otherStart < end.
      if (slot.startTime.compareTo(block.endTime) < 0 &&
          block.startTime.compareTo(slot.endTime) < 0) {
        return true;
      }
    }
    return false;
  }

  /// One session summary: course name + 📍room + teacher initials, with an
  /// optional class-name prefix (for room/teacher axes where the class isn't
  /// the column).
  Widget _sessionLine(
    BuildContext context,
    ClassSession session, {
    required bool showClass,
  }) {
    final courseName = controller.findCourseName(session.courseId);
    final room = RoomNormalizer.normalize(session.location ?? '');
    final initials = _teacherInitials(session.id);
    final classPrefix =
        showClass ? '${controller.findClassGroupName(session.classGroupId)} · ' : '';

    final parts = <String>[];
    if (room.isNotEmpty) parts.add('📍$room');
    if (initials.isNotEmpty) parts.add(initials);

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$classPrefix$courseName',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: NestColors.deepWood,
            ),
          ),
          if (parts.isNotEmpty)
            Text(
              parts.join('  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.7),
              ),
            ),
        ],
      ),
    );
  }

  String _teacherInitials(String sessionId) {
    final names = controller.allTermSessionTeacherAssignments
        .where((row) => row.classSessionId == sessionId)
        .map((row) => controller.findTeacherName(row.teacherProfileId).trim())
        .where((name) => name.isNotEmpty)
        .map(_initial)
        .toList();
    return names.join(',');
  }

  /// First 1-2 characters of a display name (Korean names are short, so 2
  /// chars reads well; ASCII names fall back to up to 2 too).
  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.length <= 2) return trimmed;
    return trimmed.substring(0, 2);
  }

  // ---------------------------------------------------------------------------
  // Shared cell / header chrome
  // ---------------------------------------------------------------------------

  Widget _cellShell(
    BuildContext context, {
    required double width,
    required bool conflict,
    required bool empty,
    required List<Widget> children,
    bool unavailable = false,
    String? badge,
  }) {
    final Color background;
    final Color borderColor;
    if (conflict) {
      background = Colors.red.shade50;
      borderColor = Colors.red.shade400;
    } else if (unavailable) {
      background = NestColors.roseMist.withValues(alpha: 0.55);
      borderColor = NestColors.roseMist;
    } else if (empty) {
      background = Colors.white;
      borderColor = NestColors.roseMist;
    } else {
      background = NestColors.creamyWhite;
      borderColor = NestColors.roseMist;
    }

    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: background,
        border: Border.all(
          color: borderColor,
          width: conflict ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null) ...[
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.red.shade400,
              ),
              child: Text(
                badge,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
          ],
          if (empty)
            Text(
              '-',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.3),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }

  Widget _headerCell(
    BuildContext context, {
    required double width,
    required String title,
  }) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.roseMist.withValues(alpha: 0.72),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _columnHeaderCell(
    BuildContext context, {
    required double width,
    required _OverlayColumn column,
  }) {
    final ref = WholeSchoolColumnRef(axis: axis, id: column.id);
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 6),
      child: Material(
        color: NestColors.roseMist.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onColumnTap == null ? null : () => onColumnTap!(ref),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NestColors.roseMist),
            ),
            child: Text(
              column.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeCell(
    BuildContext context, {
    required double width,
    required String label,
  }) {
    return Container(
      width: width,
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: NestColors.creamyWhite,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }

  Widget _dayBand(
    BuildContext context, {
    required int day,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
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
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _legendItem(
          context,
          color: Colors.red.shade400,
          label: '중복(충돌)',
        ),
        if (axis == WholeSchoolAxis.byTeacher)
          _legendItem(
            context,
            color: NestColors.roseMist,
            label: '불가시간',
          ),
        _legendItem(
          context,
          color: NestColors.creamyWhite,
          label: '배정됨',
        ),
      ],
    );
  }

  Widget _legendItem(
    BuildContext context, {
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: color,
            border: Border.all(color: NestColors.roseMist),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _emptyNote(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.creamyWhite,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  String _emptyColumnMessage() {
    switch (axis) {
      case WholeSchoolAxis.byClass:
        return '표시할 반이 없습니다.';
      case WholeSchoolAxis.byRoom:
        return '배정된 장소가 없습니다.';
      case WholeSchoolAxis.byTeacher:
        return '등록된 선생님이 없습니다.';
    }
  }
}

class _OverlayColumn {
  const _OverlayColumn({required this.id, required this.label});

  final String id;
  final String label;
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
