import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/child_selector_header.dart';
import '../widgets/entity_visuals.dart';

class ParentTimetableTab extends StatefulWidget {
  const ParentTimetableTab({
    super.key,
    required this.controller,
    required this.selectedChildId,
    required this.childClassBundles,
    required this.onSelectChild,
    required this.isLoadingChildClasses,
  });

  final NestController controller;
  final String? selectedChildId;
  final Map<String, ChildClassBundle> childClassBundles;
  final ValueChanged<String?> onSelectChild;
  final bool isLoadingChildClasses;

  @override
  State<ParentTimetableTab> createState() => _ParentTimetableTabState();
}

class _ParentTimetableTabState extends State<ParentTimetableTab> {
  final _unavailabilityStartController = TextEditingController(text: '09:00');
  final _unavailabilityEndController = TextEditingController(text: '10:00');
  final _unavailabilityNoteController = TextEditingController();
  int _selectedUnavailabilityDay = 1;

  @override
  void dispose() {
    _unavailabilityStartController.dispose();
    _unavailabilityEndController.dispose();
    _unavailabilityNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bundles = widget.childClassBundles;
    final enrolledClassCount = bundles.length;
    final enrolledSessionCount = bundles.values
        .map((b) => b.sessions.length)
        .fold<int>(0, (acc, v) => acc + v);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        ChildSelectorHeader(
          controller: controller,
          selectedChildId: widget.selectedChildId,
          childClassBundles: bundles,
          onSelectChild: widget.onSelectChild,
          isLoadingChildClasses: widget.isLoadingChildClasses,
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 700;
            final cardWidth = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    icon: Icons.groups,
                    label: '배정 반',
                    value: '$enrolledClassCount',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _MetricCard(
                    icon: Icons.view_week,
                    label: '주간 수업',
                    value: '$enrolledSessionCount',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              color: NestColors.deepWood.withValues(alpha: 0.74),
            ),
            const SizedBox(width: 8),
            Text('내 아이 시간표', style: Theme.of(context).textTheme.titleLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _openUnavailabilitySheet(controller),
              icon: const Icon(Icons.block, size: 18),
              label: const Text('내 불가 시간'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Timetable cards
        if (widget.selectedChildId == null)
          _buildEmptyHint('아이를 먼저 선택하세요.')
        else if (bundles.isEmpty && !widget.isLoadingChildClasses)
          _buildEmptyHint('배정된 반 또는 시간표가 없습니다.')
        else ...[
          _buildWeeklyScheduleBoard(controller, bundles),
          const SizedBox(height: 14),
          Text('반별 상세', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._buildTimetableCards(controller, bundles),
        ],
      ],
    );
  }

  List<Widget> _buildTimetableCards(
    NestController controller,
    Map<String, ChildClassBundle> bundles,
  ) {
    final sorted = bundles.values.toList(growable: false)
      ..sort((a, b) => a.classGroup.name.compareTo(b.classGroup.name));

    return sorted
        .map((bundle) {
          final sessions = bundle.sessions.toList(growable: false)
            ..sort((a, b) {
              final left = controller.findTimeSlot(a.timeSlotId);
              final right = controller.findTimeSlot(b.timeSlotId);
              if (left == null || right == null) {
                return a.timeSlotId.compareTo(b.timeSlotId);
              }
              final dayCompare = left.dayOfWeek.compareTo(right.dayOfWeek);
              if (dayCompare != 0) return dayCompare;
              return left.startTime.compareTo(right.startTime);
            });

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        EntityAvatar(
                          label: bundle.classGroup.name,
                          icon: Icons.groups_2_outlined,
                          size: 42,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            bundle.classGroup.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const Spacer(),
                        Chip(
                          avatar: const Icon(Icons.campaign_outlined, size: 14),
                          label: Text('공지 ${bundle.announcements.length}'),
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(width: 6),
                        Chip(
                          avatar: const Icon(Icons.schedule, size: 14),
                          label: Text('${sessions.length}수업'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (sessions.isEmpty)
                      _buildEmptyHint('등록된 수업이 없습니다.')
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 900;
                          final tileWidth = compact
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2;
                          return Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: sessions
                                .map((session) {
                                  final slot = controller.findTimeSlot(
                                    session.timeSlotId,
                                  );
                                  final teachers = _teacherLabelForSession(
                                    controller: controller,
                                    sessionId: session.id,
                                    assignments: bundle.assignments,
                                  );
                                  final slotLabel = slot == null
                                      ? session.timeSlotId
                                      : '${_dayLabel(slot.dayOfWeek)} ${_shortTime(slot.startTime)}-${_shortTime(slot.endTime)}';
                                  final location = (session.location ?? '')
                                      .trim();
                                  final roomLabel = location.isEmpty
                                      ? '장소 미지정'
                                      : location;

                                  return Container(
                                    width: tileWidth,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: NestColors.roseMist,
                                      ),
                                      color: Colors.white,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.menu_book_rounded,
                                              size: 18,
                                              color: NestColors.clay,
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                controller.findCourseName(
                                                  session.courseId,
                                                ),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        _InfoRow(
                                          icon: Icons.schedule_outlined,
                                          text: slotLabel,
                                        ),
                                        const SizedBox(height: 4),
                                        _InfoRow(
                                          icon: Icons.school_outlined,
                                          text: teachers,
                                        ),
                                        const SizedBox(height: 4),
                                        _InfoRow(
                                          icon: Icons.meeting_room_outlined,
                                          text: roomLabel,
                                        ),
                                      ],
                                    ),
                                  );
                                })
                                .toList(growable: false),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          );
        })
        .toList(growable: false);
  }

  Widget _buildWeeklyScheduleBoard(
    NestController controller,
    Map<String, ChildClassBundle> bundles,
  ) {
    final entries = _collectScheduleEntries(controller, bundles);
    if (entries.isEmpty) {
      return _buildEmptyHint('시간표 데이터가 없습니다.');
    }

    final slotById = {for (final slot in controller.timeSlots) slot.id: slot};
    final days = <int>{};
    final periodKeys = <String>{};
    final byPeriodDay = <String, Map<int, List<_ParentScheduleEntry>>>{};

    for (final entry in entries) {
      final slot = slotById[entry.session.timeSlotId];
      if (slot == null) {
        continue;
      }

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
      return _buildEmptyHint('시간표 슬롯 정보를 찾을 수 없습니다.');
    }

    final sortedDays = days.toList(growable: false)..sort();
    final sortedPeriods = periodKeys.toList(growable: false)
      ..sort((a, b) => _comparePeriodKey(a, b));

    const timeColWidth = 128.0;
    final dayColWidth = sortedDays.length >= 5 ? 210.0 : 230.0;
    final boardWidth = timeColWidth + dayColWidth * sortedDays.length;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: NestColors.roseMist),
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: boardWidth,
          child: Column(
            children: [
              Row(
                children: [
                  _ScheduleHeaderCell(
                    width: timeColWidth,
                    label: '교시 / 시간',
                    align: Alignment.center,
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
                final periodIndex = rowEntry.key + 1;
                final periodKey = rowEntry.value;
                final segments = periodKey.split('-');
                final periodLabel = segments.length == 2
                    ? '${_shortTime(segments[0])} - ${_shortTime(segments[1])}'
                    : periodKey;

                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(
                        color: NestColors.roseMist.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: timeColWidth,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 12,
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '$periodIndex교시',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                periodLabel,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: NestColors.deepWood.withValues(
                                        alpha: 0.72,
                                      ),
                                    ),
                              ),
                            ],
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
                          padding: const EdgeInsets.all(8),
                          child: cells.isEmpty
                              ? Center(
                                  child: Text(
                                    '-',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: NestColors.deepWood.withValues(
                                            alpha: 0.48,
                                          ),
                                        ),
                                  ),
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: cells
                                      .map(
                                        (cell) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: _ParentScheduleCell(
                                            courseName: controller
                                                .findCourseName(
                                                  cell.session.courseId,
                                                ),
                                            className: cell.className,
                                            teacherLabel:
                                                _teacherLabelForSession(
                                                  controller: controller,
                                                  sessionId: cell.session.id,
                                                  assignments: cell.assignments,
                                                ),
                                            locationLabel:
                                                (cell.session.location ?? '')
                                                    .trim()
                                                    .isEmpty
                                                ? '장소 미지정'
                                                : (cell.session.location ?? '')
                                                      .trim(),
                                          ),
                                        ),
                                      )
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
        ),
      ),
    );
  }

  List<_ParentScheduleEntry> _collectScheduleEntries(
    NestController controller,
    Map<String, ChildClassBundle> bundles,
  ) {
    final rows = <_ParentScheduleEntry>[];
    final sorted = bundles.values.toList(growable: false)
      ..sort((a, b) => a.classGroup.name.compareTo(b.classGroup.name));

    for (final bundle in sorted) {
      for (final session in bundle.sessions) {
        if (controller.findTimeSlot(session.timeSlotId) == null) {
          continue;
        }
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
      if (dayCompare != 0) {
        return dayCompare;
      }
      final startCompare = leftSlot.startTime.compareTo(rightSlot.startTime);
      if (startCompare != 0) {
        return startCompare;
      }
      return a.className.compareTo(b.className);
    });
    return rows;
  }

  int _comparePeriodKey(String left, String right) {
    final leftParts = left.split('-');
    final rightParts = right.split('-');
    final leftStart = leftParts.firstOrNull ?? left;
    final rightStart = rightParts.firstOrNull ?? right;

    final startCompare = _clockToMinute(
      leftStart,
    ).compareTo(_clockToMinute(rightStart));
    if (startCompare != 0) {
      return startCompare;
    }

    final leftEnd = leftParts.length > 1 ? leftParts[1] : left;
    final rightEnd = rightParts.length > 1 ? rightParts[1] : right;
    return _clockToMinute(leftEnd).compareTo(_clockToMinute(rightEnd));
  }

  int _clockToMinute(String value) {
    final source = value.trim();
    final parts = source.split(':');
    if (parts.length < 2) {
      return 0;
    }
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  void _openUnavailabilitySheet(NestController controller) {
    final currentUserId = controller.user?.id;
    if (currentUserId == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final blocks =
                controller.memberUnavailabilityBlocks
                    .where(
                      (row) =>
                          row.ownerKind == 'MEMBER_USER' &&
                          row.ownerId == currentUserId,
                    )
                    .toList(growable: false)
                  ..sort((a, b) {
                    final day = a.dayOfWeek.compareTo(b.dayOfWeek);
                    if (day != 0) return day;
                    return a.startTime.compareTo(b.startTime);
                  });

            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      Row(
                        children: [
                          Text(
                            '내 불가 시간 설정',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '등록한 시간은 시간표 생성 시 자동으로 회피됩니다.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 600;
                          final dayField = _buildDayField(
                            controller,
                            setSheetState,
                          );
                          final startField = _buildTimeField(
                            controller: _unavailabilityStartController,
                            label: '시작 (HH:MM)',
                          );
                          final endField = _buildTimeField(
                            controller: _unavailabilityEndController,
                            label: '종료 (HH:MM)',
                          );

                          if (compact) {
                            return Column(
                              children: [
                                dayField,
                                const SizedBox(height: 8),
                                startField,
                                const SizedBox(height: 8),
                                endField,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(flex: 3, child: dayField),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: startField),
                              const SizedBox(width: 8),
                              Expanded(flex: 2, child: endField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _unavailabilityNoteController,
                        decoration: const InputDecoration(
                          labelText: '메모 (선택)',
                          prefixIcon: Icon(Icons.edit_note),
                        ),
                        minLines: 1,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton.icon(
                        onPressed: controller.isBusy
                            ? null
                            : () async {
                                await _createBlock(currentUserId);
                                if (context.mounted) setSheetState(() {});
                              },
                        icon: const Icon(Icons.add),
                        label: const Text('불가 시간 추가'),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        '등록 항목',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      if (blocks.isEmpty)
                        _buildEmptyHint('등록된 불가 시간이 없습니다.')
                      else
                        ...blocks.map((block) {
                          final day = _dayLabel(block.dayOfWeek);
                          final start = _shortTime(block.startTime);
                          final end = _shortTime(block.endTime);
                          final note = block.note.trim();

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: NestColors.roseMist),
                              ),
                              child: ListTile(
                                dense: true,
                                leading: const Icon(Icons.schedule),
                                title: Text('$day · $start - $end'),
                                subtitle: note.isEmpty ? null : Text(note),
                                trailing: IconButton(
                                  onPressed: controller.isBusy
                                      ? null
                                      : () async {
                                          await _deleteBlock(block.id);
                                          if (context.mounted) {
                                            setSheetState(() {});
                                          }
                                        },
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDayField(NestController controller, StateSetter setSheetState) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedUnavailabilityDay,
      decoration: const InputDecoration(
        labelText: '요일',
        prefixIcon: Icon(Icons.calendar_today_outlined),
      ),
      items: const [
        DropdownMenuItem(value: 0, child: Text('Sun')),
        DropdownMenuItem(value: 1, child: Text('Mon')),
        DropdownMenuItem(value: 2, child: Text('Tue')),
        DropdownMenuItem(value: 3, child: Text('Wed')),
        DropdownMenuItem(value: 4, child: Text('Thu')),
        DropdownMenuItem(value: 5, child: Text('Fri')),
        DropdownMenuItem(value: 6, child: Text('Sat')),
      ],
      onChanged: controller.isBusy
          ? null
          : (value) {
              if (value == null) return;
              setState(() => _selectedUnavailabilityDay = value);
              setSheetState(() {});
            },
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.access_time),
      ),
    );
  }

  Future<void> _createBlock(String userId) async {
    try {
      await widget.controller.createMemberUnavailabilityBlock(
        ownerKind: 'MEMBER_USER',
        ownerId: userId,
        dayOfWeek: _selectedUnavailabilityDay,
        startTime: _unavailabilityStartController.text,
        endTime: _unavailabilityEndController.text,
        note: _unavailabilityNoteController.text,
      );
      _unavailabilityNoteController.clear();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _deleteBlock(String blockId) async {
    try {
      await widget.controller.deleteMemberUnavailabilityBlock(blockId: blockId);
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  // ── Helpers ──

  String _teacherLabelForSession({
    required NestController controller,
    required String sessionId,
    required List<SessionTeacherAssignment> assignments,
  }) {
    final rows =
        assignments
            .where((row) => row.classSessionId == sessionId)
            .toList(growable: false)
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

  Widget _buildEmptyHint(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.roseMist.withValues(alpha: 0.36),
      ),
      child: Text(message),
    );
  }

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

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
        style: Theme.of(
          context,
        ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ParentScheduleCell extends StatelessWidget {
  const _ParentScheduleCell({
    required this.courseName,
    required this.className,
    required this.teacherLabel,
    required this.locationLabel,
  });

  final String courseName;
  final String className;
  final String teacherLabel;
  final String locationLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: NestColors.roseMist.withValues(alpha: 0.26),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            courseName,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            className,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            teacherLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            locationLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
        color: Colors.white,
      ),
      child: Row(
        children: [
          EntityAvatar(label: label, icon: icon, size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 15,
          color: NestColors.deepWood.withValues(alpha: 0.72),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}
