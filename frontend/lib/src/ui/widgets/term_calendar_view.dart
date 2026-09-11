import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/schedule_occurrence.dart';
import '../../services/schedule_overlap.dart';
import '../nest_theme.dart';
import 'nest_motion.dart';

/// 학기 한 달을 격자로 보여 주고, 날을 누르면 수업·학사·개인 일정을 펼친다.
class TermCalendarView extends StatefulWidget {
  const TermCalendarView({
    super.key,
    required this.academicEvents,
    required this.personalEvents,
    required this.classesOnDate,
    required this.courseNameOf,
    this.termStart,
    this.termEnd,
    this.childId,
    this.canAddPersonal = false,
    this.onAddPersonal,
    this.onEditPersonal,
    this.onOpenAcademic,
  });

  final List<AcademicEvent> academicEvents;
  final List<PersonalEvent> personalEvents;
  final List<ResolvedOccurrence> Function(DateTime date) classesOnDate;
  final String Function(String courseId) courseNameOf;
  final DateTime? termStart;
  final DateTime? termEnd;
  final String? childId;
  final bool canAddPersonal;
  final void Function(DateTime date)? onAddPersonal;
  final void Function(PersonalEvent event)? onEditPersonal;
  final void Function(AcademicEvent event)? onOpenAcademic;

  @override
  State<TermCalendarView> createState() => _TermCalendarViewState();
}

class _TermCalendarViewState extends State<TermCalendarView> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = _initialMonth();
  }

  DateTime _initialMonth() {
    final now = DateTime.now();
    final start = widget.termStart;
    final end = widget.termEnd;
    if (start != null && end != null) {
      if (now.isBefore(start)) return DateTime(start.year, start.month);
      if (now.isAfter(end)) return DateTime(end.year, end.month);
    }
    return DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    final leading = first.weekday - 1; // Monday-first
    final cells = leading + daysInMonth;
    final rows = ((cells + 6) ~/ 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: '이전 달',
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month - 1);
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                DateFormat('yyyy년 M월', 'ko').format(_month),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            IconButton(
              tooltip: '다음 달',
              onPressed: () => setState(() {
                _month = DateTime(_month.year, _month.month + 1);
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: const ['월', '화', '수', '목', '금', '토', '일']
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: NestColors.clay,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < rows; row++)
          Row(
            children: List.generate(7, (col) {
              final index = row * 7 + col;
              final dayNum = index - leading + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 54));
              }
              final date = DateTime(_month.year, _month.month, dayNum);
              return Expanded(child: _DayCell(date: date, parent: widget));
            }),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: const [
            _LegendDot(color: NestColors.dustyRose, label: '수업'),
            _LegendDot(color: NestColors.clay, label: '학사'),
            _LegendDot(color: NestColors.mutedSage, label: '개인'),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.date, required this.parent});

  final DateTime date;
  final TermCalendarView parent;

  @override
  Widget build(BuildContext context) {
    final academic = academicEventsOnDate(
      events: parent.academicEvents,
      date: date,
    );
    final personal = personalEventsOnDate(
      events: parent.personalEvents,
      date: date,
      childId: parent.childId,
    );
    final classes = parent.classesOnDate(date);
    final inTerm = _inTerm(date, parent.termStart, parent.termEnd);
    final today = DateUtils.isSameDay(date, DateTime.now());

    return NestPressable(
      onPressed: () => _openDay(context, classes, academic, personal),
      child: Container(
        height: 54,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: today
              ? NestColors.roseMist.withValues(alpha: 0.55)
              : inTerm
              ? Colors.white
              : NestColors.creamyWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: today ? NestColors.dustyRose : NestColors.roseMist,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: inTerm
                    ? NestColors.deepWood
                    : NestColors.deepWood.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (classes.any((row) => !row.isCanceled))
                  _dot(NestColors.dustyRose),
                if (academic.isNotEmpty) _dot(NestColors.clay),
                if (personal.isNotEmpty) _dot(NestColors.mutedSage),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDay(
    BuildContext context,
    List<ResolvedOccurrence> classes,
    List<AcademicEvent> academic,
    List<PersonalEvent> personal,
  ) {
    showNestSheet<void>(
      context: context,
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('M월 d일 (E)', 'ko').format(date),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (academic.isEmpty && classes.isEmpty && personal.isEmpty)
                  const Text('이 날에는 아직 일정이 없습니다.'),
                ...academic.map(
                  (event) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.flag_outlined, color: NestColors.clay),
                    title: Text(event.title),
                    subtitle: Text(
                      [
                        academicKindLabel(event.kind),
                        if (!event.isAllDay)
                          '${event.startTime} – ${event.endTime ?? ''}',
                      ].join(' · '),
                    ),
                    onTap: parent.onOpenAcademic == null
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            parent.onOpenAcademic!(event);
                          },
                  ),
                ),
                ...classes.map((row) {
                  final hidden = personalHidesClass(
                    events: personal,
                    date: date,
                    slot: row.slot,
                  );
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      row.isCanceled
                          ? Icons.event_busy_outlined
                          : Icons.school_outlined,
                      color: NestColors.dustyRose,
                    ),
                    title: Text(
                      parent.courseNameOf(row.session.courseId),
                      style: hidden
                          ? const TextStyle(
                              decoration: TextDecoration.lineThrough,
                            )
                          : null,
                    ),
                    subtitle: Text(
                      '${row.slot.startTime.substring(0, 5)} – '
                      '${row.slot.endTime.substring(0, 5)}'
                      '${hidden ? ' · 개인 일정 우선' : ''}'
                      '${row.isCanceled ? ' · 휴강' : ''}',
                    ),
                  );
                }),
                ...personal.map(
                  (event) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.person_outline,
                      color: NestColors.mutedSage,
                    ),
                    title: Text(event.title),
                    subtitle: Text(
                      '${DateFormat('HH:mm').format(event.startsAt)} – '
                      '${DateFormat('HH:mm').format(event.endsAt)}'
                      '${event.isFromGoogle ? ' · Google' : ''}',
                    ),
                    onTap: parent.onEditPersonal == null
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            parent.onEditPersonal!(event);
                          },
                  ),
                ),
                if (parent.canAddPersonal && parent.onAddPersonal != null) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        parent.onAddPersonal!(date);
                      },
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('이 날에 개인 일정'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

bool _inTerm(DateTime date, DateTime? start, DateTime? end) {
  if (start == null || end == null) return true;
  final day = nestDateOnly(date);
  return !day.isBefore(nestDateOnly(start)) && !day.isAfter(nestDateOnly(end));
}

Widget _dot(Color color) {
  return Container(
    width: 6,
    height: 6,
    margin: const EdgeInsets.symmetric(horizontal: 1),
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(color),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
