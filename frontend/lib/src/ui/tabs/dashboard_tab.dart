import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({
    super.key,
    required this.controller,
    this.onRequestTabChange,
  });

  final NestController controller;
  final ValueChanged<String>? onRequestTabChange;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _formKey = GlobalKey<FormState>();
  final _joinSearchController = TextEditingController();
  final _joinRequestNoteController = TextEditingController();
  bool _bootstrapExpanded = false;
  final _homeschoolController = TextEditingController(text: 'Nest Warm Home');
  final _termController = TextEditingController(text: '2026 Spring');
  final _classController = TextEditingController(text: 'Robin Class');
  final _courseController = TextEditingController(text: '국어, 수학, 자연탐구, 미술');
  bool _joinSearching = false;
  List<HomeschoolDirectoryEntry> _joinSearchResults = const [];
  String? _joinSearchMessage;
  final Set<String> _joinRequestingIds = <String>{};

  late final TextEditingController _startDateController;
  late final TextEditingController _endDateController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 4, now.day);
    _startDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(now),
    );
    _endDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(end),
    );
  }

  @override
  void dispose() {
    _joinSearchController.dispose();
    _joinRequestNoteController.dispose();
    _homeschoolController.dispose();
    _termController.dispose();
    _classController.dispose();
    _courseController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;

    final noMembership = controller.memberships.isEmpty;

    // ── No membership: onboarding experience ──
    if (noMembership) {
      return ListView(
        children: [
          _buildOnboardingWelcome(theme, controller),
          if (controller.pendingInvites.isNotEmpty) ...[
            const SizedBox(height: 16),
            _PendingInvitesCard(controller: controller),
          ],
          const SizedBox(height: 16),
          _buildOnboardingJoinRequestCard(theme, controller),
          const SizedBox(height: 16),
          _buildOnboardingCreateCard(theme, controller),
        ],
      );
    }

    // ── Normal dashboard ──
    // Determine if setup guide should show (admin + not all steps done)
    final showSetupGuide =
        controller.isAdminLike &&
        !_setupSteps(controller).every((s) => s.completed);

    // Bootstrap already done when homeschool + term + class all exist
    final bootstrapDone =
        controller.selectedHomeschoolId != null &&
        controller.terms.isNotEmpty &&
        controller.classGroups.isNotEmpty;

    return ListView(
      children: [
        if (controller.pendingInvites.isNotEmpty) ...[
          _PendingInvitesCard(controller: controller),
          const SizedBox(height: 16),
        ],
        if (showSetupGuide) ...[
          _buildAdminSetupFlowCard(theme, controller),
          const SizedBox(height: 16),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 980
                ? 4
                : width >= 680
                ? 3
                : 2;
            final itemWidth =
                (width - ((crossAxisCount - 1) * 12)) / crossAxisCount;
            final childAspectRatio = itemWidth / 108;

            return GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: childAspectRatio,
              children: [
                _SummaryCard(
                  label: '소속 홈스쿨',
                  value: '${controller.memberships.length}',
                  icon: Icons.house,
                ),
                _SummaryCard(
                  label: '학기',
                  value: '${controller.terms.length}',
                  icon: Icons.calendar_month,
                ),
                _SummaryCard(
                  label: '반',
                  value: '${controller.classGroups.length}',
                  icon: Icons.groups,
                ),
                _SummaryCard(
                  label: '활성 수업',
                  value: '${controller.sessions.length}',
                  icon: Icons.view_week,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('최근 공지', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    if (controller.canWriteAnnouncement)
                      FilledButton.tonalIcon(
                        onPressed: controller.isBusy
                            ? null
                            : () => _showCreateAnnouncementModal(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('공지 작성'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (controller.announcements.isEmpty)
                  const Text('등록된 공지가 없습니다.')
                else
                  ...controller.announcements.take(3).map((notice) {
                    final scope = notice.classGroupId == null
                        ? '전체'
                        : controller.findClassGroupName(notice.classGroupId);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${notice.pinned ? '[PIN] ' : ''}${notice.title}',
                      ),
                      subtitle: Text('$scope · ${notice.body}'),
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (controller.isAdminLike)
          _buildBootstrapCard(theme, controller, bootstrapDone)
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '관리 기능(초기 세팅, 권한 관리, Drive 설정)은 관리자 뷰에서 사용할 수 있습니다.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBootstrapCard(
    ThemeData theme,
    NestController controller,
    bool bootstrapDone,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () =>
                  setState(() => _bootstrapExpanded = !_bootstrapExpanded),
              child: Row(
                children: [
                  Text('빠른 초기 세팅', style: theme.textTheme.titleLarge),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _bootstrapExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                  const Spacer(),
                  if (bootstrapDone)
                    Chip(
                      label: const Text('세팅 완료'),
                      avatar: Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green.shade600,
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _bootstrapExpanded
                  ? Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            '관리 운영의 기본 틀(홈스쿨, 학기, 반, 과목, 시간 슬롯)을 자동으로 만듭니다.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: NestColors.deepWood.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _homeschoolController,
                            decoration: const InputDecoration(
                              labelText: '홈스쿨 이름',
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? '필수값입니다.'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _termController,
                            decoration: const InputDecoration(
                              labelText: '학기 이름',
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? '필수값입니다.'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _startDateController,
                                  decoration: const InputDecoration(
                                    labelText: '시작일 (YYYY-MM-DD)',
                                  ),
                                  validator: _validateDate,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _endDateController,
                                  decoration: const InputDecoration(
                                    labelText: '종료일 (YYYY-MM-DD)',
                                  ),
                                  validator: _validateDate,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _classController,
                            decoration: const InputDecoration(
                              labelText: '반 이름',
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                ? '필수값입니다.'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _courseController,
                            decoration: const InputDecoration(
                              labelText: '기본 과목 (콤마 구분)',
                            ),
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            onPressed: controller.isBusy
                                ? null
                                : () => _submitBootstrap(),
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('운영 틀 생성'),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAnnouncementModal(BuildContext context) {
    final controller = widget.controller;
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    String? selectedClassGroupId;
    bool pinned = false;
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('공지사항 작성', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 14),
                TextFormField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: '제목'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '제목을 입력하세요.' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: bodyCtrl,
                  decoration: const InputDecoration(labelText: '본문'),
                  maxLines: 4,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '본문을 입력하세요.' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: selectedClassGroupId,
                  decoration: const InputDecoration(labelText: '대상'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('전체')),
                    ...controller.classGroups.map(
                      (cg) =>
                          DropdownMenuItem(value: cg.id, child: Text(cg.name)),
                    ),
                  ],
                  onChanged: (v) =>
                      setModalState(() => selectedClassGroupId = v),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: const Text('상단 고정'),
                  value: pinned,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setModalState(() => pinned = v),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: controller.isBusy
                        ? null
                        : () async {
                            if (!(formKey.currentState?.validate() ?? false)) {
                              return;
                            }
                            try {
                              await controller.createAnnouncement(
                                title: titleCtrl.text,
                                body: bodyCtrl.text,
                                classGroupId: selectedClassGroupId,
                                pinned: pinned,
                              );
                              if (ctx.mounted) Navigator.of(ctx).pop();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(controller.statusMessage),
                                  ),
                                );
                              }
                            } catch (_) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(controller.statusMessage),
                                  ),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.send),
                    label: const Text('등록'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Onboarding for users with no membership ──

  Widget _buildOnboardingWelcome(ThemeData theme, NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: NestColors.roseMist,
                  foregroundColor: NestColors.deepWood,
                  child: const Icon(Icons.waving_hand, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nest에 오신 것을 환영합니다!',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.user?.email ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '아직 소속된 홈스쿨이 없습니다. 아래 두 가지 방법으로 시작할 수 있습니다.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            _OnboardingOption(
              icon: Icons.mail_outline,
              title: '초대를 받았나요?',
              description:
                  '홈스쿨 관리자가 이메일로 초대하면 아래 "대기 중 초대" 카드가 나타납니다.\n'
                  '관리자에게 가입한 이메일 주소를 알려주세요.',
              highlight: controller.pendingInvites.isNotEmpty,
            ),
            const SizedBox(height: 10),
            const _OnboardingOption(
              icon: Icons.travel_explore,
              title: '홈스쿨 검색 후 가입 요청',
              description:
                  '홈스쿨 이름으로 검색하고 가입 요청을 보낼 수 있습니다.\n'
                  '요청은 홈스쿨 관리자 승인 후 참여가 완료됩니다.',
              highlight: false,
            ),
            const SizedBox(height: 10),
            _OnboardingOption(
              icon: Icons.add_home,
              title: '새 홈스쿨을 직접 개설',
              description:
                  '관리자로서 새 홈스쿨을 개설하고 학기, 반, 과목을 한번에 설정합니다.\n'
                  '아래 버튼을 눌러 개설 모달에서 진행하세요.',
              highlight: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingCreateCard(
    ThemeData theme,
    NestController controller,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_home, color: NestColors.dustyRose),
                const SizedBox(width: 8),
                Text('홈스쿨 개설', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '홈스쿨, 학기, 반, 과목, 시간 슬롯을 한번에 만들고 관리자로 시작합니다.\n'
              '개설 버튼을 누르면 모달에서 입력할 수 있습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: controller.isBusy ? null : _showOnboardingCreateModal,
              icon: const Icon(Icons.open_in_new),
              label: const Text('홈스쿨 개설 열기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOnboardingJoinRequestCard(
    ThemeData theme,
    NestController controller,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.travel_explore, color: NestColors.dustyRose),
                const SizedBox(width: 8),
                Text('홈스쿨 검색 및 가입 요청', style: theme.textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '이름으로 홈스쿨을 검색한 뒤 가입 요청을 보낼 수 있습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _joinSearchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchHomeschools(),
                    decoration: const InputDecoration(
                      labelText: '홈스쿨 이름 검색',
                      hintText: '예: Nest Warm Home',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.tonalIcon(
                  onPressed: _joinSearching ? null : _searchHomeschools,
                  icon: const Icon(Icons.search),
                  label: const Text('검색'),
                ),
              ],
            ),
            if (_joinSearchMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                _joinSearchMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.72),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (_joinSearching)
              const Center(child: CircularProgressIndicator())
            else if (_joinSearchResults.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NestColors.roseMist),
                  color: NestColors.creamyWhite,
                ),
                child: Text(
                  '검색어를 입력하고 홈스쿨을 찾아보세요.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              ..._joinSearchResults.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OnboardingJoinResultTile(
                    entry: entry,
                    isRequesting: _joinRequestingIds.contains(entry.id),
                    onRequest: () => _promptJoinRequest(entry),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showOnboardingCreateModal() async {
    final controller = widget.controller;
    await showDialog<void>(
      context: context,
      barrierDismissible: !controller.isBusy,
      builder: (dialogContext) {
        final maxWidth = MediaQuery.of(dialogContext).size.width < 700
            ? double.infinity
            : 680.0;
        return Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '홈스쿨 개설',
                      style: Theme.of(dialogContext).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '운영에 필요한 기본 틀을 한 번에 생성합니다.',
                      style: Theme.of(dialogContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: NestColors.deepWood.withValues(alpha: 0.72),
                          ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _homeschoolController,
                      decoration: const InputDecoration(labelText: '홈스쿨 이름'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '필수값입니다.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _termController,
                      decoration: const InputDecoration(labelText: '학기 이름'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '필수값입니다.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _startDateController,
                            decoration: const InputDecoration(
                              labelText: '시작일 (YYYY-MM-DD)',
                            ),
                            validator: _validateDate,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _endDateController,
                            decoration: const InputDecoration(
                              labelText: '종료일 (YYYY-MM-DD)',
                            ),
                            validator: _validateDate,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _classController,
                      decoration: const InputDecoration(labelText: '반 이름'),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? '필수값입니다.'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _courseController,
                      decoration: const InputDecoration(
                        labelText: '기본 과목 (콤마 구분)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: controller.isBusy
                              ? null
                              : () => Navigator.of(dialogContext).pop(),
                          child: const Text('닫기'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: controller.isBusy
                              ? null
                              : () async {
                                  final ok = await _submitBootstrap();
                                  if (!ok || !dialogContext.mounted) {
                                    return;
                                  }
                                  Navigator.of(dialogContext).pop();
                                },
                          icon: const Icon(Icons.auto_awesome),
                          label: const Text('홈스쿨 개설하기'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _searchHomeschools() async {
    final query = _joinSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _joinSearchResults = const [];
        _joinSearchMessage = '검색어를 입력해주세요.';
      });
      return;
    }

    setState(() {
      _joinSearching = true;
      _joinSearchMessage = null;
    });

    try {
      final rows = await widget.controller.searchHomeschoolDirectory(
        query: query,
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _joinSearchResults = rows;
        _joinSearchMessage = rows.isEmpty
            ? '검색 결과가 없습니다. 다른 키워드로 시도해보세요.'
            : null;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _joinSearchMessage = widget.controller.statusMessage;
      });
    } finally {
      if (mounted) {
        setState(() {
          _joinSearching = false;
        });
      }
    }
  }

  Future<void> _promptJoinRequest(HomeschoolDirectoryEntry entry) async {
    _joinRequestNoteController.clear();
    final note = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.name} 가입 요청',
              style: Theme.of(ctx).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              '관리자에게 전달할 메시지를 남길 수 있습니다. (선택)',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _joinRequestNoteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '요청 메시지',
                hintText: '예: 아이 2명이 함께 참여하려고 합니다.',
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('취소'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () =>
                      Navigator.of(ctx).pop(_joinRequestNoteController.text),
                  child: const Text('가입 요청 보내기'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (note == null) {
      return;
    }

    await _requestJoin(entry, note);
  }

  Future<void> _requestJoin(HomeschoolDirectoryEntry entry, String note) async {
    setState(() => _joinRequestingIds.add(entry.id));
    try {
      await widget.controller.requestJoinHomeschool(
        homeschoolId: entry.id,
        requestNote: note,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _joinSearchResults = _joinSearchResults
            .map(
              (row) => row.id == entry.id
                  ? row.copyWith(hasPendingRequest: true)
                  : row,
            )
            .toList(growable: false);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
    } finally {
      if (mounted) {
        setState(() => _joinRequestingIds.remove(entry.id));
      }
    }
  }

  String? _validateDate(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '필수값입니다.';
    }

    final parsed = DateTime.tryParse(value.trim());
    if (parsed == null) {
      return 'YYYY-MM-DD 형식으로 입력하세요.';
    }

    return null;
  }

  Widget _buildAdminSetupFlowCard(ThemeData theme, NestController controller) {
    final steps = _setupSteps(controller);
    final completedCount = steps.where((step) => step.completed).length;
    _SetupStep? nextStep;
    for (final step in steps) {
      if (!step.completed && step.enabled) {
        nextStep = step;
        break;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('학기 설정 가이드', style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '관리자는 순서대로 진행하면 홈스쿨 운영 틀을 빠르게 완성할 수 있습니다.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: steps.isEmpty ? 0 : completedCount / steps.length,
                color: NestColors.dustyRose,
                backgroundColor: NestColors.roseMist,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '완료 $completedCount / ${steps.length}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            ...steps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SetupStepTile(
                  step: step,
                  onOpen: widget.onRequestTabChange == null || !step.enabled
                      ? null
                      : () => widget.onRequestTabChange!.call(step.targetTab),
                ),
              ),
            ),
            if (nextStep != null) ...[
              const SizedBox(height: 4),
              Builder(
                builder: (context) {
                  final actionableStep = nextStep!;
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: widget.onRequestTabChange == null
                          ? null
                          : () => widget.onRequestTabChange!.call(
                              actionableStep.targetTab,
                            ),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(
                        '다음 단계: ${actionableStep.order}. ${actionableStep.title}',
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<_SetupStep> _setupSteps(NestController controller) {
    final hasHomeschool = controller.selectedHomeschoolId != null;
    final hasTerm = controller.selectedTermId != null;
    final hasClass = controller.classGroups.isNotEmpty;
    final hasCourses = controller.courses.isNotEmpty;
    final hasSlots = controller.timeSlots.isNotEmpty;

    return [
      _SetupStep(
        order: 1,
        title: '가정 관리',
        description: '가정을 만들고 아이를 등록합니다.',
        targetTab: '학기 설정',
        actionLabel: '가정/아이 설정 열기',
        completed:
            controller.families.isNotEmpty && controller.children.isNotEmpty,
        enabled: hasHomeschool,
      ),
      _SetupStep(
        order: 2,
        title: '반 관리',
        description: '반을 만들고 아이를 반에 배정합니다.',
        targetTab: '학기 설정',
        actionLabel: '반/배정 설정 열기',
        completed:
            controller.classGroups.isNotEmpty &&
            controller.classEnrollments.isNotEmpty,
        enabled: hasTerm,
      ),
      _SetupStep(
        order: 3,
        title: '과목 관리',
        description: '과목을 준비하고 시간표에서 반에 배정합니다.',
        targetTab: '학기 설정',
        actionLabel: '과목/수업 편성 열기',
        completed: hasCourses && hasClass,
        enabled: hasHomeschool,
      ),
      _SetupStep(
        order: 4,
        title: '시간표 관리',
        description: '이번 학기의 시간표를 생성/보정하고 확정합니다.',
        targetTab: '시간표',
        actionLabel: '시간표 관리 열기',
        completed: controller.sessions.isNotEmpty,
        enabled: hasTerm && hasClass && hasCourses && hasSlots,
      ),
    ];
  }

  Future<bool> _submitBootstrap() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return false;
    }

    try {
      await widget.controller.bootstrapFrame(
        homeschoolName: _homeschoolController.text,
        termName: _termController.text,
        startDate: _startDateController.text,
        endDate: _endDateController.text,
        className: _classController.text,
        coursesCsv: _courseController.text,
      );

      if (!mounted) {
        return true;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
      return true;
    } catch (_) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(widget.controller.statusMessage)));
      return false;
    }
  }
}

class _PendingInvitesCard extends StatelessWidget {
  const _PendingInvitesCard({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pending =
        controller.pendingInvites
            .where((invite) => invite.canAccept)
            .toList(growable: false)
          ..sort((a, b) {
            final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
            final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
            return right.compareTo(left);
          });

    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NestColors.creamyWhite,
            NestColors.roseMist.withValues(alpha: 0.55),
          ],
        ),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: NestColors.dustyRose.withValues(alpha: 0.22),
                foregroundColor: NestColors.deepWood,
                child: const Icon(Icons.mail_rounded, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('대기 중 초대', style: theme.textTheme.titleLarge),
              ),
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.confirmation_num_outlined, size: 16),
                label: Text('${pending.length}건'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '홈스쿨 관리자에게 받은 초대를 수락하면 바로 멤버십이 활성화됩니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 14),
          ...pending.map(
            (invite) => _InviteItem(controller: controller, invite: invite),
          ),
        ],
      ),
    );
  }
}

class _InviteMetaChip extends StatelessWidget {
  const _InviteMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.white.withValues(alpha: 0.72),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: NestColors.deepWood),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: NestColors.deepWood,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteItem extends StatelessWidget {
  const _InviteItem({required this.controller, required this.invite});

  final NestController controller;
  final HomeschoolInvite invite;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final created = invite.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(invite.createdAt!);
    final expires = invite.expiresAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd').format(invite.expiresAt!);
    final schoolName = invite.homeschoolName == 'Unknown Homeschool'
        ? '홈스쿨 이름 확인 중'
        : invite.homeschoolName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, NestColors.creamyWhite],
          ),
          border: Border.all(color: NestColors.roseMist),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.card_membership_rounded,
                  color: NestColors.dustyRose,
                ),
                const SizedBox(width: 8),
                Text(
                  '홈스쿨 초대장',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: NestColors.deepWood,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              schoolName,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: NestColors.deepWood,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InviteMetaChip(icon: Icons.badge_outlined, label: invite.role),
                _InviteMetaChip(
                  icon: Icons.event_available_outlined,
                  label: '만료 $expires',
                ),
                _InviteMetaChip(
                  icon: Icons.schedule_outlined,
                  label: '발송 $created',
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              height: 1,
              color: NestColors.roseMist,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () async {
                        try {
                          await controller.acceptPendingInvite(
                            invite.inviteToken,
                          );
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(controller.statusMessage)),
                          );
                        } catch (_) {
                          if (!context.mounted) {
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(controller.statusMessage)),
                          );
                        }
                      },
                icon: const Icon(Icons.mark_email_read_outlined),
                label: const Text('이 초대 수락하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: NestColors.roseMist,
              foregroundColor: NestColors.deepWood,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 2),
                  Text(value, style: theme.textTheme.titleLarge),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupStep {
  const _SetupStep({
    required this.order,
    required this.title,
    required this.description,
    required this.targetTab,
    required this.actionLabel,
    required this.completed,
    required this.enabled,
  });

  final int order;
  final String title;
  final String description;
  final String targetTab;
  final String actionLabel;
  final bool completed;
  final bool enabled;
}

class _SetupStepTile extends StatelessWidget {
  const _SetupStepTile({required this.step, this.onOpen});

  final _SetupStep step;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final isDone = step.completed;
    final active = step.enabled;
    final borderColor = isDone ? Colors.green.shade400 : NestColors.roseMist;
    final badgeBg = isDone ? Colors.green.shade50 : NestColors.creamyWhite;
    final badgeFg = isDone ? Colors.green.shade800 : NestColors.deepWood;
    final titleStyle = Theme.of(context).textTheme.titleMedium;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        color: active ? Colors.white : Colors.grey.shade100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isDone
                    ? Colors.green.shade600
                    : NestColors.dustyRose,
                foregroundColor: Colors.white,
                child: isDone
                    ? const Icon(Icons.check, size: 14)
                    : Text(
                        '${step.order}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text('${step.order}. ${step.title}', style: titleStyle),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isDone ? Colors.green.shade200 : NestColors.roseMist,
                  ),
                ),
                child: Text(
                  isDone ? '완료' : (active ? '진행 필요' : '선행 단계 필요'),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: badgeFg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            step.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: NestColors.deepWood.withValues(
                alpha: active ? 0.78 : 0.52,
              ),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: active ? onOpen : null,
            icon: const Icon(Icons.open_in_new, size: 16),
            label: Text(step.actionLabel),
          ),
        ],
      ),
    );
  }
}

class _OnboardingJoinResultTile extends StatelessWidget {
  const _OnboardingJoinResultTile({
    required this.entry,
    required this.isRequesting,
    required this.onRequest,
  });

  final HomeschoolDirectoryEntry entry;
  final bool isRequesting;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    final memberLabel = '활성 구성원 ${entry.activeMemberCount}명';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: NestColors.roseMist,
            foregroundColor: NestColors.deepWood,
            child: const Icon(Icons.school_outlined, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$memberLabel · ${entry.timezone}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          if (entry.hasPendingRequest)
            Chip(
              label: const Text('요청 대기중'),
              avatar: const Icon(Icons.hourglass_top, size: 16),
              visualDensity: VisualDensity.compact,
            )
          else
            FilledButton.tonal(
              onPressed: isRequesting ? null : onRequest,
              child: isRequesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('가입 요청'),
            ),
        ],
      ),
    );
  }
}

class _OnboardingOption extends StatelessWidget {
  const _OnboardingOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.highlight,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? NestColors.dustyRose : NestColors.roseMist,
          width: highlight ? 2 : 1,
        ),
        color: highlight
            ? NestColors.roseMist.withValues(alpha: 0.3)
            : Colors.white,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: NestColors.roseMist,
            foregroundColor: NestColors.deepWood,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
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
