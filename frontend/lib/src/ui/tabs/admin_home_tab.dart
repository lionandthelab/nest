import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../models/new_term_checklist.dart';
import '../nest_theme.dart';
import '../widgets/drive_integration_card.dart';
import '../widgets/nest_empty_state.dart';
import '../widgets/nest_refresh.dart';
import '../widgets/nest_skeleton.dart';
import '../widgets/quick_bootstrap_card.dart';
import '../widgets/term_navigator_bar.dart';
import 'dashboard_tab.dart' show PendingInvitesCard;

/// 관리자 홈 — 신학기 운영의 출발점.
///
/// 예전 대시보드는 초대/가입요청/지표/학사일정/Drive/공지/초기세팅이 한 줄로
/// 이어진 긴 스크롤이라, 모바일에서 "지금 뭘 해야 하는지"가 보이지 않았다.
/// 이 화면은 세 덩어리로 다시 짰다.
///
/// 1. 학기 상태 헤더 — 지금 보고 있는 학기와 개학까지 남은 날
/// 2. 신학기 준비 체크리스트 — 남은 단계를 눌러 해당 화면으로 바로 이동
/// 3. 빠른 작업 — 공지/학사일정/반/시간표 등 자주 쓰는 진입점 (큰 탭 타깃)
///
/// 그 아래에 처리 대기 알림과 요약을 붙이고, 자주 쓰지 않는 Drive 설정은
/// 접힌 상태로 맨 아래에 둔다.
class AdminHomeTab extends StatelessWidget {
  const AdminHomeTab({
    super.key,
    required this.controller,
    required this.onNavigate,
  });

  final NestController controller;

  /// 탭(+선택적 섹션)으로 이동한다. `HomePage`가 넘겨준다.
  final void Function(String tabLabel, {String? section}) onNavigate;

  @override
  Widget build(BuildContext context) {
    final pendingChildRequests = controller.childRegistrationRequests
        .where((request) => request.isPending)
        .length;
    final pendingJoinRequests = controller.joinRequests
        .where((request) => request.isPending)
        .length;

    final checklist = buildNewTermChecklist(
      hasTerm: controller.selectedTermId != null,
      familyCount: controller.families.length,
      childCount: controller.children.length,
      teacherCount: controller.teacherProfiles.length,
      classGroupCount: controller.classGroups.length,
      enrollmentCount: controller.classEnrollments.length,
      courseCount: controller.courses.length,
      classroomCount: controller.classrooms.length,
      timeSlotCount: controller.timeSlots.length,
      sessionCount: controller.sessions.length,
      academicEventCount: controller.academicEvents.length,
      announcementCount: controller.allAnnouncements.length,
    );

    final booting =
        controller.isBusy &&
        controller.terms.isEmpty &&
        controller.classGroups.isEmpty;

    return NestRefreshable(
      onRefresh: () => controller.refreshAll(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _TermStatusHeader(controller: controller),
          const SizedBox(height: 12),
          if (controller.pendingInvites.isNotEmpty) ...[
            PendingInvitesCard(controller: controller),
            const SizedBox(height: 12),
          ],
          if (pendingJoinRequests > 0) ...[
            _AlertBanner(
              icon: Icons.person_add_alt_1,
              title: '가입 요청 $pendingJoinRequests건',
              subtitle: '승인하면 바로 홈스쿨 구성원이 됩니다.',
              onTap: () => onNavigate(NewTermTabs.system),
            ),
            const SizedBox(height: 12),
          ],
          if (pendingChildRequests > 0) ...[
            _AlertBanner(
              icon: Icons.child_care_outlined,
              title: '아이 등록 요청 $pendingChildRequests건',
              subtitle: '학부모가 올린 아이 등록을 확인해 주세요.',
              onTap: () => onNavigate(
                NewTermTabs.termSetup,
                section: NewTermSections.family,
              ),
            ),
            const SizedBox(height: 12),
          ],
          _NewTermChecklistCard(
            checklist: checklist,
            controller: controller,
            onNavigate: onNavigate,
          ),
          const SizedBox(height: 12),
          _QuickActionsCard(controller: controller, onNavigate: onNavigate),
          const SizedBox(height: 12),
          // 운영 틀이 통째로 비어 있을 때만 "한 번에 만들기" 지름길을 노출한다.
          if (controller.terms.isEmpty &&
              controller.classGroups.isEmpty &&
              controller.courses.isEmpty) ...[
            QuickBootstrapCard(controller: controller),
            const SizedBox(height: 12),
          ],
          if (booting)
            const NestSkeletonMetrics(count: 4)
          else
            _SummaryStrip(controller: controller, onNavigate: onNavigate),
          const SizedBox(height: 12),
          _UpcomingEventsCard(controller: controller, onNavigate: onNavigate),
          const SizedBox(height: 12),
          _RecentNoticesCard(controller: controller, onNavigate: onNavigate),
          const SizedBox(height: 12),
          DriveIntegrationCard(controller: controller),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── 학기 상태 헤더 ─────────────────────────────────────────────

class _TermStatusHeader extends StatelessWidget {
  const _TermStatusHeader({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final term = controller.selectedTerm;

    if (term == null) {
      return _HeaderShell(
        child: Row(
          children: [
            const Icon(Icons.event_busy_outlined, color: NestColors.clay),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '학기가 아직 없습니다.\n먼저 이번 학기를 만들어 주세요.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: NestColors.deepWood,
                ),
              ),
            ),
            FilledButton.tonal(
              onPressed: controller.isBusy
                  ? null
                  : () => showTermEditorDialog(context, controller),
              child: const Text('학기 만들기'),
            ),
          ],
        ),
      );
    }

    final phase = controller.phaseOf(term);
    final (badgeText, badgeColor) = switch (phase) {
      TermPhase.current => ('진행 중', NestColors.mutedSage),
      TermPhase.upcoming => ('예정', NestColors.dustyRose),
      TermPhase.past => ('지난 학기', NestColors.clay),
    };

    final period = _periodLabel(term);
    final countdown = _countdownLabel(term, phase);

    // 학기 이름/전환은 바로 위 TermNavigatorBar가 이미 담당하므로, 여기서는
    // 그 바에 없는 정보(기간·남은 날짜·상태)만 한 줄로 덧붙인다.
    return _HeaderShell(
      child: Row(
        children: [
          Icon(Icons.flag_outlined, size: 18, color: NestColors.clay),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              period.isEmpty ? term.name : '${term.name} · $period',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: NestColors.deepWood.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (countdown.isNotEmpty) ...[
            Text(
              countdown,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: NestColors.clay,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: badgeColor.withValues(alpha: 0.18),
              border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              badgeText,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: NestColors.deepWood,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _periodLabel(Term term) {
    final start = term.startDate;
    final end = term.endDate;
    if (start == null && end == null) return '';
    final formatter = DateFormat('yyyy.M.d');
    if (start != null && end != null) {
      return '${formatter.format(start)} ~ ${formatter.format(end)}';
    }
    return formatter.format((start ?? end)!);
  }

  String _countdownLabel(Term term, TermPhase phase) {
    final today = DateUtils.dateOnly(DateTime.now());
    switch (phase) {
      case TermPhase.upcoming:
        final start = term.startDate;
        if (start == null) return '';
        final days = DateUtils.dateOnly(start).difference(today).inDays;
        if (days <= 0) return '개학일';
        return '개학까지 D-$days';
      case TermPhase.current:
        final end = term.endDate;
        if (end == null) return '';
        final days = DateUtils.dateOnly(end).difference(today).inDays;
        if (days <= 0) return '오늘 종료';
        return '종료까지 $days일';
      case TermPhase.past:
        return '읽기 전용';
    }
  }
}

class _HeaderShell extends StatelessWidget {
  const _HeaderShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NestColors.creamyWhite,
            NestColors.roseMist.withValues(alpha: 0.6),
          ],
        ),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: child,
    );
  }
}

// ── 신학기 준비 체크리스트 ──────────────────────────────────────

class _NewTermChecklistCard extends StatefulWidget {
  const _NewTermChecklistCard({
    required this.checklist,
    required this.controller,
    required this.onNavigate,
  });

  final NewTermChecklist checklist;
  final NestController controller;
  final void Function(String tabLabel, {String? section}) onNavigate;

  @override
  State<_NewTermChecklistCard> createState() => _NewTermChecklistCardState();
}

class _NewTermChecklistCardState extends State<_NewTermChecklistCard> {
  /// 단계 목록은 기본으로 접어둔다. 9단계를 모두 펼치면 모바일 첫 화면에서
  /// '빠른 작업'이 접히는 선 아래로 밀려나므로, 평소에는 진행률과 "다음 단계"
  /// 버튼만 보여주고 전체 로드맵은 눌러서 편다.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final checklist = widget.checklist;
    final next = checklist.nextStep;
    final remaining = checklist.remainingSteps.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Icon(
                    checklist.isComplete
                        ? Icons.verified_outlined
                        : Icons.checklist_rtl,
                    size: 20,
                    color: NestColors.clay,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '신학기 준비',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${checklist.completedCount}/${checklist.totalCount}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: NestColors.deepWood.withValues(alpha: 0.7),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: checklist.progress,
                color: checklist.isComplete
                    ? NestColors.mutedSage
                    : NestColors.dustyRose,
                backgroundColor: NestColors.roseMist,
              ),
            ),
            if (!_expanded) ...[
              const SizedBox(height: 8),
              Text(
                checklist.isComplete
                    ? (remaining == 0
                          ? '이번 학기 준비가 모두 끝났습니다.'
                          : '필수 단계를 모두 마쳤습니다. 선택 단계 $remaining개가 남아 있어요.')
                    : '남은 단계 $remaining개 · 눌러서 전체 보기',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.7),
                ),
              ),
            ],
            if (_expanded) ...[
              const SizedBox(height: 12),
              ...checklist.steps.map(
                (step) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ChecklistTile(
                    step: step,
                    onTap: step.enabled ? () => _openStep(step) : null,
                  ),
                ),
              ),
            ],
            if (next != null) ...[
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: widget.controller.isBusy
                      ? null
                      : () => _openStep(next),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(
                    '다음 단계: ${next.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openStep(NewTermStep step) {
    // 학기 만들기는 탭 이동 없이 학기 편집 다이얼로그를 바로 연다.
    if (step.id == 'term') {
      showTermEditorDialog(context, widget.controller);
      return;
    }
    final tab = step.targetTab;
    if (tab == null) return;
    widget.onNavigate(tab, section: step.targetSection);
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({required this.step, required this.onTap});

  final NewTermStep step;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = step.state == NewTermStepState.done;
    final blocked = step.state == NewTermStepState.blocked;

    return Material(
      color: blocked ? NestColors.creamyWhite : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: done
                  ? NestColors.mutedSage.withValues(alpha: 0.55)
                  : NestColors.roseMist,
            ),
          ),
          child: Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle
                    : blocked
                    ? Icons.lock_outline
                    : Icons.radio_button_unchecked,
                size: 20,
                color: done
                    ? NestColors.mutedSage
                    : NestColors.deepWood.withValues(alpha: blocked ? 0.3 : 0.5),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            step.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: NestColors.deepWood.withValues(
                                alpha: blocked ? 0.5 : 1,
                              ),
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: NestColors.deepWood.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ),
                        if (step.optional) ...[
                          const SizedBox(width: 6),
                          Text(
                            '선택',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              color: NestColors.clay,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!done) ...[
                      const SizedBox(height: 2),
                      Text(
                        blocked ? '앞 단계를 먼저 끝내주세요.' : step.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(
                            alpha: blocked ? 0.4 : 0.65,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: NestColors.deepWood.withValues(alpha: 0.35),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 빠른 작업 ────────────────────────────────────────────────

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.tab,
    this.section,
  });

  final IconData icon;
  final String label;
  final String tab;
  final String? section;
}

class _QuickActionsCard extends StatelessWidget {
  const _QuickActionsCard({required this.controller, required this.onNavigate});

  final NestController controller;
  final void Function(String tabLabel, {String? section}) onNavigate;

  static const _actions = <_QuickAction>[
    _QuickAction(
      icon: Icons.campaign_outlined,
      label: '공지 작성',
      tab: NewTermTabs.news,
      section: NewTermSections.notices,
    ),
    _QuickAction(
      icon: Icons.event_note_outlined,
      label: '학사일정',
      tab: NewTermTabs.news,
      section: NewTermSections.events,
    ),
    _QuickAction(
      icon: Icons.home_work_outlined,
      label: '가정·아이',
      tab: NewTermTabs.termSetup,
      section: NewTermSections.family,
    ),
    _QuickAction(
      icon: Icons.school_outlined,
      label: '선생님',
      tab: NewTermTabs.termSetup,
      section: NewTermSections.teacher,
    ),
    _QuickAction(
      icon: Icons.groups_outlined,
      label: '반 편성',
      tab: NewTermTabs.termSetup,
      section: NewTermSections.classGroup,
    ),
    _QuickAction(
      icon: Icons.menu_book_outlined,
      label: '과목',
      tab: NewTermTabs.termSetup,
      section: NewTermSections.course,
    ),
    _QuickAction(
      icon: Icons.calendar_view_week_outlined,
      label: '시간표',
      tab: NewTermTabs.timetable,
      section: NewTermSections.timetable,
    ),
    _QuickAction(
      icon: Icons.manage_accounts_outlined,
      label: '멤버·권한',
      tab: NewTermTabs.system,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_outlined, size: 20, color: NestColors.clay),
                const SizedBox(width: 8),
                Text(
                  '빠른 작업',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                // 타일 최소 폭 150px 기준으로 열 수를 정한다(모바일 2열).
                final columns = (constraints.maxWidth / 150).floor().clamp(2, 4);
                final spacing = 10.0;
                final tileWidth =
                    (constraints.maxWidth - spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _actions
                      .map(
                        (action) => SizedBox(
                          width: tileWidth,
                          child: _QuickActionTile(
                            action: action,
                            onTap: controller.isBusy
                                ? null
                                : () => onNavigate(
                                    action.tab,
                                    section: action.section,
                                  ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});

  final _QuickAction action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NestColors.creamyWhite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: NestColors.roseMist),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: NestColors.roseMist.withValues(alpha: 0.75),
                foregroundColor: NestColors.deepWood,
                child: Icon(action.icon, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: NestColors.deepWood,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 요약 / 알림 ──────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: NestColors.roseMist.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: NestColors.dustyRose),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: NestColors.deepWood.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 숫자 요약. 예전 4칸 지표 그리드를 한 줄짜리 칩 스트립으로 줄여
/// 첫 화면에서 체크리스트와 빠른 작업이 밀려나지 않게 한다.
class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.controller, required this.onNavigate});

  final NestController controller;
  final void Function(String tabLabel, {String? section}) onNavigate;

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, int, String, String?)>[
      (
        Icons.home_work_outlined,
        '가정',
        controller.families.length,
        NewTermTabs.termSetup,
        NewTermSections.family,
      ),
      (
        Icons.child_friendly_outlined,
        '아이',
        controller.children.length,
        NewTermTabs.termSetup,
        NewTermSections.family,
      ),
      (
        Icons.groups_outlined,
        '반',
        controller.classGroups.length,
        NewTermTabs.termSetup,
        NewTermSections.classGroup,
      ),
      (
        Icons.school_outlined,
        '선생님',
        controller.teacherProfiles.length,
        NewTermTabs.termSetup,
        NewTermSections.teacher,
      ),
      (
        Icons.view_week_outlined,
        '수업',
        controller.sessions.length,
        NewTermTabs.timetable,
        NewTermSections.timetable,
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entries
          .map(
            (entry) => _SummaryChip(
              icon: entry.$1,
              label: entry.$2,
              value: entry.$3,
              onTap: controller.isBusy
                  ? null
                  : () => onNavigate(entry.$4, section: entry.$5),
            ),
          )
          .toList(),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: NestColors.roseMist),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: NestColors.clay),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$value',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: NestColors.deepWood,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UpcomingEventsCard extends StatelessWidget {
  const _UpcomingEventsCard({
    required this.controller,
    required this.onNavigate,
  });

  final NestController controller;
  final void Function(String tabLabel, {String? section}) onNavigate;

  @override
  Widget build(BuildContext context) {
    final today = DateUtils.dateOnly(DateTime.now());
    final upcoming =
        controller.academicEvents
            .where(
              (event) =>
                  !(event.endDate ?? event.eventDate).isBefore(today),
            )
            .toList()
          ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    return _ListCard(
      icon: Icons.event_note_outlined,
      title: '다가오는 학사일정',
      actionLabel: '관리',
      onAction: () =>
          onNavigate(NewTermTabs.news, section: NewTermSections.events),
      child: upcoming.isEmpty
          ? const _InlineEmpty(text: '예정된 일정이 없습니다. 개학일과 학기 행사를 등록해 주세요.')
          : Column(
              children: upcoming
                  .take(3)
                  .map(
                    (event) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 58,
                            child: Text(
                              DateFormat('M.d(E)', 'ko').format(event.eventDate),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: NestColors.clay,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _RecentNoticesCard extends StatelessWidget {
  const _RecentNoticesCard({
    required this.controller,
    required this.onNavigate,
  });

  final NestController controller;
  final void Function(String tabLabel, {String? section}) onNavigate;

  @override
  Widget build(BuildContext context) {
    final notices = controller.allAnnouncements.take(3).toList();

    return _ListCard(
      icon: Icons.campaign_outlined,
      title: '최근 공지',
      actionLabel: '관리',
      onAction: () =>
          onNavigate(NewTermTabs.news, section: NewTermSections.notices),
      child: notices.isEmpty
          ? const _InlineEmpty(text: '등록된 공지가 없습니다. 새 학기 안내를 남겨보세요.')
          : Column(
              children: notices
                  .map(
                    (notice) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          if (notice.pinned) ...[
                            Icon(
                              Icons.push_pin,
                              size: 14,
                              color: NestColors.dustyRose,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              notice.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            notice.classGroupId == null
                                ? '전체'
                                : controller.findClassGroupName(
                                    notice.classGroupId,
                                  ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: NestColors.deepWood.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

/// 요약 카드 안에서 쓰는 한 줄 빈 상태.
/// [NestEmptyState]는 아이콘 72px + 상하 40px 여백이라, 요약 카드 두 개가 모두
/// 비어 있으면 첫 화면이 통째로 여백이 된다.
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: NestColors.deepWood.withValues(alpha: 0.55),
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.icon,
    required this.title,
    required this.actionLabel,
    required this.onAction,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: NestColors.clay),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}
