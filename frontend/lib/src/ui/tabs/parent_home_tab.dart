import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../services/schedule_occurrence.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/announcement_attachments.dart';
import '../widgets/homeschool_tips_card.dart';
import '../widgets/nest_3d_icon.dart';
import '../widgets/nest_empty_state.dart';
import '../widgets/nest_motion.dart';
import '../widgets/nest_refresh.dart';
import '../widgets/nest_skeleton.dart';
import '../widgets/portfolio_generation_dialog.dart';
import '../widgets/schedule_personal_section.dart';
import '../widgets/today_personal_events.dart';
import '../widgets/today_schedule_card.dart';
import 'lessons_today_section.dart';
import 'self_study/supervision_schedule_view.dart';

class ParentHomeTab extends StatefulWidget {
  const ParentHomeTab({
    super.key,
    required this.controller,
    required this.selectedChildId,
    required this.childClassBundles,
    required this.isLoadingChildClasses,
    this.onOpenTimetable,
    this.onRefresh,
  });

  final NestController controller;
  final String? selectedChildId;
  final Map<String, ChildClassBundle> childClassBundles;
  final bool isLoadingChildClasses;
  final VoidCallback? onOpenTimetable;
  final Future<void> Function()? onRefresh;

  @override
  State<ParentHomeTab> createState() => _ParentHomeTabState();
}

class _ParentHomeTabState extends State<ParentHomeTab> {
  bool _showAllAnnouncements = false;
  bool _showFullTimetable = false;
  bool _showSchoolSchedule = false;

  String _selectedChildName(NestController controller) {
    final id = widget.selectedChildId;
    if (id == null || id.isEmpty) return '';
    final child = controller.myChildren.where((c) => c.id == id).firstOrNull;
    return (child?.name ?? '').trim();
  }

  String _teacherNameForOccurrence(
    NestController controller,
    Map<String, ChildClassBundle> bundles,
    ResolvedOccurrence row,
  ) {
    for (final bundle in bundles.values) {
      for (final a in bundle.assignments) {
        if (a.classSessionId == row.session.id) {
          final name = controller.findTeacherName(a.teacherProfileId).trim();
          if (name.isNotEmpty && name != a.teacherProfileId) return name;
        }
      }
    }
    return '';
  }

  String _lessonLabelForOccurrence(
    NestController controller,
    ResolvedOccurrence row,
  ) {
    final lesson = controller.courseLessonOn(
      courseId: row.session.courseId,
      date: row.date,
    );
    return (lesson?.headline ?? '').trim();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bundles = widget.childClassBundles;
    final hasChild = widget.selectedChildId != null;
    final noEnrollments =
        hasChild && bundles.isEmpty && !widget.isLoadingChildClasses;

    final todaySessions = bundles.values.expand((bundle) => bundle.sessions);
    final occurrences = controller.occurrencesOn(
      DateTime.now(),
      forSessions: todaySessions,
    );
    final childName = _selectedChildName(controller);
    final todayTitle = childName.isEmpty
        ? '내 아이 오늘 수업'
        : '$childName의 오늘 수업';

    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // ── 1순위: 내 아이의 오늘 수업 위젯 (다양한 위젯 스타일 전환 지원) ──
        NestAppear(
          index: 0,
          child: TodayScheduleCard(
            occurrences: occurrences,
            courseNameOf: controller.findCourseName,
            classNameOf: controller.findClassGroupName,
            teacherNameOf: (row) =>
                _teacherNameForOccurrence(controller, bundles, row),
            lessonLabelOf: (row) => _lessonLabelForOccurrence(controller, row),
            titleLabel: todayTitle,
            userId: controller.user?.id,
            enableStyleSwitcher: true,
            isFullTimetableExpanded: _showFullTimetable,
            onToggleFullTimetable: () =>
                setState(() => _showFullTimetable = !_showFullTimetable),
            onOpenTimetable: widget.onOpenTimetable,
          ),
        ),
        const SizedBox(height: 10),

        // ── 추가 클릭 시 펼쳐지는 우리 아이 전체 주간 시간표 및 상세 진도 ──
        if (_showFullTimetable) ...[
          _buildExpandedChildTimetableSection(
            context,
            controller: controller,
            bundles: bundles,
            noEnrollments: noEnrollments,
          ),
          const SizedBox(height: 12),
        ],

        // ── 오늘 아이 개인 일정 (방과후·학원 등 오늘 일정만 간결하게) ──
        if (widget.selectedChildId != null) ...[
          TodayPersonalEvents(
            events: controller.personalEventsOn(
              DateTime.now(),
              childId: widget.selectedChildId,
            ),
            onAdd: () => openPersonalEventForChild(
              context: context,
              controller: controller,
              childId: widget.selectedChildId!,
              sessions: todaySessions,
            ),
            onOpen: (event) => openPersonalEventForChild(
              context: context,
              controller: controller,
              childId: widget.selectedChildId!,
              sessions: todaySessions,
              event: event,
            ),
          ),
          const SizedBox(height: 10),
        ],

        if (noEnrollments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
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
                            '관리자가 반 배정을 완료하면 시간표와 학습 현황을 확인할 수 있습니다.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── 공지 배너 (최근 1건 한 줄 요약) ──
        _buildAnnouncementBanner(controller),

        const SizedBox(height: 12),

        // ── 빠른 액션 및 부수 정보(학사 일정·감독 시간표) 온디맨드 펼침 바 ──
        _buildSecondaryActionsBar(context, controller),

        if (_showSchoolSchedule) ...[
          const SizedBox(height: 12),
          _buildMySupervision(controller),
          _buildHomeschoolSchedule(controller),
          const SizedBox(height: 12),
          const HomeschoolTipsCard(density: HomeschoolTipsDensity.compact),
        ],
      ],
    );

    if (widget.onRefresh == null) return list;
    return NestRefreshable(onRefresh: widget.onRefresh!, child: list);
  }

  Widget _buildExpandedChildTimetableSection(
    BuildContext context, {
    required NestController controller,
    required Map<String, ChildClassBundle> bundles,
    required bool noEnrollments,
  }) {
    final allSessions = bundles.values
        .expand((b) => b.sessions)
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Nest3dIcon.studyBooks(size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '우리 아이 주간 전체 시간표 · 진도',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _showFullTimetable = false),
                  child: const Text('접기'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (widget.isLoadingChildClasses && bundles.isEmpty)
              const NestSkeletonCard(lines: 3)
            else if (allSessions.isEmpty)
              Text(
                '등록된 주간 시간표가 없습니다.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.65),
                ),
              )
            else ...[
              _buildCompactWeeklyByDay(context, controller, allSessions),
              if (!noEnrollments && bundles.isNotEmpty) ...[
                const Divider(height: 24),
                LessonsTodaySection(
                  controller: controller,
                  childId: widget.selectedChildId,
                  bundles: bundles,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactWeeklyByDay(
    BuildContext context,
    NestController controller,
    List<ClassSession> allSessions,
  ) {
    const dayLabels = <int, String>{
      1: '월요일',
      2: '화요일',
      3: '수요일',
      4: '목요일',
      5: '금요일',
      6: '토요일',
      0: '일요일',
    };

    final grouped = <int, List<(ClassSession, TimeSlot)>>{};
    for (final session in allSessions) {
      final slot = controller.findTimeSlot(session.timeSlotId);
      if (slot == null) continue;
      grouped.putIfAbsent(slot.dayOfWeek, () => []).add((session, slot));
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.$2.startTime.compareTo(b.$2.startTime));
    }

    final orderedDays = [1, 2, 3, 4, 5, 6, 0]
        .where((d) => (grouped[d] ?? const []).isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final day in orderedDays)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dayLabels[day] ?? '$day요일',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: NestColors.clay,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final item in grouped[day]!)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: NestColors.creamyWhite,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: NestColors.roseMist),
                        ),
                        child: Text(
                          '${shortTimeLabel(item.$2.startTime)} ${controller.findCourseName(item.$1.courseId)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSecondaryActionsBar(
    BuildContext context,
    NestController controller,
  ) {
    final eventCount = controller.academicEvents.length;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (widget.onOpenTimetable != null)
          OutlinedButton.icon(
            onPressed: widget.onOpenTimetable,
            icon: const Icon(Icons.event_busy_outlined, size: 17),
            label: const Text('결석 신고 · 전체 시간표'),
          ),
        OutlinedButton.icon(
          onPressed: () =>
              setState(() => _showSchoolSchedule = !_showSchoolSchedule),
          icon: Icon(
            _showSchoolSchedule
                ? Icons.expand_less_rounded
                : Icons.event_note_outlined,
            size: 17,
          ),
          label: Text(
            _showSchoolSchedule
                ? '학사 일정 · 내 감독 접기'
                : eventCount > 0
                ? '학사 일정 · 내 감독 보기 ($eventCount)'
                : '학사 일정 · 내 감독 보기',
          ),
        ),
        TextButton.icon(
          onPressed: () {
            showPortfolioGenerationDialog(
              context,
              controller: controller,
              initialChildId: widget.selectedChildId,
            );
          },
          icon: const Nest3dIcon.portfolio(size: 18),
          label: const Text('학기 학습 포트폴리오 (PDF)'),
        ),
      ],
    );
  }

  // ── 내 감독 시간표 ──
  Widget _buildMySupervision(NestController controller) {
    if (controller.selectedSelfStudyPlan == null) {
      return const SizedBox.shrink();
    }
    final withDuty = controller.currentUserTeacherProfiles
        .where(
          (p) =>
              controller.selfStudySlotsForSupervisor(p.id).isNotEmpty ||
              controller.selfStudySupervisionsForTeacher(p.id).isNotEmpty,
        )
        .toList();
    if (withDuty.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.assignment_ind_outlined, color: NestColors.clay),
                  const SizedBox(width: 8),
                  Text(
                    '내 감독 시간표',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '내가 감독하는 공과 자습이에요.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              for (final p in withDuty)
                SupervisionScheduleView(
                  controller: controller,
                  teacherProfileId: p.id,
                  teacherName: p.displayName,
                  showHeader: withDuty.length > 1,
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Announcement banner: latest one + 더 보기 ──

  Widget _buildAnnouncementBanner(NestController controller) {
    final announcements = controller.announcements.toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

    if (announcements.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_showAllAnnouncements) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 20,
                color: NestColors.deepWood.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                '공지사항',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _showAllAnnouncements = false),
                child: const Text('접기'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...announcements.map((a) => _buildAnnouncementCard(a, controller)),
        ],
      );
    }

    final latest = announcements.first;
    final when = latest.createdAt == null
        ? ''
        : DateFormat('MM/dd').format(latest.createdAt!);
    final classGroupName = latest.classGroupId == null
        ? '전체'
        : controller.findClassGroupName(latest.classGroupId!);

    return Card(
      color: NestColors.roseMist.withValues(alpha: 0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _showAllAnnouncements = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              const Nest3dIcon.announcement(size: 28, floating: true),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (latest.body.trim().isNotEmpty)
                      Text(
                        latest.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.65),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  '$classGroupName · $when',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ),
              if (announcements.length > 1) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: NestColors.deepWood.withValues(alpha: 0.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement a, NestController controller) {
    final when = a.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(a.createdAt!);
    final classGroupName = a.classGroupId == null
        ? '전체 공지'
        : controller.findClassGroupName(a.classGroupId!);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (a.pinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.push_pin,
                      size: 14,
                      color: NestColors.dustyRose,
                    ),
                  ),
                Expanded(
                  child: Text(
                    a.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$classGroupName · $when',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.5),
              ),
            ),
            if (a.body.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(a.body, style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (controller.attachmentsForAnnouncement(a.id).isNotEmpty) ...[
              const SizedBox(height: 8),
              AnnouncementAttachmentList(
                attachments: controller.attachmentsForAnnouncement(a.id),
                resolveUrl: controller.mediaPublicUrl,
                downloadBytes: (path) =>
                    controller.downloadMediaBytes(storagePath: path),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Academic schedule ──

  Widget _buildHomeschoolSchedule(NestController controller) {
    final currentTerm = controller.terms
        .where((t) => t.id == controller.selectedTermId)
        .firstOrNull;

    final termLabel = currentTerm != null ? currentTerm.name : '학기 정보 없음';
    final termPeriod =
        currentTerm != null &&
            currentTerm.startDate != null &&
            currentTerm.endDate != null
        ? '${DateFormat('yyyy.MM.dd').format(currentTerm.startDate!)} ~ ${DateFormat('yyyy.MM.dd').format(currentTerm.endDate!)}'
        : '';

    final events = controller.academicEvents.toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 20,
              color: NestColors.deepWood.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 6),
            Text(
              '학사 일정',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (termPeriod.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 26),
            child: Text(
              '$termLabel · $termPeriod',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.55),
              ),
            ),
          ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          const NestEmptyState.with3d(
            illustration: Nest3dIcon.calendar(size: 58, floating: true),
            title: '등록된 학사 일정이 없습니다',
            subtitle: '관리자가 일정을 등록하면 여기서 확인할 수 있습니다.',
          )
        else
          ...events.map((event) {
            final dateLabel = event.endDate != null
                ? '${DateFormat('M/d').format(event.eventDate)} ~ ${DateFormat('M/d').format(event.endDate!)}'
                : DateFormat('M월 d일 (E)', 'ko').format(event.eventDate);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: NestColors.roseMist.withValues(alpha: 0.4),
                      ),
                      child: Center(
                        child: Text(
                          '${event.eventDate.day}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateLabel,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: NestColors.deepWood.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                          ),
                          if (event.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              event.description,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
