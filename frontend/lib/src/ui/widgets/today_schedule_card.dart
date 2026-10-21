import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/nest_cache.dart';
import '../../services/schedule_occurrence.dart';
import '../nest_theme.dart';
import 'nest_3d_icon.dart';
import 'nest_motion.dart';
import 'nest_sheet.dart';

/// 오늘 일정 위젯의 표시 타입.
///
/// 학부모·선생님·학생마다 선호하는 일정 확인 방식이 다르므로 4가지 위젯 스타일을
/// 제공하고, 사용자가 선택한 스타일을 로컬 캐시([NestCache])에 기억한다.
enum TodayWidgetStyle {
  /// 지금/다음 수업 1개를 크게 강조하고 남은 수업을 아래에 요약
  hero('hero', '포커스', '다음 수업을 크게 강조하고 남은 수업을 요약해요', Icons.bolt_rounded),

  /// 하루 전체 수업을 시간순 타임라인으로 표시
  timeline(
    'timeline',
    '타임라인',
    '시간순 세로 흐름으로 오늘 수업·진도·교실을 한눈에 봐요',
    Icons.timeline_rounded,
  ),

  /// 군더더기 없이 시간·과목·장소만 한 줄씩 보여주는 컴팩트 리스트
  compact(
    'compact',
    '심플목록',
    '교시·시간·과목·장소만 간결한 목록으로 빠르게 확인해요',
    Icons.view_headline_rounded,
  ),

  /// 오늘 수업을 하나씩 체크하며 진도·준비물을 챙기는 인터랙티브 위젯
  checklist(
    'checklist',
    '체크카드',
    '오늘 수업을 하나씩 완료 체크하며 진도를 챙겨요',
    Icons.task_alt_rounded,
  );

  const TodayWidgetStyle(this.id, this.label, this.description, this.icon);

  final String id;
  final String label;
  final String description;
  final IconData icon;

  static TodayWidgetStyle fromId(
    String? raw, {
    TodayWidgetStyle fallback = TodayWidgetStyle.hero,
  }) {
    if (raw == null || raw.isEmpty) return fallback;
    for (final style in TodayWidgetStyle.values) {
      if (style.id == raw) return style;
    }
    return fallback;
  }
}

/// 오늘 일정 위젯 (4가지 멀티 스타일 + 전체 시간표 확장 액션 지원).
class TodayScheduleCard extends StatefulWidget {
  const TodayScheduleCard({
    super.key,
    required this.occurrences,
    required this.courseNameOf,
    this.classNameOf,
    this.teacherNameOf,
    this.lessonLabelOf,
    this.now,
    this.onOpenTimetable,
    this.onToggleFullTimetable,
    this.isFullTimetableExpanded = false,
    this.fullTimetableButtonLabel,
    this.emptyLabel = '오늘 남은 수업이 없어요',
    this.titleLabel,
    this.userId,
    this.initialStyle,
    this.enableStyleSwitcher = false,
  });

  final List<ResolvedOccurrence> occurrences;
  final String Function(String courseId) courseNameOf;
  final String Function(String classGroupId)? classNameOf;
  final String Function(ResolvedOccurrence row)? teacherNameOf;
  final String Function(ResolvedOccurrence row)? lessonLabelOf;
  final DateTime? now;
  final VoidCallback? onOpenTimetable;
  final VoidCallback? onToggleFullTimetable;
  final bool isFullTimetableExpanded;
  final String? fullTimetableButtonLabel;
  final String emptyLabel;
  final String? titleLabel;
  final String? userId;
  final TodayWidgetStyle? initialStyle;
  final bool enableStyleSwitcher;

  @override
  State<TodayScheduleCard> createState() => _TodayScheduleCardState();
}

class _TodayScheduleCardState extends State<TodayScheduleCard> {
  late TodayWidgetStyle _style;
  Set<String> _checkedSessionIds = <String>{};

  String _dateKey(DateTime clock) => DateFormat('yyyy-MM-dd').format(clock);

  @override
  void initState() {
    super.initState();
    _style = _resolveInitialStyle();
    _loadChecklist();
  }

  @override
  void didUpdateWidget(covariant TodayScheduleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStyle != widget.initialStyle &&
        widget.initialStyle != null) {
      _style = widget.initialStyle!;
    } else if (oldWidget.userId != widget.userId) {
      _style = _resolveInitialStyle();
    }
  }

  TodayWidgetStyle _resolveInitialStyle() {
    if (widget.initialStyle != null) return widget.initialStyle!;
    final uid = widget.userId;
    if (uid != null && uid.isNotEmpty) {
      final saved = NestCache.loadTodayWidgetStyle(userId: uid);
      if (saved != null) {
        return TodayWidgetStyle.fromId(
          saved,
          fallback: widget.enableStyleSwitcher
              ? TodayWidgetStyle.timeline
              : TodayWidgetStyle.hero,
        );
      }
    }
    return TodayWidgetStyle.hero;
  }

  void _loadChecklist() {
    final clock = widget.now ?? DateTime.now();
    _checkedSessionIds = NestCache.loadTodayChecklist(
      dateKey: _dateKey(clock),
    );
  }

  void _selectStyle(TodayWidgetStyle next) {
    if (_style == next) return;
    setState(() => _style = next);
    final uid = widget.userId;
    if (uid != null && uid.isNotEmpty) {
      unawaited(NestCache.saveTodayWidgetStyle(userId: uid, style: next.id));
    }
  }

  void _toggleChecked(String sessionKey) {
    final clock = widget.now ?? DateTime.now();
    setState(() {
      if (_checkedSessionIds.contains(sessionKey)) {
        _checkedSessionIds.remove(sessionKey);
      } else {
        _checkedSessionIds.add(sessionKey);
      }
    });
    unawaited(
      NestCache.saveTodayChecklist(
        dateKey: _dateKey(clock),
        checkedKeys: _checkedSessionIds,
      ),
    );
  }

  void _openStyleGallerySheet(BuildContext context) {
    showNestSheet<void>(
      context: context,
      builder: (ctx) => NestSheet(
        title: '오늘 일정 위젯 스타일 선택',
        subtitle: '가장 보기 편한 오늘 수업 위젯 모양을 골라보세요.',
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
        ],
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final candidate in TodayWidgetStyle.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    _selectStyle(candidate);
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _style == candidate
                          ? NestColors.roseMist.withValues(alpha: 0.55)
                          : NestColors.creamyWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _style == candidate
                            ? NestColors.clay
                            : NestColors.roseMist,
                        width: _style == candidate ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _style == candidate
                                ? NestColors.dustyRose.withValues(alpha: 0.45)
                                : NestColors.roseMist.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            candidate.icon,
                            size: 20,
                            color: NestColors.deepWood,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${candidate.label} 위젯',
                                style: Theme.of(ctx).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                candidate.description,
                                style: Theme.of(ctx).textTheme.bodySmall
                                    ?.copyWith(
                                      color: NestColors.deepWood.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _style == candidate
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: _style == candidate
                              ? NestColors.clay
                              : NestColors.deepWood.withValues(alpha: 0.35),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final clock = widget.now ?? DateTime.now();
    final nowMinutes = clock.hour * 60 + clock.minute;

    // 오늘 날짜의 모든 유효 수업 (시간순)
    final todayAll = widget.occurrences
        .where((row) => !row.isCanceled)
        .where((row) => nestDateOnly(row.date) == nestDateOnly(clock))
        .toList()
      ..sort(
        (a, b) => nestMinutesFromTime(
          a.slot.startTime,
        ).compareTo(nestMinutesFromTime(b.slot.startTime)),
      );

    // 아직 끝나지 않은 오늘 남은 수업
    final remaining = todayAll
        .where((row) => nestMinutesFromTime(row.slot.endTime) > nowMinutes)
        .toList();

    // 기본(레거시 호환) 모드: 스타일 스위처가 꺼져 있고 initialStyle도 지정되지 않은 경우
    if (!widget.enableStyleSwitcher && widget.initialStyle == null) {
      return _buildLegacyHeroCard(context, remaining);
    }

    return Card(
      color: NestColors.roseMist.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWidgetHeader(context, todayAll.length, remaining.length),
            if (widget.enableStyleSwitcher) ...[
              const SizedBox(height: 10),
              _buildStyleSwitcherRow(context),
            ],
            const SizedBox(height: 12),
            if (todayAll.isEmpty)
              _buildEmptyBody(context)
            else
              switch (_style) {
                TodayWidgetStyle.hero => _buildHeroBody(
                  context,
                  todayAll: todayAll,
                  remaining: remaining,
                  nowMinutes: nowMinutes,
                ),
                TodayWidgetStyle.timeline => _buildTimelineBody(
                  context,
                  todayAll: todayAll,
                  nowMinutes: nowMinutes,
                ),
                TodayWidgetStyle.compact => _buildCompactBody(
                  context,
                  todayAll: todayAll,
                  nowMinutes: nowMinutes,
                ),
                TodayWidgetStyle.checklist => _buildChecklistBody(
                  context,
                  todayAll: todayAll,
                  nowMinutes: nowMinutes,
                ),
              },
            if (widget.onToggleFullTimetable != null ||
                widget.onOpenTimetable != null) ...[
              const SizedBox(height: 12),
              _buildFooterActions(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLegacyHeroCard(
    BuildContext context,
    List<ResolvedOccurrence> remaining,
  ) {
    final next = remaining.isEmpty ? null : remaining.first;
    final rest = remaining.length > 1
        ? remaining.sublist(1)
        : const <ResolvedOccurrence>[];

    return NestPressable(
      enabled: widget.onOpenTimetable != null,
      onPressed: widget.onOpenTimetable,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        color: NestColors.roseMist.withValues(alpha: 0.35),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: next == null
              ? _buildEmptyBody(context)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '다음 수업',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.clay,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.courseNameOf(next.session.courseId),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _detailLine(next),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.72),
                      ),
                    ),
                    if (rest.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        '오늘 남은 수업 ${rest.length}개',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: NestColors.deepWood.withValues(alpha: 0.62),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...rest.take(3).map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '${shortTimeLabel(row.slot.startTime)}  ${widget.courseNameOf(row.session.courseId)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildWidgetHeader(
    BuildContext context,
    int totalCount,
    int remainingCount,
  ) {
    final clock = widget.now ?? DateTime.now();
    final dateText = DateFormat('M월 d일 (E)', 'ko').format(clock);
    final title = widget.titleLabel ?? '오늘의 수업';

    return Row(
      children: [
        const Nest3dIcon.calendar(size: 28, floating: true),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: NestColors.dustyRose.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      totalCount == 0 ? '휴강·없음' : '오늘 $totalCount교시',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: NestColors.deepWood,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                totalCount == 0
                    ? '$dateText · 예정된 수업이 없습니다'
                    : '$dateText · 남은 수업 $remainingCount개',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
        if (widget.enableStyleSwitcher)
          IconButton(
            tooltip: '위젯 스타일 안내',
            visualDensity: VisualDensity.compact,
            onPressed: () => _openStyleGallerySheet(context),
            icon: Icon(
              Icons.dashboard_customize_outlined,
              size: 20,
              color: NestColors.deepWood.withValues(alpha: 0.7),
            ),
          ),
      ],
    );
  }

  Widget _buildStyleSwitcherRow(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final candidate in TodayWidgetStyle.values)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                avatar: Icon(
                  candidate.icon,
                  size: 15,
                  color: _style == candidate
                      ? NestColors.deepWood
                      : NestColors.deepWood.withValues(alpha: 0.6),
                ),
                label: Text(candidate.label),
                selected: _style == candidate,
                selectedColor: NestColors.dustyRose.withValues(alpha: 0.55),
                backgroundColor: NestColors.creamyWhite.withValues(alpha: 0.8),
                labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: _style == candidate
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: NestColors.deepWood,
                ),
                onSelected: (_) => _selectStyle(candidate),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyBody(BuildContext context) {
    return Row(
      children: [
        const Nest3dIcon.studyBooks(size: 28, floating: true),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            widget.emptyLabel,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        if (widget.onOpenTimetable != null &&
            widget.onToggleFullTimetable == null)
          Icon(
            Icons.chevron_right,
            color: NestColors.deepWood.withValues(alpha: 0.45),
          ),
      ],
    );
  }

  Widget _buildHeroBody(
    BuildContext context, {
    required List<ResolvedOccurrence> todayAll,
    required List<ResolvedOccurrence> remaining,
    required int nowMinutes,
  }) {
    final next = remaining.isEmpty ? todayAll.last : remaining.first;
    final isAllDone = remaining.isEmpty;
    final isOngoing =
        !isAllDone &&
        nestMinutesFromTime(next.slot.startTime) <= nowMinutes &&
        nestMinutesFromTime(next.slot.endTime) > nowMinutes;
    final rest = remaining.length > 1
        ? remaining.sublist(1)
        : const <ResolvedOccurrence>[];
    final lessonLabel = widget.lessonLabelOf?.call(next) ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NestColors.creamyWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: NestColors.dustyRose.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isAllDone
                          ? NestColors.mutedSage.withValues(alpha: 0.25)
                          : isOngoing
                          ? NestColors.dustyRose.withValues(alpha: 0.6)
                          : NestColors.roseMist,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isAllDone
                          ? '오늘 수업 완료'
                          : isOngoing
                          ? '지금 수업 중'
                          : '다음 수업',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: NestColors.deepWood,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!isAllDone && !isOngoing) ...[
                    const SizedBox(width: 8),
                    Text(
                      '다음 수업',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.clay,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.courseNameOf(next.session.courseId),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _detailLine(next),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.74),
                ),
              ),
              if (lessonLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 15,
                      color: NestColors.clay,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        lessonLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            '오늘 남은 수업 ${rest.length}개',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: NestColors.deepWood.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 6),
          ...rest.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Text(
                    '${shortTimeLabel(row.slot.startTime)}  ${widget.courseNameOf(row.session.courseId)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (row.location.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '· ${row.location}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTimelineBody(
    BuildContext context, {
    required List<ResolvedOccurrence> todayAll,
    required int nowMinutes,
  }) {
    return Column(
      children: [
        for (var i = 0; i < todayAll.length; i++)
          _buildTimelineRow(
            context,
            row: todayAll[i],
            isLast: i == todayAll.length - 1,
            nowMinutes: nowMinutes,
          ),
      ],
    );
  }

  Widget _buildTimelineRow(
    BuildContext context, {
    required ResolvedOccurrence row,
    required bool isLast,
    required int nowMinutes,
  }) {
    final startMin = nestMinutesFromTime(row.slot.startTime);
    final endMin = nestMinutesFromTime(row.slot.endTime);
    final isDone = endMin <= nowMinutes;
    final isOngoing = startMin <= nowMinutes && endMin > nowMinutes;
    final courseName = widget.courseNameOf(row.session.courseId);
    final className = widget.classNameOf?.call(row.session.classGroupId) ?? '';
    final teacherName = widget.teacherNameOf?.call(row) ?? '';
    final lessonLabel = widget.lessonLabelOf?.call(row) ?? '';

    final metaParts = <String>[
      if (className.isNotEmpty) className,
      if (row.location.isNotEmpty) row.location,
      if (teacherName.isNotEmpty) '$teacherName 선생님',
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 52,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shortTimeLabel(row.slot.startTime),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isDone
                          ? NestColors.deepWood.withValues(alpha: 0.45)
                          : NestColors.deepWood,
                    ),
                  ),
                  Text(
                    shortTimeLabel(row.slot.endTime),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOngoing
                      ? NestColors.clay
                      : isDone
                      ? NestColors.mutedSage
                      : NestColors.dustyRose,
                  border: Border.all(color: NestColors.creamyWhite, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: NestColors.roseMist,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isOngoing
                      ? NestColors.creamyWhite
                      : NestColors.creamyWhite.withValues(
                          alpha: isDone ? 0.55 : 0.88,
                        ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOngoing ? NestColors.clay : NestColors.roseMist,
                    width: isOngoing ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            courseName,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  decoration: isDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isDone
                                      ? NestColors.deepWood.withValues(
                                          alpha: 0.55,
                                        )
                                      : NestColors.deepWood,
                                ),
                          ),
                        ),
                        if (isOngoing)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: NestColors.dustyRose.withValues(
                                alpha: 0.5,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '수업 중',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                      ],
                    ),
                    if (metaParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        metaParts.join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                    if (lessonLabel.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '진도: $lessonLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.clay,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBody(
    BuildContext context, {
    required List<ResolvedOccurrence> todayAll,
    required int nowMinutes,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: NestColors.creamyWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        children: [
          for (var i = 0; i < todayAll.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: NestColors.roseMist.withValues(alpha: 0.7),
              ),
            _buildCompactRow(
              context,
              index: i + 1,
              row: todayAll[i],
              nowMinutes: nowMinutes,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactRow(
    BuildContext context, {
    required int index,
    required ResolvedOccurrence row,
    required int nowMinutes,
  }) {
    final endMin = nestMinutesFromTime(row.slot.endTime);
    final isDone = endMin <= nowMinutes;
    final courseName = widget.courseNameOf(row.session.courseId);
    final className = widget.classNameOf?.call(row.session.classGroupId) ?? '';
    final rightLabel = [
      if (className.isNotEmpty) className,
      if (row.location.isNotEmpty) row.location,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isDone
                  ? NestColors.roseMist.withValues(alpha: 0.5)
                  : NestColors.roseMist,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$index',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: NestColors.deepWood,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${shortTimeLabel(row.slot.startTime)}–${shortTimeLabel(row.slot.endTime)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: NestColors.deepWood.withValues(alpha: isDone ? 0.45 : 0.8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              courseName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: NestColors.deepWood.withValues(alpha: isDone ? 0.5 : 1),
              ),
            ),
          ),
          if (rightLabel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                rightLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistBody(
    BuildContext context, {
    required List<ResolvedOccurrence> todayAll,
    required int nowMinutes,
  }) {
    final completedCount = todayAll
        .where((row) => _checkedSessionIds.contains(_sessionKey(row)))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Nest3dIcon.checkStamp(size: 20),
            const SizedBox(width: 6),
            Text(
              '수업 체크 완료 $completedCount / ${todayAll.length}',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Text(
              '터치해서 완료 표시',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final row in todayAll)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildChecklistItem(context, row),
          ),
      ],
    );
  }

  Widget _buildChecklistItem(BuildContext context, ResolvedOccurrence row) {
    final key = _sessionKey(row);
    final checked = _checkedSessionIds.contains(key);
    final courseName = widget.courseNameOf(row.session.courseId);
    final lessonLabel = widget.lessonLabelOf?.call(row) ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _toggleChecked(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: checked
              ? NestColors.mutedSage.withValues(alpha: 0.18)
              : NestColors.creamyWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: checked ? NestColors.mutedSage : NestColors.roseMist,
          ),
        ),
        child: Row(
          children: [
            Icon(
              checked
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: checked
                  ? NestColors.mutedSage
                  : NestColors.deepWood.withValues(alpha: 0.45),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      decoration: checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    lessonLabel.isNotEmpty
                        ? '${_detailLine(row)} · $lessonLabel'
                        : _detailLine(row),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterActions(BuildContext context) {
    final primaryAction =
        widget.onToggleFullTimetable ?? widget.onOpenTimetable;
    final label =
        widget.fullTimetableButtonLabel ??
        (widget.isFullTimetableExpanded ? '전체 시간표 접기' : '전체 시간표 보기');

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (primaryAction != null)
          FilledButton.tonalIcon(
            onPressed: primaryAction,
            icon: Icon(
              widget.isFullTimetableExpanded
                  ? Icons.expand_less_rounded
                  : Icons.calendar_view_week_rounded,
              size: 18,
            ),
            label: Text(label),
          ),
        if (widget.onToggleFullTimetable != null &&
            widget.onOpenTimetable != null)
          TextButton.icon(
            onPressed: widget.onOpenTimetable,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('시간표 탭 열기'),
          ),
      ],
    );
  }

  String _sessionKey(ResolvedOccurrence row) {
    if (row.session.id.isNotEmpty) return row.session.id;
    return '${row.slot.id}_${row.session.courseId}';
  }

  String _detailLine(ResolvedOccurrence row) {
    final time =
        '${shortTimeLabel(row.slot.startTime)}–${shortTimeLabel(row.slot.endTime)}';
    final className = widget.classNameOf?.call(row.session.classGroupId) ?? '';
    final teacherName = widget.teacherNameOf?.call(row) ?? '';
    final parts = <String>[
      time,
      if (className.isNotEmpty) className,
      if (row.location.isNotEmpty) row.location,
      if (teacherName.isNotEmpty) '$teacherName 선생님',
    ];
    return parts.join(' · ');
  }
}
