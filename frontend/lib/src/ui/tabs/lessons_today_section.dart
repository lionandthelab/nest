import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/schedule_badges.dart';
import 'timetable/course_lesson_sheet.dart';

/// 학부모·학생 홈에 올리는 "오늘의 수업" 섹션.
///
/// 회차 내용(진도표)은 지금까지 시간표 탭의 작은 셀을 눌러야만 보였다. 모바일에서
/// 가로로 스크롤되는 격자의 한 칸을 정확히 누르는 건 어렵고, 홈에서는 수업이 무엇을
/// 하는지 아예 알 수 없었다. 그래서 홈에 카드 목록으로 올린다 — 큰 탭 영역,
/// 세로 스크롤, 그 날 진도가 카드 안에 바로 보인다.
///
/// 오늘 수업이 없으면 **다음 수업일**로 넘어간다. 방학·개학 전에는 "오늘은 수업이
/// 없어요" 한 줄만 남아 화면이 비어 버리는데, 그때 정작 알고 싶은 건 다음 수업이다.
class LessonsTodaySection extends StatelessWidget {
  const LessonsTodaySection({
    super.key,
    required this.controller,
    required this.childId,
    required this.bundles,
  });

  final NestController controller;

  /// 결석 배지를 이 아이 기준으로만 표시하기 위해 필요하다(같은 반 형제 오탐 방지).
  final String? childId;

  final Map<String, ChildClassBundle> bundles;

  /// 오늘 이후로 수업이 있는 날을 찾을 때 며칠까지 앞을 보는지.
  /// 학기 시작 전(방학)에도 첫 수업일을 찾을 수 있을 만큼 넉넉해야 한다.
  static const int _lookaheadDays = 60;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveDay();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.auto_stories_outlined,
              size: 20,
              color: NestColors.deepWood.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                resolved.isToday ? '오늘의 수업' : '다음 수업',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (resolved.date != null)
              Text(
                _dayLabel(resolved.date!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NestColors.clay,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (resolved.rows.isEmpty)
          _quietCard(
            context,
            bundles.isEmpty
                ? '반이 배정되면 수업과 진도를 여기서 볼 수 있어요.'
                : '앞으로 예정된 수업이 없어요.',
          )
        else
          ...resolved.rows.map(
            (row) => _LessonSessionCard(
              controller: controller,
              row: row,
              date: resolved.date!,
              childId: childId,
            ),
          ),
      ],
    );
  }

  /// 보여줄 날짜와 그 날의 수업을 정한다.
  _ResolvedDay _resolveDay() {
    final today = _dateOnly(DateTime.now());
    final termStart = controller.selectedTerm?.startDate;
    final termEnd = controller.selectedTerm?.endDate;

    // 학기 시작 전이면 학기 첫날부터 찾는다(방학 중에도 개강 수업이 보이게).
    var cursor = today;
    if (termStart != null) {
      final start = _dateOnly(termStart);
      if (cursor.isBefore(start)) {
        cursor = start;
      }
    }

    final end = termEnd == null ? null : _dateOnly(termEnd);
    for (var i = 0; i <= _lookaheadDays; i++) {
      if (end != null && cursor.isAfter(end)) {
        break;
      }
      final rows = _rowsOn(cursor);
      if (rows.isNotEmpty) {
        return _ResolvedDay(
          date: cursor,
          rows: rows,
          isToday: cursor == today,
        );
      }
      cursor = _dateOnly(cursor.add(const Duration(days: 1)));
    }
    return const _ResolvedDay(date: null, rows: [], isToday: true);
  }

  List<_LessonRow> _rowsOn(DateTime date) {
    final day = date.weekday % 7; // 앱 규약: 0 = 일요일
    final rows = <_LessonRow>[];
    for (final bundle in bundles.values) {
      for (final session in bundle.sessions) {
        final baseSlot = controller.findTimeSlot(session.timeSlotId);
        if (baseSlot == null) {
          continue;
        }
        final change = controller.effectiveChangeFor(
          sessionId: session.id,
          date: date,
        );
        // ⚠️ 시간 변경(TIME_MOVED)은 요일까지 바뀔 수 있다. 원래 교시로 판단하면
        // 옮기기 전 요일에 수업이 있다고 알려주고(=엉뚱한 시각에 데려온다),
        // 옮겨간 요일에는 아예 안 보인다. 판단·정렬·표시 모두 옮겨간 교시로 한다.
        final movedSlot =
            change != null &&
                change.changeType == 'TIME_MOVED' &&
                (change.newTimeSlotId ?? '').isNotEmpty
            ? controller.findTimeSlot(change.newTimeSlotId!)
            : null;
        final slot = movedSlot ?? baseSlot;
        if (slot.dayOfWeek != day) {
          continue;
        }
        rows.add(
          _LessonRow(
            className: bundle.classGroup.name,
            session: session,
            slot: slot,
            change: change,
            isTimeMoved: movedSlot != null,
          ),
        );
      }
    }
    rows.sort((a, b) => a.slot.startTime.compareTo(b.slot.startTime));
    return rows;
  }
}

class _ResolvedDay {
  const _ResolvedDay({
    required this.date,
    required this.rows,
    required this.isToday,
  });

  final DateTime? date;
  final List<_LessonRow> rows;
  final bool isToday;
}

class _LessonRow {
  const _LessonRow({
    required this.className,
    required this.session,
    required this.slot,
    required this.change,
    required this.isTimeMoved,
  });

  final String className;
  final ClassSession session;

  /// 실제로 적용되는 교시. 시간 변경이 걸렸으면 옮겨간 교시다.
  final TimeSlot slot;

  final ClassSessionChange? change;

  /// [slot] 이 변경으로 옮겨온 교시인지(문구에 "변경됨"을 덧붙이기 위함).
  final bool isTimeMoved;
}

/// 수업 한 칸 카드. 카드 전체가 탭 영역이고, 누르면 그 과목의 진도표가 열린다.
class _LessonSessionCard extends StatelessWidget {
  const _LessonSessionCard({
    required this.controller,
    required this.row,
    required this.date,
    required this.childId,
  });

  final NestController controller;
  final _LessonRow row;
  final DateTime date;
  final String? childId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final courseName = controller.findCourseName(row.session.courseId);
    // row.slot 은 이미 "실제로 적용되는 교시"다(시간 변경이면 옮겨간 교시).
    final timeLabel =
        '${_shortTime(row.slot.startTime)} - ${_shortTime(row.slot.endTime)}'
        '${row.isTimeMoved ? ' (변경됨)' : ''}';
    final change = row.change;
    final absence = childId == null
        ? null
        : controller.absenceFor(
            sessionId: row.session.id,
            date: date,
            childId: childId!,
          );
    final canceled = change?.changeType == 'CANCELED';
    final location = (row.session.location ?? '').trim();
    final resolvedLocation =
        change != null && change.newLocation.trim().isNotEmpty
        ? change.newLocation.trim()
        : location;
    final lesson = controller.courseLessonOn(
      courseId: row.session.courseId,
      date: date,
    );
    final changeDetail = _changeDetail(controller, change, row);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showCourseLessonSheet(
          context: context,
          controller: controller,
          courseId: row.session.courseId,
          // 카드가 가리키는 그 날짜의 회차로 바로 스크롤한다.
          focusDate: date,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: NestColors.mutedSage.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _shortTime(row.slot.startTime),
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
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          courseName,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            decoration: canceled
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (change != null)
                          StudentChangeBadge(label: change.changeTypeLabel),
                        if (absence != null) const StudentAbsenceBadge(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      resolvedLocation.isEmpty
                          ? '${row.className} · $timeLabel'
                          : '${row.className} · $timeLabel · $resolvedLocation',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.6),
                      ),
                    ),
                    // 변경 상세. 배지만으로는 "무엇이 어떻게 바뀌었는지"를 알 수 없다.
                    // 특히 보강 교사는 여기 없으면 학부모가 볼 곳이 아예 없다
                    // (학부모 홈에는 수업 변경 안내 섹션이 따로 없다).
                    if (changeDetail.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        changeDetail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: NestColors.clay,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (change != null && change.reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        change.reason.trim(),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    // 그 날의 진도. 휴강이면 내용을 보여줄 이유가 없다.
                    if (!canceled) ...[
                      const SizedBox(height: 8),
                      _LessonContentStrip(lesson: lesson),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: NestColors.deepWood.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카드 안에 들어가는 그 날 진도 한 덩어리. 없으면 안내 한 줄.
class _LessonContentStrip extends StatelessWidget {
  const _LessonContentStrip({required this.lesson});

  final CourseLesson? lesson;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = lesson;

    if (row == null || row.isBlank) {
      return Text(
        '수업 내용 미등록',
        style: theme.textTheme.bodySmall?.copyWith(
          color: NestColors.deepWood.withValues(alpha: 0.45),
        ),
      );
    }

    final headline = row.headline;
    final presenter = row.presenter.trim();
    final content = row.content.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: NestColors.roseMist.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (headline.isNotEmpty)
            Text(
              headline,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          if (presenter.isNotEmpty) ...[
            if (headline.isNotEmpty) const SizedBox(height: 2),
            Text(
              '담당 $presenter',
              style: theme.textTheme.bodySmall?.copyWith(
                color: NestColors.clay,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (content.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 변경 배지 옆에 붙일 "무엇이 어떻게 바뀌었는지" 한 줄.
///
/// 시간 변경은 이미 카드의 시각 칩과 "(변경됨)" 표기로 드러나므로 여기서는
/// 요일까지 옮겨간 경우에만 덧붙인다. 보강 교사는 다른 데서 볼 곳이 없어 항상 쓴다.
String _changeDetail(
  NestController controller,
  ClassSessionChange? change,
  _LessonRow row,
) {
  if (change == null) {
    return '';
  }
  switch (change.changeType) {
    case 'TEACHER_SUBSTITUTE':
      final teacherId = change.substituteTeacherId;
      if (teacherId == null || teacherId.isEmpty) {
        return '';
      }
      final name = controller.findTeacherName(teacherId).trim();
      return name.isEmpty ? '' : '보강 교사 · $name';
    case 'TIME_MOVED':
      if (!row.isTimeMoved) {
        return '';
      }
      return '변경 시간 · ${_weekdayLabel(row.slot.dayOfWeek)} '
          '${_shortTime(row.slot.startTime)} - ${_shortTime(row.slot.endTime)}';
    default:
      return '';
  }
}

/// 앱 규약(0=일) 요일 라벨.
String _weekdayLabel(int dayOfWeek) {
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

Widget _quietCard(BuildContext context, String message) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: NestColors.deepWood.withValues(alpha: 0.7),
        ),
      ),
    ),
  );
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _dayLabel(DateTime date) =>
    DateFormat('M월 d일 (E)', 'ko').format(date);

String _shortTime(String value) {
  final parts = value.trim().split(':');
  if (parts.length < 2) {
    return value;
  }
  return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
}
