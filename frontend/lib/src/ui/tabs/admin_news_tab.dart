import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../models/new_term_checklist.dart';
import '../models/tab_section_request.dart';
import '../nest_theme.dart';
import '../widgets/nest_empty_state.dart';
import '../widgets/nest_refresh.dart';

/// 관리자 소식 탭 — 공지사항과 학사일정을 한 화면에서 관리한다.
///
/// 신학기에 가장 자주 하는 두 가지 작업(개학 공지 쓰기, 학사일정 올리기)이
/// 대시보드 카드 안에 묻혀 있던 것을 전용 탭으로 끌어올렸다. 모바일 기준으로
/// 설계했다: 세그먼트 전환 → 전폭 추가 버튼 → 바텀시트 편집기, 날짜는 직접
/// 타이핑하지 않고 달력 피커로 고른다.
class AdminNewsTab extends StatefulWidget {
  const AdminNewsTab({
    super.key,
    required this.controller,
    this.sectionRequest,
  });

  final NestController controller;

  /// 관리자 홈에서 특정 세그먼트를 지정해 들어올 때 사용한다.
  final TabSectionRequest? sectionRequest;

  @override
  State<AdminNewsTab> createState() => _AdminNewsTabState();
}

class _AdminNewsTabState extends State<AdminNewsTab> {
  static const _noticeSection = NewTermSections.notices;
  static const _eventSection = NewTermSections.events;

  String _section = _noticeSection;

  @override
  void initState() {
    super.initState();
    _applySectionRequest(widget.sectionRequest);
  }

  @override
  void didUpdateWidget(covariant AdminNewsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final request = widget.sectionRequest;
    if (request != null && request.isNewerThan(oldWidget.sectionRequest)) {
      setState(() => _applySectionRequest(request));
    }
  }

  void _applySectionRequest(TabSectionRequest? request) {
    if (request == null) return;
    if (request.section == _noticeSection || request.section == _eventSection) {
      _section = request.section;
    }
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorText(Object error) =>
      error is StateError ? error.message : widget.controller.statusMessage;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    if (!controller.canWriteAnnouncement) {
      return const NestEmptyState(
        icon: Icons.lock_outline,
        title: '관리자/교사 전용 화면입니다',
        subtitle: '공지와 학사일정은 관리자·스태프·교사만 관리할 수 있습니다.',
      );
    }

    return NestRefreshable(
      onRefresh: () => controller.refreshAll(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSectionSwitcher(context),
          const SizedBox(height: 12),
          if (_section == _noticeSection)
            ..._buildNoticeSection(context, controller)
          else
            ..._buildEventSection(context, controller),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionSwitcher(BuildContext context) {
    final controller = widget.controller;
    final noticeCount = controller.allAnnouncements.length;
    final eventCount = controller.academicEvents.length;

    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: [
          ButtonSegment<String>(
            value: _noticeSection,
            icon: const Icon(Icons.campaign_outlined, size: 18),
            label: Text(
              noticeCount == 0 ? '공지사항' : '공지사항 $noticeCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ButtonSegment<String>(
            value: _eventSection,
            icon: const Icon(Icons.event_note_outlined, size: 18),
            label: Text(
              eventCount == 0 ? '학사일정' : '학사일정 $eventCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        selected: {_section},
        showSelectedIcon: false,
        onSelectionChanged: (values) =>
            setState(() => _section = values.first),
      ),
    );
  }

  // ── 공지사항 ──────────────────────────────────────────────

  List<Widget> _buildNoticeSection(
    BuildContext context,
    NestController controller,
  ) {
    final notices = controller.allAnnouncements.toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

    return [
      _PrimaryAction(
        icon: Icons.edit_note,
        label: '새 공지 작성',
        onPressed: controller.isBusy ? null : () => _openNoticeEditor(),
      ),
      const SizedBox(height: 12),
      if (notices.isEmpty)
        NestEmptyState(
          icon: Icons.campaign_outlined,
          title: '등록된 공지가 없습니다',
          subtitle: '개학 안내, 준비물, 일정 변경 등을 공지로 남겨보세요.',
          actionLabel: '새 공지 작성',
          onAction: controller.isBusy ? null : () => _openNoticeEditor(),
        )
      else
        ...notices.map(
          (notice) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _NoticeCard(
              notice: notice,
              scopeLabel: notice.classGroupId == null
                  ? '전체'
                  : controller.findClassGroupName(notice.classGroupId),
              authorLabel: controller.findMemberName(notice.authorUserId),
              busy: controller.isBusy,
              onEdit: () => _openNoticeEditor(notice: notice),
              onTogglePin: () => _toggleNoticePin(notice),
              onDelete: () => _confirmDeleteNotice(notice),
            ),
          ),
        ),
    ];
  }

  Future<void> _openNoticeEditor({Announcement? notice}) async {
    final controller = widget.controller;
    final result = await showModalBottomSheet<_NoticeDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _NoticeEditorSheet(
        notice: notice,
        classGroups: controller.classGroups,
      ),
    );

    if (result == null || !mounted) return;

    try {
      if (notice == null) {
        await controller.createAnnouncement(
          title: result.title,
          body: result.body,
          classGroupId: result.classGroupId,
          pinned: result.pinned,
        );
      } else {
        await controller.updateAnnouncement(
          announcementId: notice.id,
          title: result.title,
          body: result.body,
          classGroupId: result.classGroupId,
          pinned: result.pinned,
        );
      }
      _showMessage(controller.statusMessage);
    } catch (error) {
      _showMessage(_errorText(error));
    }
  }

  Future<void> _toggleNoticePin(Announcement notice) async {
    final controller = widget.controller;
    try {
      await controller.updateAnnouncement(
        announcementId: notice.id,
        title: notice.title,
        body: notice.body,
        classGroupId: notice.classGroupId,
        pinned: !notice.pinned,
      );
      _showMessage(notice.pinned ? '상단 고정을 해제했습니다.' : '공지를 상단에 고정했습니다.');
    } catch (error) {
      _showMessage(_errorText(error));
    }
  }

  Future<void> _confirmDeleteNotice(Announcement notice) async {
    final confirmed = await _confirmDelete(
      title: '공지 삭제',
      message: '"${notice.title}" 공지를 삭제할까요?\n삭제하면 되돌릴 수 없습니다.',
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.controller.deleteAnnouncement(announcementId: notice.id);
      _showMessage(widget.controller.statusMessage);
    } catch (error) {
      _showMessage(_errorText(error));
    }
  }

  // ── 학사일정 ──────────────────────────────────────────────

  List<Widget> _buildEventSection(
    BuildContext context,
    NestController controller,
  ) {
    if (!controller.isAdminLike) {
      return const [
        NestEmptyState(
          icon: Icons.lock_outline,
          title: '학사일정은 관리자 전용입니다',
          subtitle: '공지사항 세그먼트에서 공지를 관리할 수 있습니다.',
        ),
      ];
    }

    final today = DateUtils.dateOnly(DateTime.now());
    final events = controller.academicEvents.toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    bool isPast(AcademicEvent event) =>
        (event.endDate ?? event.eventDate).isBefore(today);

    final upcoming = events.where((event) => !isPast(event)).toList();
    final past = events.where(isPast).toList().reversed.toList();

    return [
      _PrimaryAction(
        icon: Icons.event_available_outlined,
        label: '학사일정 추가',
        onPressed: controller.isBusy ? null : () => _openEventEditor(),
      ),
      const SizedBox(height: 12),
      if (events.isEmpty)
        NestEmptyState(
          icon: Icons.event_note_outlined,
          title: '등록된 학사 일정이 없습니다',
          subtitle: '개학일, 방학, 행사 등을 올리면 학부모·학생 화면에 함께 보입니다.',
          actionLabel: '학사일정 추가',
          onAction: controller.isBusy ? null : () => _openEventEditor(),
        )
      else ...[
        if (upcoming.isNotEmpty) ...[
          _SectionLabel(text: '다가오는 일정', count: upcoming.length),
          const SizedBox(height: 8),
          ...upcoming.map((event) => _buildEventTile(controller, event)),
        ],
        if (past.isNotEmpty) ...[
          if (upcoming.isNotEmpty) const SizedBox(height: 8),
          _SectionLabel(text: '지난 일정', count: past.length),
          const SizedBox(height: 8),
          ...past.map(
            (event) => _buildEventTile(controller, event, dimmed: true),
          ),
        ],
      ],
    ];
  }

  Widget _buildEventTile(
    NestController controller,
    AcademicEvent event, {
    bool dimmed = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _AcademicEventCard(
        event: event,
        dimmed: dimmed,
        busy: controller.isBusy,
        onEdit: () => _openEventEditor(event: event),
        onDelete: () => _confirmDeleteEvent(event),
      ),
    );
  }

  Future<void> _openEventEditor({AcademicEvent? event}) async {
    final result = await showModalBottomSheet<_EventDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _EventEditorSheet(
        event: event,
        termStart: widget.controller.selectedTerm?.startDate,
      ),
    );

    if (result == null || !mounted) return;

    final controller = widget.controller;
    final formatter = DateFormat('yyyy-MM-dd');
    try {
      if (event == null) {
        await controller.createAcademicEvent(
          title: result.title,
          description: result.description,
          eventDate: formatter.format(result.startDate),
          endDate: result.endDate == null
              ? null
              : formatter.format(result.endDate!),
        );
      } else {
        await controller.updateAcademicEvent(
          eventId: event.id,
          title: result.title,
          description: result.description,
          eventDate: formatter.format(result.startDate),
          endDate: result.endDate == null
              ? null
              : formatter.format(result.endDate!),
        );
      }
      if (mounted) setState(() {});
      _showMessage(controller.statusMessage);
    } catch (error) {
      _showMessage(_errorText(error));
    }
  }

  Future<void> _confirmDeleteEvent(AcademicEvent event) async {
    final confirmed = await _confirmDelete(
      title: '학사일정 삭제',
      message: '"${event.title}" 일정을 삭제할까요?',
    );
    if (confirmed != true || !mounted) return;

    try {
      await widget.controller.deleteAcademicEvent(eventId: event.id);
      if (mounted) setState(() {});
      _showMessage(widget.controller.statusMessage);
    } catch (error) {
      _showMessage(_errorText(error));
    }
  }

  Future<bool?> _confirmDelete({
    required String title,
    required String message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ── 공용 조각 ────────────────────────────────────────────────

/// 목록 위에 붙는 전폭 기본 동작 버튼. 모바일에서 엄지로 누르기 쉬운 높이.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.count});

  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: NestColors.deepWood,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$count',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: NestColors.deepWood.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.scopeLabel,
    required this.authorLabel,
    required this.busy,
    required this.onEdit,
    required this.onTogglePin,
    required this.onDelete,
  });

  final Announcement notice;
  final String scopeLabel;
  final String authorLabel;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = notice.createdAt == null
        ? ''
        : DateFormat('M월 d일').format(notice.createdAt!);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white,
        border: Border.all(
          color: notice.pinned ? NestColors.dustyRose : NestColors.roseMist,
          width: notice.pinned ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notice.pinned) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.push_pin,
                    size: 16,
                    color: NestColors.dustyRose,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  notice.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _RowMenu(
                busy: busy,
                items: [
                  _MenuAction(
                    icon: Icons.edit_outlined,
                    label: '수정',
                    onSelected: onEdit,
                  ),
                  _MenuAction(
                    icon: notice.pinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin,
                    label: notice.pinned ? '고정 해제' : '상단 고정',
                    onSelected: onTogglePin,
                  ),
                  _MenuAction(
                    icon: Icons.delete_outline,
                    label: '삭제',
                    destructive: true,
                    onSelected: onDelete,
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  notice.body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetaChip(icon: Icons.groups_outlined, label: scopeLabel),
                    if (authorLabel.isNotEmpty)
                      _MetaChip(
                        icon: Icons.person_outline,
                        label: authorLabel,
                      ),
                    if (created.isNotEmpty)
                      _MetaChip(
                        icon: Icons.schedule_outlined,
                        label: created,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademicEventCard extends StatelessWidget {
  const _AcademicEventCard({
    required this.event,
    required this.dimmed,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final AcademicEvent event;
  final bool dimmed;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = event.eventDate;
    final end = event.endDate;
    final multiDay = end != null && !DateUtils.isSameDay(start, end);
    final rangeLabel = multiDay
        ? '${DateFormat('M.d').format(start)} ~ ${DateFormat('M.d').format(end)}'
        : DateFormat('EEEE', 'ko').format(start);
    final alpha = dimmed ? 0.45 : 1.0;

    return Opacity(
      opacity: alpha,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white,
          border: Border.all(color: NestColors.roseMist),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: NestColors.roseMist.withValues(alpha: 0.5),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('M월').format(start),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: NestColors.clay,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${start.day}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: NestColors.deepWood,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    rangeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.55),
                    ),
                  ),
                  if (event.description.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        event.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            _RowMenu(
              busy: busy,
              items: [
                _MenuAction(
                  icon: Icons.edit_outlined,
                  label: '수정',
                  onSelected: onEdit,
                ),
                _MenuAction(
                  icon: Icons.delete_outline,
                  label: '삭제',
                  destructive: true,
                  onSelected: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuAction {
  const _MenuAction({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool destructive;
}

/// 카드 우측 오버플로 메뉴. 좁은 화면에서 버튼 여러 개가 제목을 밀어내지 않도록
/// 수정/고정/삭제를 한 곳에 모은다.
class _RowMenu extends StatelessWidget {
  const _RowMenu({required this.busy, required this.items});

  final bool busy;
  final List<_MenuAction> items;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return PopupMenuButton<int>(
      enabled: !busy,
      tooltip: '더보기',
      icon: Icon(
        Icons.more_vert,
        size: 20,
        color: NestColors.deepWood.withValues(alpha: 0.6),
      ),
      onSelected: (index) => items[index].onSelected(),
      itemBuilder: (context) => [
        for (var index = 0; index < items.length; index++)
          PopupMenuItem<int>(
            value: index,
            child: Row(
              children: [
                Icon(
                  items[index].icon,
                  size: 18,
                  color: items[index].destructive ? errorColor : null,
                ),
                const SizedBox(width: 10),
                Text(
                  items[index].label,
                  style: items[index].destructive
                      ? TextStyle(color: errorColor)
                      : null,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: NestColors.creamyWhite,
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: NestColors.clay),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: NestColors.deepWood.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 편집 바텀시트 ─────────────────────────────────────────────

class _NoticeDraft {
  const _NoticeDraft({
    required this.title,
    required this.body,
    required this.classGroupId,
    required this.pinned,
  });

  final String title;
  final String body;
  final String? classGroupId;
  final bool pinned;
}

class _NoticeEditorSheet extends StatefulWidget {
  const _NoticeEditorSheet({required this.notice, required this.classGroups});

  final Announcement? notice;
  final List<ClassGroup> classGroups;

  @override
  State<_NoticeEditorSheet> createState() => _NoticeEditorSheetState();
}

class _NoticeEditorSheetState extends State<_NoticeEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late String? _classGroupId;
  late bool _pinned;

  @override
  void initState() {
    super.initState();
    final notice = widget.notice;
    _titleController = TextEditingController(text: notice?.title ?? '');
    _bodyController = TextEditingController(text: notice?.body ?? '');
    _pinned = notice?.pinned ?? false;
    // 삭제된 반을 가리키던 공지는 대상 드롭다운이 값을 못 찾아 터지므로 전체로 되돌린다.
    final classGroupId = notice?.classGroupId;
    _classGroupId =
        classGroupId != null &&
            widget.classGroups.any((group) => group.id == classGroupId)
        ? classGroupId
        : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _NoticeDraft(
        title: _titleController.text,
        body: _bodyController.text,
        classGroupId: _classGroupId,
        pinned: _pinned,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.notice != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? '공지 수정' : '새 공지 작성',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                autofocus: !isEdit,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '제목',
                  hintText: '예: 2학기 개학 안내',
                  prefixIcon: Icon(Icons.title, size: 20),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? '제목을 입력하세요.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bodyController,
                minLines: 4,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: '내용',
                  alignLabelWithHint: true,
                  hintText: '학부모·선생님에게 전할 내용을 적어주세요.',
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? '내용을 입력하세요.'
                    : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _classGroupId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: '받는 대상',
                  prefixIcon: Icon(Icons.groups_outlined, size: 20),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('전체 (모든 반)'),
                  ),
                  ...widget.classGroups.map(
                    (group) => DropdownMenuItem<String?>(
                      value: group.id,
                      child: Text(group.name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => setState(() => _classGroupId = value),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                title: const Text('상단 고정'),
                subtitle: const Text('중요한 공지를 목록 맨 위에 둡니다.'),
                value: _pinned,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) => setState(() => _pinned = value),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: Icon(isEdit ? Icons.check : Icons.send, size: 20),
                  label: Text(isEdit ? '수정 저장' : '공지 등록'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDraft {
  const _EventDraft({
    required this.title,
    required this.description,
    required this.startDate,
    required this.endDate,
  });

  final String title;
  final String description;
  final DateTime startDate;
  final DateTime? endDate;
}

class _EventEditorSheet extends StatefulWidget {
  const _EventEditorSheet({required this.event, required this.termStart});

  final AcademicEvent? event;

  /// 새 일정의 기본 날짜 후보. 학기 시작일이 오늘 이후면 그 날짜를 먼저 제안한다.
  final DateTime? termStart;

  @override
  State<_EventEditorSheet> createState() => _EventEditorSheetState();
}

class _EventEditorSheetState extends State<_EventEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late DateTime _startDate;
  DateTime? _endDate;
  late bool _multiDay;

  @override
  void initState() {
    super.initState();
    final event = widget.event;
    _titleController = TextEditingController(text: event?.title ?? '');
    _descController = TextEditingController(text: event?.description ?? '');

    final today = DateUtils.dateOnly(DateTime.now());
    final termStart = widget.termStart;
    _startDate =
        event?.eventDate ??
        (termStart != null && !termStart.isBefore(today)
            ? DateUtils.dateOnly(termStart)
            : today);
    _endDate = event?.endDate;
    _multiDay =
        _endDate != null && !DateUtils.isSameDay(_startDate, _endDate!);
    if (!_multiDay) _endDate = null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 5),
      helpText: isStart ? '시작 날짜 선택' : '종료 날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startDate = picked;
        // 시작일이 종료일을 넘어서면 종료일을 시작일에 맞춰 끌어올린다.
        if (_endDate != null && _endDate!.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      } else {
        _endDate = picked.isBefore(_startDate) ? _startDate : picked;
      }
    });
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _EventDraft(
        title: _titleController.text,
        description: _descController.text,
        startDate: _startDate,
        endDate: _multiDay ? (_endDate ?? _startDate) : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.event != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isEdit ? '학사일정 수정' : '학사일정 추가',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                autofocus: !isEdit,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '일정 이름',
                  hintText: '예: 개학식, 가을 현장학습',
                  prefixIcon: Icon(Icons.title, size: 20),
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? '일정 이름을 입력하세요.'
                    : null,
              ),
              const SizedBox(height: 12),
              _DatePickerField(
                label: _multiDay ? '시작 날짜' : '날짜',
                value: _startDate,
                onTap: () => _pickDate(isStart: true),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                title: const Text('여러 날 진행'),
                subtitle: const Text('방학·수련회처럼 기간이 있는 일정'),
                value: _multiDay,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) => setState(() {
                  _multiDay = value;
                  _endDate = value ? (_endDate ?? _startDate) : null;
                }),
              ),
              if (_multiDay) ...[
                _DatePickerField(
                  label: '종료 날짜',
                  value: _endDate ?? _startDate,
                  onTap: () => _pickDate(isStart: false),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _descController,
                minLines: 2,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                decoration: const InputDecoration(
                  labelText: '설명 (선택)',
                  alignLabelWithHint: true,
                  hintText: '준비물, 장소 등을 적어주세요.',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: Icon(isEdit ? Icons.check : Icons.add, size: 20),
                  label: Text(isEdit ? '수정 저장' : '일정 추가'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 날짜를 직접 입력하지 않고 달력에서 고르게 하는 필드. 모바일에서
/// `yyyy-MM-dd` 타이핑을 없애는 것이 이 화면 개편의 핵심 중 하나다.
class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: Text(
          DateFormat('yyyy년 M월 d일 (E)', 'ko').format(value),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
