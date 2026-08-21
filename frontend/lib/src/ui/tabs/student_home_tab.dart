import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/nest_empty_state.dart';
import '../widgets/nest_skeleton.dart';

/// 학생 본인 계정의 홈 탭.
///
/// ParentHomeTab 과 같은 데이터(반 번들 / 공지 / 학사 일정)를 쓰되, 화면의
/// 주어를 "우리 아이"가 아니라 "나(학생)"로 바꿨다. 계정이 아직 어떤 아이와도
/// 연결되지 않았을 수 있으므로, 그 경우에도 빈 화면이나 예외 없이 안내를
/// 보여주는 것이 이 탭의 가장 중요한 요구사항이다.
class StudentHomeTab extends StatefulWidget {
  const StudentHomeTab({
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
  State<StudentHomeTab> createState() => _StudentHomeTabState();
}

class _StudentHomeTabState extends State<StudentHomeTab> {
  bool _showAllAnnouncements = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    // 화면의 주인공 아이. home_page 가 넘겨준 값을 우선하고, 없으면 컨트롤러가
    // 해석한 값(관리자 미리보기 포함)을 쓴다.
    final childId = _resolveChildId(controller);

    // 계정이 아직 어떤 학생 정보와도 연결되지 않은 상태.
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

    final child = _findChild(controller, childId);
    final bundles = widget.childClassBundles;

    if (widget.isLoadingChildClasses && bundles.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: const [
          NestSkeletonCard(lines: 2),
          SizedBox(height: 10),
          NestSkeletonCard(lines: 3),
          SizedBox(height: 10),
          NestSkeletonCard(lines: 3),
        ],
      );
    }

    final noEnrollments = bundles.isEmpty;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildGreeting(context, child),
        const SizedBox(height: 12),
        if (noEnrollments) ...[
          _buildNoticeCard(
            context,
            title: '반 배정 대기 중',
            body: '아직 반에 배정되지 않았어요. '
                '관리 선생님이 반 배정을 마치면 시간표를 확인할 수 있습니다.',
          ),
          const SizedBox(height: 12),
        ],
        _buildAnnouncementBanner(controller),
        const SizedBox(height: 16),
        if (!noEnrollments) ...[
          _buildTodayClasses(context, controller, childId, bundles),
          const SizedBox(height: 16),
          _buildUpcomingChanges(context, controller, bundles),
          const SizedBox(height: 16),
        ],
        _buildMyAbsences(context, controller, childId, bundles),
        const SizedBox(height: 16),
        _buildHomeschoolSchedule(context, controller),
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

  ChildProfile? _findChild(NestController controller, String childId) {
    return controller.children.where((row) => row.id == childId).firstOrNull ??
        controller.activeStudentChild;
  }

  /// 번들 → 컨트롤러 순으로 세션을 찾는다(번들에 없는 과거 신고 대비).
  ClassSession? _findSession(
    NestController controller,
    Map<String, ChildClassBundle> bundles,
    String sessionId,
  ) {
    for (final bundle in bundles.values) {
      for (final session in bundle.sessions) {
        if (session.id == sessionId) return session;
      }
    }
    return controller.allTermSessions
            .where((row) => row.id == sessionId)
            .firstOrNull ??
        controller.sessions.where((row) => row.id == sessionId).firstOrNull;
  }

  String _courseNameForSession(
    NestController controller,
    Map<String, ChildClassBundle> bundles,
    String sessionId,
  ) {
    final session = _findSession(controller, bundles, sessionId);
    if (session == null) return '수업';
    return controller.findCourseName(session.courseId);
  }

  /// 앱 요일 규약(0=일 .. 6=토).
  int _appDay(DateTime date) => date.weekday % 7;

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  // ── 인사말 ──

  Widget _buildGreeting(BuildContext context, ChildProfile? child) {
    final name = (child?.name ?? '').trim();
    final greeting = name.isEmpty ? '안녕하세요' : '$name 학생, 안녕하세요';
    final todayLabel = DateFormat('M월 d일 (E)', 'ko').format(DateTime.now());

    return Card(
      color: NestColors.roseMist.withValues(alpha: 0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: NestColors.dustyRose.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.waving_hand_outlined,
                  color: NestColors.deepWood.withValues(alpha: 0.75)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    greeting,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '오늘은 $todayLabel이에요.',
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

  Widget _buildNoticeCard(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return Card(
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
                    title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 오늘의 수업 ──

  Widget _buildTodayClasses(
    BuildContext context,
    NestController controller,
    String childId,
    Map<String, ChildClassBundle> bundles,
  ) {
    final today = _today();
    final todayDay = _appDay(today);

    final rows = <_StudentSessionRow>[];
    var weeklyCount = 0;
    for (final bundle in bundles.values) {
      for (final session in bundle.sessions) {
        final slot = controller.findTimeSlot(session.timeSlotId);
        if (slot == null) continue;
        weeklyCount += 1;
        if (slot.dayOfWeek != todayDay) continue;
        rows.add(
          _StudentSessionRow(
            className: bundle.classGroup.name,
            session: session,
            slot: slot,
          ),
        );
      }
    }
    rows.sort((a, b) => a.slot.startTime.compareTo(b.slot.startTime));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          icon: Icons.today_outlined,
          title: '오늘의 수업',
          trailing: '이번 주 수업 $weeklyCount개',
        ),
        const SizedBox(height: 10),
        if (rows.isEmpty)
          _buildQuietCard(context, '오늘은 수업이 없어요.')
        else
          ...rows.map(
            (row) => _buildSessionCard(context, controller, childId, row, today),
          ),
      ],
    );
  }

  Widget _buildSessionCard(
    BuildContext context,
    NestController controller,
    String childId,
    _StudentSessionRow row,
    DateTime date,
  ) {
    final courseName = controller.findCourseName(row.session.courseId);
    final timeLabel =
        '${_shortTime(row.slot.startTime)} - ${_shortTime(row.slot.endTime)}';
    final change = controller.effectiveChangeFor(
      sessionId: row.session.id,
      date: date,
    );
    // 같은 반에 형제가 있을 수 있으므로 반드시 이 아이의 신고만 본다.
    final absence = controller.absenceFor(
      sessionId: row.session.id,
      date: date,
      childId: childId,
    );
    final location = (row.session.location ?? '').trim();
    final resolvedLocation = change != null && change.newLocation.trim().isNotEmpty
        ? change.newLocation.trim()
        : location;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          courseName,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                decoration: change?.changeType == 'CANCELED'
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                        ),
                      ),
                      if (change != null) ...[
                        const SizedBox(width: 6),
                        StudentChangeBadge(label: change.changeTypeLabel),
                      ],
                      if (absence != null) ...[
                        const SizedBox(width: 6),
                        const StudentAbsenceBadge(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    resolvedLocation.isEmpty
                        ? '${row.className} · $timeLabel'
                        : '${row.className} · $timeLabel · $resolvedLocation',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.6),
                        ),
                  ),
                  if (change != null && change.reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      change.reason.trim(),
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
  }

  // ── 다가오는 수업 변경 안내 ──

  Widget _buildUpcomingChanges(
    BuildContext context,
    NestController controller,
    Map<String, ChildClassBundle> bundles,
  ) {
    final today = _today();
    final sessionIds = <String>{
      for (final bundle in bundles.values)
        for (final session in bundle.sessions) session.id,
    };

    final changes = <ClassSessionChange>[];
    final seen = <String>{};
    void collect(ClassSessionChange change) {
      if (!sessionIds.contains(change.classSessionId)) return;
      if (!seen.add(change.id)) return;
      final to = change.effectiveTo;
      // 이미 끝난 변경은 숨긴다(종료일 없으면 학기 끝까지 유효).
      if (to != null && DateTime(to.year, to.month, to.day).isBefore(today)) {
        return;
      }
      changes.add(change);
    }

    for (final bundle in bundles.values) {
      bundle.changes.forEach(collect);
    }
    for (final change in controller.classSessionChanges) {
      collect(change);
    }
    changes.sort((a, b) => a.effectiveFrom.compareTo(b.effectiveFrom));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          icon: Icons.campaign_outlined,
          title: '수업 변경 안내',
        ),
        const SizedBox(height: 10),
        if (changes.isEmpty)
          _buildQuietCard(context, '예정된 수업 변경이 없어요.')
        else
          ...changes.map(
            (change) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        StudentChangeBadge(label: change.changeTypeLabel),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _courseNameForSession(
                              controller,
                              bundles,
                              change.classSessionId,
                            ),
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _changePeriodLabel(change),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: NestColors.deepWood.withValues(alpha: 0.6),
                          ),
                    ),
                    if (_changeDetailLabel(controller, change).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        _changeDetailLabel(controller, change),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (change.reason.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        change.reason.trim(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: NestColors.deepWood.withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
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

  String _changeDetailLabel(
    NestController controller,
    ClassSessionChange change,
  ) {
    switch (change.changeType) {
      case 'TIME_MOVED':
        final slotId = change.newTimeSlotId;
        final slot = slotId == null ? null : controller.findTimeSlot(slotId);
        if (slot == null) return '';
        return '변경 시간 · ${_dayLabel(slot.dayOfWeek)} '
            '${_shortTime(slot.startTime)} - ${_shortTime(slot.endTime)}';
      case 'ROOM_MOVED':
        final room = change.newLocation.trim();
        return room.isEmpty ? '' : '변경 장소 · $room';
      case 'TEACHER_SUBSTITUTE':
        final teacherId = change.substituteTeacherId;
        if (teacherId == null || teacherId.isEmpty) return '';
        return '담당 교사 · ${controller.findTeacherName(teacherId)}';
      default:
        return '';
    }
  }

  // ── 내가 신고한 결석 ──

  Widget _buildMyAbsences(
    BuildContext context,
    NestController controller,
    String childId,
    Map<String, ChildClassBundle> bundles,
  ) {
    final reports = controller
        .absencesForChild(childId)
        .where((row) => !row.isCanceled)
        .toList();
    final today = _today();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          icon: Icons.event_busy_outlined,
          title: '내가 신고한 결석',
        ),
        const SizedBox(height: 10),
        if (reports.isEmpty)
          _buildQuietCard(context, '신고한 결석이 없어요.')
        else
          ...reports.map((report) {
            final courseName = _courseNameForSession(
              controller,
              bundles,
              report.classSessionId,
            );
            final dateLabel =
                DateFormat('M월 d일 (E)', 'ko').format(report.occurrenceDate);
            final occurrence = DateTime(
              report.occurrenceDate.year,
              report.occurrenceDate.month,
              report.occurrenceDate.day,
            );
            final canCancel = !occurrence.isBefore(today);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  courseName,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 6),
                              StudentStatusChip(label: report.statusLabel),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: NestColors.deepWood
                                      .withValues(alpha: 0.6),
                                ),
                          ),
                          if (report.reason.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              report.reason.trim(),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (canCancel)
                      TextButton(
                        onPressed: () => _cancelAbsence(report),
                        child: const Text('취소'),
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Future<void> _cancelAbsence(AbsenceReport report) async {
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
    if (mounted) setState(() {});
  }

  // ── 공지 배너 (ParentHomeTab 과 동일한 표현) ──

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
              Icon(Icons.campaign_outlined,
                  size: 20, color: NestColors.deepWood.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text('공지사항',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
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
              Icon(Icons.campaign, size: 20, color: NestColors.dustyRose),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (latest.body.trim().isNotEmpty)
                      Text(
                        latest.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  NestColors.deepWood.withValues(alpha: 0.65),
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$classGroupName · $when',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
              ),
              if (announcements.length > 1) ...[
                const SizedBox(width: 4),
                Icon(Icons.expand_more,
                    size: 18,
                    color: NestColors.deepWood.withValues(alpha: 0.5)),
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
                    child: Icon(Icons.push_pin,
                        size: 14, color: NestColors.dustyRose),
                  ),
                Expanded(
                  child: Text(
                    a.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
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
          ],
        ),
      ),
    );
  }

  // ── 학사 일정 ──

  Widget _buildHomeschoolSchedule(
    BuildContext context,
    NestController controller,
  ) {
    final currentTerm = controller.selectedTerm;
    final termLabel = currentTerm != null ? currentTerm.name : '학기 정보 없음';
    final termPeriod = currentTerm != null &&
            currentTerm.startDate != null &&
            currentTerm.endDate != null
        ? '${DateFormat('yyyy.MM.dd').format(currentTerm.startDate!)} ~ '
            '${DateFormat('yyyy.MM.dd').format(currentTerm.endDate!)}'
        : '';

    final events = controller.academicEvents.toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          context,
          icon: Icons.event_note_outlined,
          title: '학사 일정',
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
          const NestEmptyState(
            icon: Icons.event_note_outlined,
            title: '등록된 학사 일정이 없습니다',
            subtitle: '관리 선생님이 일정을 등록하면 여기서 확인할 수 있습니다.',
          )
        else
          ...events.map((event) {
            final dateLabel = event.endDate != null
                ? '${DateFormat('M/d').format(event.eventDate)} ~ '
                    '${DateFormat('M/d').format(event.endDate!)}'
                : DateFormat('M월 d일 (E)', 'ko').format(event.eventDate);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
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
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: NestColors.deepWood
                                      .withValues(alpha: 0.55),
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

  // ── 공통 위젯 ──

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? trailing,
  }) {
    return Row(
      children: [
        Icon(icon,
            size: 20, color: NestColors.deepWood.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          title,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (trailing != null) ...[
          const Spacer(),
          Text(
            trailing,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.55),
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildQuietCard(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.6),
            ),
      ),
    );
  }

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _shortTime(String value) {
    final source = value.trim();
    final parts = source.split(':');
    if (parts.length < 2) return source;
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  String _dayLabel(int dayOfWeek) {
    const labels = <int, String>{
      0: '일', 1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토',
    };
    return labels[dayOfWeek] ?? '$dayOfWeek';
  }
}

// ── 공유 위젯 ──

class _StudentSessionRow {
  const _StudentSessionRow({
    required this.className,
    required this.session,
    required this.slot,
  });

  final String className;
  final ClassSession session;
  final TimeSlot slot;
}

/// 수업 변경 배지. 학생 시간표 탭에서도 같은 표현을 쓴다.
class StudentChangeBadge extends StatelessWidget {
  const StudentChangeBadge({super.key, required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: NestColors.clay.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w800,
          color: NestColors.clay,
        ),
      ),
    );
  }
}

/// 결석 신고 배지.
class StudentAbsenceBadge extends StatelessWidget {
  const StudentAbsenceBadge({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 4 : 6,
        vertical: compact ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: NestColors.mutedSage.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '결석',
        style: TextStyle(
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w800,
          color: NestColors.mutedSage,
        ),
      ),
    );
  }
}

/// 결석 신고 상태 칩.
class StudentStatusChip extends StatelessWidget {
  const StudentStatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: NestColors.roseMist.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: NestColors.deepWood,
        ),
      ),
    );
  }
}
