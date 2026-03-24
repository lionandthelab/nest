import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
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
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bundles = widget.childClassBundles;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (widget.isLoadingChildClasses && bundles.isEmpty) ...[
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

  Widget _buildWeeklyScheduleBoard(
    NestController controller,
    Map<String, ChildClassBundle> bundles,
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
    final byPeriodDay = <String, Map<int, List<_ParentScheduleEntry>>>{};

    for (final entry in entries) {
      final slot = slotById[entry.session.timeSlotId];
      if (slot == null) continue;

      final periodKey = '${slot.startTime}-${slot.endTime}';
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
        final naturalWidth =
            naturalTimeCol + naturalDayCol * sortedDays.length;
        final scale = naturalWidth > availableWidth
            ? availableWidth / naturalWidth
            : 1.0;
        final timeColWidth = naturalTimeCol * scale;
        final dayColWidth = naturalDayCol * scale;
        final boardWidth = timeColWidth + dayColWidth * sortedDays.length;

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

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return Padding(
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
                    onPressed: () => Navigator.pop(ctx),
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
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
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
class _SubjectNameCell extends StatelessWidget {
  const _SubjectNameCell({
    required this.courseName,
    required this.onTap,
    this.compact = false,
  });

  final String courseName;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
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
          color: NestColors.roseMist.withValues(alpha: 0.26),
          border: Border.all(color: NestColors.roseMist),
        ),
        child: Text(
          courseName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: compact ? 11 : null,
              ),
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
