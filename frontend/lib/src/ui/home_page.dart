import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_config.dart';
import '../state/nest_controller.dart';
import 'models/child_class_bundle.dart';
import 'nest_theme.dart';
import 'tabs/community_feed_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/family_admin_tab.dart';
import 'tabs/gallery_tab.dart';
import 'tabs/parent_home_tab.dart';
import 'tabs/parent_timetable_tab.dart';
import 'tabs/profile_settings_tab.dart';
import 'tabs/system_admin_tab.dart';
import 'tabs/teacher_hub_tab.dart';
import 'tabs/timetable_tab.dart';
import 'widgets/nest_motion.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final NestController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _hasUnsavedScheduleChanges = false;
  DateTime? _lastBackPress;

  // ── Parent child selector state (shared across parent tabs) ──
  String? _selectedChildId;
  String? _lastScheduledChildLoadId;
  Map<String, ChildClassBundle> _childClassBundles = const {};
  bool _isLoadingChildClasses = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // If not on the first tab, go back to the first tab.
        if (_currentIndex > 0) {
          setState(() => _currentIndex = 0);
          return;
        }
        // Double-tap back to exit.
        final now = DateTime.now();
        if (_lastBackPress != null &&
            now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
          return;
        }
        _lastBackPress = now;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('한 번 더 누르면 앱을 종료합니다'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      child: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        // Keep child selector in sync when controller data changes.
        if (widget.controller.isParentView) {
          _syncSelectedChild(widget.controller);
        }

        final width = MediaQuery.sizeOf(context).width;
        final desktopLike = width >= 1080;
        final tabs = _buildTabs(widget.controller, isMobileLike: !desktopLike);
        final labels = tabs.map((tab) => tab.label).toList(growable: false);

        final safeIndex = _currentIndex >= tabs.length ? 0 : _currentIndex;
        if (safeIndex != _currentIndex) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _currentIndex = safeIndex;
            });
          });
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              const _WarmScenery(),
              desktopLike
                  ? SafeArea(
                      child: _DesktopScaffold(
                        currentIndex: safeIndex,
                        onSelectIndex: (value) => _handleTabSelection(
                          nextIndex: value,
                          tabs: tabs,
                          currentIndex: safeIndex,
                        ),
                        labels: labels,
                        controller: widget.controller,
                        tabLabel: tabs[safeIndex].label,
                        tab: tabs[safeIndex].page,
                        onLogout: _handleLogout,
                        onRefresh: _handleRefresh,
                        onSelectHomeschool: _handleHomeschoolChange,
                        onSelectTerm: _handleTermChange,
                        onSelectClassGroup: _handleClassGroupChange,
                        onSelectViewRole: _handleViewRoleChange,
                        selectedChildId: _selectedChildId,
                        onSelectChild: _handleChildChange,
                        onOpenParentAnnouncements: _openParentAnnouncementsTab,
                      ),
                    )
                  : _MobileScaffold(
                      currentIndex: safeIndex,
                      onSelectIndex: (value) => _handleTabSelection(
                        nextIndex: value,
                        tabs: tabs,
                        currentIndex: safeIndex,
                      ),
                      labels: labels,
                      controller: widget.controller,
                      tabLabel: tabs[safeIndex].label,
                      tab: tabs[safeIndex].page,
                      onLogout: _handleLogout,
                      onRefresh: _handleRefresh,
                      onSelectHomeschool: _handleHomeschoolChange,
                      onSelectTerm: _handleTermChange,
                      onSelectClassGroup: _handleClassGroupChange,
                      onSelectViewRole: _handleViewRoleChange,
                      selectedChildId: _selectedChildId,
                      onSelectChild: _handleChildChange,
                      onOpenParentAnnouncements: _openParentAnnouncementsTab,
                    ),
            ],
          ),
        );
      },
    ),
    );
  }

  List<_TabSpec> _buildTabs(
    NestController controller, {
    required bool isMobileLike,
  }) {
    // ── No membership: onboarding-only dashboard ──
    if (controller.memberships.isEmpty) {
      return [
        _TabSpec(
          label: '대시보드',
          page: DashboardTab(
            controller: controller,
            onRequestTabChange: _navigateToTabLabel,
          ),
        ),
      ];
    }

    if (controller.isAdminLike) {
      return [
        _TabSpec(
          label: '대시보드',
          page: DashboardTab(
            controller: controller,
            onRequestTabChange: _navigateToTabLabel,
          ),
        ),
        _TabSpec(
          label: '학기 설정',
          page: FamilyAdminTab(controller: controller),
        ),
        _TabSpec(
          label: '시간표',
          page: TimetableTab(
            controller: controller,
            onDirtyChanged: _handleScheduleDirtyChanged,
          ),
        ),
        _TabSpec(
          label: '시스템',
          page: SystemAdminTab(controller: controller),
        ),
      ];
    }

    // ── Parent view: dashboard + timetable + SNS ──
    if (controller.isParentView) {
      return [
        _TabSpec(
          label: '대시보드',
          page: ParentHomeTab(
            controller: controller,
            selectedChildId: _selectedChildId,
            childClassBundles: _childClassBundles,
            isLoadingChildClasses: _isLoadingChildClasses,
          ),
        ),
        _TabSpec(
          label: '시간표',
          page: ParentTimetableTab(
            controller: controller,
            selectedChildId: _selectedChildId,
            childClassBundles: _childClassBundles,
            isLoadingChildClasses: _isLoadingChildClasses,
          ),
        ),
        _TabSpec(
          label: 'SNS',
          page: CommunityFeedTab(
            controller: controller,
            title: '커뮤니티',
          ),
        ),
        _TabSpec(
          label: '설정',
          page: ProfileSettingsTab(controller: controller),
        ),
      ];
    }

    // ── Teacher / other non-admin view ──
    final tabs = <_TabSpec>[
      if (controller.isTeacherView)
        _TabSpec(
          label: '교사 허브',
          page: TeacherHubTab(controller: controller),
        ),
      _TabSpec(
        label: '시간표',
        page: TimetableTab(
          controller: controller,
          onDirtyChanged: _handleScheduleDirtyChanged,
        ),
      ),
      if (!isMobileLike)
        _TabSpec(
          label: '갤러리',
          page: GalleryTab(controller: controller),
        ),
    ];
    tabs.add(
      _TabSpec(
        label: isMobileLike ? 'SNS' : '커뮤니티',
        page: CommunityFeedTab(
          controller: controller,
          title: '커뮤니티',
        ),
      ),
    );
    tabs.add(
      _TabSpec(
        label: '설정',
        page: ProfileSettingsTab(controller: controller),
      ),
    );

    return tabs;
  }

  // ── Parent child selector helpers ──

  void _syncSelectedChild(NestController controller) {
    final children = controller.myChildren.toList(growable: false);
    final previous = _selectedChildId;
    final firstId = children.firstOrNull?.id;
    final stillValid =
        previous != null && children.any((child) => child.id == previous);

    if (!stillValid) {
      _selectedChildId = firstId;
      _childClassBundles = const {};
      _lastScheduledChildLoadId = null;
    }

    final selectedId = _selectedChildId;
    if (selectedId == null || selectedId.isEmpty) return;
    if (_lastScheduledChildLoadId == selectedId) return;

    _lastScheduledChildLoadId = selectedId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadChildClassBundles(selectedId);
    });
  }

  void _handleChildChange(String? childId) {
    setState(() {
      _selectedChildId = childId;
      _childClassBundles = const {};
      _lastScheduledChildLoadId = null;
    });
  }

  void _handleScheduleDirtyChanged(bool dirty) {
    if (!mounted || _hasUnsavedScheduleChanges == dirty) {
      return;
    }
    setState(() {
      _hasUnsavedScheduleChanges = dirty;
    });
  }

  Future<void> _handleTabSelection({
    required int nextIndex,
    required List<_TabSpec> tabs,
    required int currentIndex,
  }) async {
    if (nextIndex == currentIndex || !mounted) {
      return;
    }

    final leavingSchedule =
        _isScheduleTabLabel(tabs[currentIndex].label) &&
        !_isScheduleTabLabel(tabs[nextIndex].label);

    if (leavingSchedule && _hasUnsavedScheduleChanges) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('수정사항 경고'),
          content: const Text(
            '시간표 탭에 저장되지 않은 수정사항이 있습니다. 탭을 이동하면 현재 수정사항이 사라집니다. 이동할까요?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('이동'),
            ),
          ],
        ),
      );

      if (discard != true || !mounted) {
        return;
      }

      setState(() {
        _hasUnsavedScheduleChanges = false;
      });
    }

    if (!mounted) {
      return;
    }

    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = nextIndex;
    });
  }

  bool _isScheduleTabLabel(String label) {
    final normalized = label.trim().toLowerCase();
    return normalized == 'schedule' ||
        normalized == 'timetable' ||
        label.trim() == '시간표';
  }

  Future<void> _loadChildClassBundles(String childId) async {
    if (_isLoadingChildClasses) return;

    final controller = widget.controller;
    setState(() => _isLoadingChildClasses = true);

    try {
      final classGroups =
          controller.classGroupsForChild(childId).toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name));

      final allAnnouncements = await controller
          .fetchAnnouncementsForHomeschool();
      final bundleMap = <String, ChildClassBundle>{};

      for (final classGroup in classGroups) {
        final sessions = await controller.fetchSessionsForClassGroup(
          classGroupId: classGroup.id,
        );
        final sessionIds = sessions
            .map((s) => s.id)
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
        final assignments = await controller
            .fetchSessionTeacherAssignmentsForSessions(
              classSessionIds: sessionIds,
            );
        final classAnnouncements = allAnnouncements
            .where(
              (row) =>
                  row.classGroupId == null || row.classGroupId == classGroup.id,
            )
            .toList(growable: false);

        bundleMap[classGroup.id] = ChildClassBundle(
          classGroup: classGroup,
          sessions: sessions,
          assignments: assignments,
          announcements: classAnnouncements,
        );
      }

      if (!mounted) return;
      setState(() => _childClassBundles = bundleMap);
    } catch (_) {
      // Keep existing data on failure.
    } finally {
      if (mounted) setState(() => _isLoadingChildClasses = false);
    }
  }

  Future<void> _handleLogout() async {
    try {
      await widget.controller.signOut();
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _handleRefresh() async {
    try {
      await widget.controller.refreshAll();
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _handleHomeschoolChange(String? value) async {
    try {
      await widget.controller.changeHomeschool(value);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _handleTermChange(String? value) async {
    try {
      await widget.controller.changeTerm(value);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _handleClassGroupChange(String? value) async {
    try {
      await widget.controller.changeClassGroup(value);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _handleViewRoleChange(String? value) async {
    try {
      await widget.controller.changeViewRole(value);
      if (!mounted) {
        return;
      }
      setState(() {
        _currentIndex = 0;
      });
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  void _navigateToTabLabel(String label) {
    final tabs = _buildTabs(
      widget.controller,
      isMobileLike: MediaQuery.sizeOf(context).width < 1080,
    );
    final normalizedTarget = _normalizeTabLabel(label);
    final targetIndex = tabs.indexWhere(
      (tab) => _normalizeTabLabel(tab.label) == normalizedTarget,
    );
    if (targetIndex < 0 || !mounted) {
      return;
    }

    setState(() {
      _currentIndex = targetIndex;
    });
  }

  void _openParentAnnouncementsTab() {
    _navigateToTabLabel('소식');
  }

  String _normalizeTabLabel(String label) {
    final trimmed = label.trim();
    return switch (trimmed) {
      'Dashboard' => '대시보드',
      'Term Setup' => '학기 설정',
      'Schedule' => '시간표',
      'Timetable' => '시간표',
      'System' => '시스템',
      'Teacher Hub' => '교사 허브',
      'Gallery' => '갤러리',
      'Community' => '커뮤니티',
      'SNS' => 'SNS',
      '커뮤니티' => 'SNS',
      _ => trimmed,
    };
  }

  void _showMessage(String message) {
    if (!mounted || message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TabSpec {
  const _TabSpec({required this.label, required this.page});

  final String label;
  final Widget page;
}

class _DesktopScaffold extends StatelessWidget {
  const _DesktopScaffold({
    required this.currentIndex,
    required this.onSelectIndex,
    required this.labels,
    required this.controller,
    required this.tabLabel,
    required this.tab,
    required this.onLogout,
    required this.onRefresh,
    required this.onSelectHomeschool,
    required this.onSelectTerm,
    required this.onSelectClassGroup,
    required this.onSelectViewRole,
    required this.selectedChildId,
    required this.onSelectChild,
    required this.onOpenParentAnnouncements,
  });

  final int currentIndex;
  final ValueChanged<int> onSelectIndex;
  final List<String> labels;
  final NestController controller;
  final String tabLabel;
  final Widget tab;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String? value) onSelectHomeschool;
  final Future<void> Function(String? value) onSelectTerm;
  final Future<void> Function(String? value) onSelectClassGroup;
  final Future<void> Function(String? value) onSelectViewRole;
  final String? selectedChildId;
  final ValueChanged<String?> onSelectChild;
  final VoidCallback onOpenParentAnnouncements;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 8, 16),
          child: NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onSelectIndex,
            labelType: NavigationRailLabelType.all,
            useIndicator: true,
            backgroundColor: Colors.white.withValues(alpha: 0.7),
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelectIndex(0),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 68,
                      height: 68,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            destinations: labels
                .map(
                  (label) => NavigationRailDestination(
                    icon: _iconForLabel(label, filled: false),
                    selectedIcon: _iconForLabel(label, filled: true),
                    label: Text(label),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            child: _MainPanel(
              controller: controller,
              tabLabel: tabLabel,
              tab: tab,
              onLogout: onLogout,
              onRefresh: onRefresh,
              onSelectHomeschool: onSelectHomeschool,
              onSelectTerm: onSelectTerm,
              onSelectClassGroup: onSelectClassGroup,
              onSelectViewRole: onSelectViewRole,
              selectedChildId: selectedChildId,
              onSelectChild: onSelectChild,
              onOpenParentAnnouncements: onOpenParentAnnouncements,
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileScaffold extends StatefulWidget {
  const _MobileScaffold({
    required this.currentIndex,
    required this.onSelectIndex,
    required this.labels,
    required this.controller,
    required this.tabLabel,
    required this.tab,
    required this.onLogout,
    required this.onRefresh,
    required this.onSelectHomeschool,
    required this.onSelectTerm,
    required this.onSelectClassGroup,
    required this.onSelectViewRole,
    required this.selectedChildId,
    required this.onSelectChild,
    required this.onOpenParentAnnouncements,
  });

  final int currentIndex;
  final ValueChanged<int> onSelectIndex;
  final List<String> labels;
  final NestController controller;
  final String tabLabel;
  final Widget tab;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String? value) onSelectHomeschool;
  final Future<void> Function(String? value) onSelectTerm;
  final Future<void> Function(String? value) onSelectClassGroup;
  final Future<void> Function(String? value) onSelectViewRole;
  final String? selectedChildId;
  final ValueChanged<String?> onSelectChild;
  final VoidCallback onOpenParentAnnouncements;

  @override
  State<_MobileScaffold> createState() => _MobileScaffoldState();
}

class _MobileScaffoldState extends State<_MobileScaffold> {
  String _displayName(NestController controller) {
    final fromDirectory = controller.findMemberDisplayName(controller.user?.id);
    if (fromDirectory.trim().isNotEmpty &&
        fromDirectory != controller.user?.id) {
      return fromDirectory;
    }

    final metadata = controller.user?.userMetadata ?? const <String, dynamic>{};
    final metadataName = metadata['full_name'] ?? metadata['name'];
    if (metadataName is String && metadataName.trim().isNotEmpty) {
      return metadataName.trim();
    }

    final email = controller.user?.email ?? '';
    if (email.contains('@')) {
      return email.split('@').first;
    }
    return '사용자';
  }

  String _panelTitle(NestController controller) {
    if (controller.isAdminLike) {
      return '관리자';
    }
    if (controller.isTeacherView) {
      return '교사';
    }
    if (controller.isParentView) {
      return '학부모';
    }
    return 'Nest School';
  }

  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildParentChildChip(NestController controller) {
    if (!controller.isParentView) {
      return const SizedBox.shrink();
    }

    final children = controller.myChildren.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    if (children.isEmpty) {
      return Chip(
        label: const Text('내 아이 미연동'),
        avatar: const Icon(Icons.child_care_outlined, size: 14),
        visualDensity: VisualDensity.compact,
      );
    }

    final selected = children
        .where((child) => child.id == widget.selectedChildId)
        .firstOrNull;
    final label = selected == null
        ? '아이 선택'
        : '${selected.name} (${selected.familyName})';

    return PopupMenuButton<String>(
      tooltip: '아이 선택',
      onSelected: widget.onSelectChild,
      itemBuilder: (context) => children
          .map(
            (child) => PopupMenuItem<String>(
              value: child.id,
              child: Row(
                children: [
                  Icon(
                    child.id == widget.selectedChildId
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${child.name} (${child.familyName})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Chip(
        label: Text(label, overflow: TextOverflow.ellipsis),
        avatar: const Icon(Icons.child_friendly_outlined, size: 14),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Future<void> _openContextSheet() async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => _MobileSettingsPage(
          controller: widget.controller,
          selectedChildId: widget.selectedChildId,
          onSelectChild: widget.onSelectChild,
          onSelectHomeschool: widget.onSelectHomeschool,
          onSelectTerm: widget.onSelectTerm,
          onSelectClassGroup: widget.onSelectClassGroup,
          onSelectViewRole: widget.onSelectViewRole,
          onRefresh: widget.onRefresh,
          onLogout: widget.onLogout,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final displayName = _displayName(controller);
    final panelTitle = _panelTitle(controller);
    final parentChildChip = _buildParentChildChip(controller);

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NestColors.roseMist),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/logo_square.png',
                              width: 42,
                              height: 42,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$panelTitle · ${widget.tabLabel}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium,
                                ),
                                Text(
                                  '$displayName 님',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: NestColors.deepWood.withValues(
                                      alpha: 0.72,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: '빠른 메뉴',
                            onSelected: (action) async {
                              if (action == 'settings') {
                                await _openContextSheet();
                                return;
                              }
                              if (action == 'info') {
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('역할 안내'),
                                    content: Text(
                                      controller.isParentView
                                          ? '부모 뷰는 내 아이 기준 정보를 보여줍니다.'
                                          : controller.isTeacherView
                                          ? '교사 뷰는 담당 수업과 아이 상태 중심입니다.'
                                          : '관리자 뷰는 전체 운영 설정을 관리합니다.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                        child: const Text('확인'),
                                      ),
                                    ],
                                  ),
                                );
                                return;
                              }
                              try {
                                if (action == 'refresh') {
                                  await widget.onRefresh();
                                } else if (action == 'logout') {
                                  await widget.onLogout();
                                }
                              } catch (_) {
                                _showMessage(controller.statusMessage);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'settings',
                                child: ListTile(
                                  leading: Icon(Icons.tune),
                                  title: Text('설정'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'info',
                                child: ListTile(
                                  leading: Icon(Icons.info_outline),
                                  title: Text('역할 안내'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuDivider(),
                              PopupMenuItem<String>(
                                value: 'refresh',
                                child: ListTile(
                                  leading: Icon(Icons.refresh),
                                  title: Text('새로고침'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'logout',
                                child: ListTile(
                                  leading: Icon(Icons.logout),
                                  title: Text('로그아웃'),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Chip(
                              label: Text(
                                _labelForRole(controller.currentRole ?? '-'),
                              ),
                              avatar: const Icon(
                                Icons.shield_outlined,
                                size: 14,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                            if (parentChildChip is! SizedBox) ...[
                              const SizedBox(width: 6),
                              parentChildChip,
                            ],
                            const SizedBox(width: 6),
                            ActionChip(
                              label: const Text('설정'),
                              avatar: const Icon(Icons.tune, size: 14),
                              visualDensity: VisualDensity.compact,
                              onPressed: controller.isBusy
                                  ? null
                                  : _openContextSheet,
                            ),
                          ],
                        ),
                      ),
                      if (controller.isBusy)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: NestColors.roseMist),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) =>
                                  nestFadeSlideTransition(
                                    child,
                                    animation,
                                    beginOffset: const Offset(0.02, 0),
                                  ),
                              child: KeyedSubtree(
                                key: ValueKey<String>(
                                  'mobile-tab-${widget.tabLabel}',
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: widget.tab,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: NestBusyOverlay(visible: controller.isBusy),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            border: Border(
              top: BorderSide(
                color: NestColors.roseMist.withValues(alpha: 0.9),
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: NavigationBar(
              selectedIndex: widget.currentIndex,
              onDestinationSelected: widget.onSelectIndex,
              height: 68,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: widget.labels
                  .map(
                    (label) => NavigationDestination(
                      icon: _iconForLabel(label, filled: false),
                      selectedIcon: _iconForLabel(label, filled: true),
                      label: label,
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileSettingsPage extends StatefulWidget {
  const _MobileSettingsPage({
    required this.controller,
    required this.selectedChildId,
    required this.onSelectChild,
    required this.onSelectHomeschool,
    required this.onSelectTerm,
    required this.onSelectClassGroup,
    required this.onSelectViewRole,
    required this.onRefresh,
    required this.onLogout,
  });

  final NestController controller;
  final String? selectedChildId;
  final ValueChanged<String?> onSelectChild;
  final Future<void> Function(String? value) onSelectHomeschool;
  final Future<void> Function(String? value) onSelectTerm;
  final Future<void> Function(String? value) onSelectClassGroup;
  final Future<void> Function(String? value) onSelectViewRole;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLogout;

  @override
  State<_MobileSettingsPage> createState() => _MobileSettingsPageState();
}

class _MobileSettingsPageState extends State<_MobileSettingsPage> {
  void _showMessage(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _roleLabel(String? role) {
    switch (role) {
      case 'HOMESCHOOL_ADMIN':
        return '홈스쿨 관리자';
      case 'PARENT':
        return '학부모';
      case 'TEACHER':
        return '교사';
      case 'GUEST_TEACHER':
        return '게스트 교사';
      case 'STAFF':
        return '스태프';
      default:
        return role ?? '-';
    }
  }

  String _displayName(NestController controller) {
    final fromDirectory = controller.findMemberDisplayName(controller.user?.id);
    if (fromDirectory.trim().isNotEmpty &&
        fromDirectory != controller.user?.id) {
      return fromDirectory;
    }
    final metadata = controller.user?.userMetadata ?? const <String, dynamic>{};
    final metadataName = metadata['full_name'] ?? metadata['name'];
    if (metadataName is String && metadataName.trim().isNotEmpty) {
      return metadataName.trim();
    }
    final email = controller.user?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return '사용자';
  }

  Future<void> _showNicknameEditDialog(NestController controller) async {
    final current = _displayName(controller);
    final textController = TextEditingController(text: current);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('닉네임 변경'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: '닉네임',
            hintText: '앱에서 표시될 이름',
            prefixIcon: Icon(Icons.person_outlined, size: 20),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(textController.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (result == null || result.isEmpty || result == current) return;
    try {
      await controller.updateDisplayName(result);
      if (mounted) _showMessage('닉네임이 변경되었습니다.');
    } catch (_) {
      if (mounted) _showMessage(controller.statusMessage);
    }
  }

  void _showLegalDialog(BuildContext context, {required String title, required String content}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final children = controller.myChildren.toList(growable: false)
          ..sort((a, b) => a.name.compareTo(b.name));
        final childValue =
            children.any((child) => child.id == widget.selectedChildId)
            ? widget.selectedChildId
            : null;
        final parentTargets = controller.parentViewCandidateUserIds;
        final teacherTargets = controller.teacherViewCandidateProfiles;
        final parentTargetValue =
            parentTargets.contains(controller.activeParentViewTargetUserId)
            ? controller.activeParentViewTargetUserId
            : null;
        final teacherTargetValue =
            teacherTargets.any(
              (row) => row.id == controller.activeTeacherViewTargetProfileId,
            )
            ? controller.activeTeacherViewTargetProfileId
            : null;

        return Scaffold(
          appBar: AppBar(title: const Text('모바일 설정')),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ContextSelector(
                    controller: controller,
                    onSelectHomeschool: widget.onSelectHomeschool,
                    onSelectTerm: widget.onSelectTerm,
                    onSelectClassGroup: widget.onSelectClassGroup,
                    onSelectViewRole: widget.onSelectViewRole,
                  ),
                  const SizedBox(height: 12),
                  if (controller.isParentView) ...[
                    Text(
                      '아이 선택',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (children.isEmpty)
                      Text(
                        '연동된 아이가 없습니다.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      DropdownButtonFormField<String>(
                        initialValue: childValue,
                        isExpanded: true,
                        items: children
                            .map(
                              (child) => DropdownMenuItem<String>(
                                value: child.id,
                                child: Text(
                                  '${child.name} (${child.familyName})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          widget.onSelectChild(value);
                          setState(() {});
                        },
                        decoration: const InputDecoration(labelText: '내 아이'),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (controller.isParentView &&
                      controller.hasAdminLikeMembershipInSelectedHomeschool &&
                      parentTargets.isNotEmpty) ...[
                    Text(
                      '관리자 부모 대상',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: parentTargetValue,
                      isExpanded: true,
                      items: parentTargets
                          .map(
                            (userId) => DropdownMenuItem<String>(
                              value: userId,
                              child: Text(
                                controller.findMemberDisplayName(userId),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        unawaited(
                          controller
                              .selectParentViewTargetUserId(value)
                              .catchError((_) {
                                _showMessage(controller.statusMessage);
                              })
                              .whenComplete(() => setState(() {})),
                        );
                      },
                      decoration: const InputDecoration(labelText: '부모 계정 대상'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (controller.isTeacherView &&
                      controller.hasAdminLikeMembershipInSelectedHomeschool &&
                      teacherTargets.isNotEmpty) ...[
                    Text(
                      '관리자 교사 대상',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: teacherTargetValue,
                      isExpanded: true,
                      items: teacherTargets
                          .map(
                            (profile) => DropdownMenuItem<String>(
                              value: profile.id,
                              child: Text(
                                profile.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }
                        unawaited(
                          controller
                              .selectTeacherViewTargetProfileId(value)
                              .catchError((_) {
                                _showMessage(controller.statusMessage);
                              })
                              .whenComplete(() => setState(() {})),
                        );
                      },
                      decoration: const InputDecoration(labelText: '교사 프로필 대상'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: controller.isBusy
                              ? null
                              : () async {
                                  try {
                                    await widget.onRefresh();
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  } catch (_) {
                                    _showMessage(controller.statusMessage);
                                  }
                                },
                          icon: const Icon(Icons.refresh),
                          label: const Text('새로고침'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: controller.isBusy
                              ? null
                              : () async {
                                  Navigator.of(context).pop();
                                  try {
                                    await widget.onLogout();
                                  } catch (_) {
                                    _showMessage(controller.statusMessage);
                                  }
                                },
                          icon: const Icon(Icons.logout),
                          label: const Text('로그아웃'),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),
                  // ── Account info ──
                  Text(
                    '계정 정보',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 22,
                                backgroundColor: NestColors.roseMist,
                                child: Text(
                                  (controller.user?.email ?? '?')[0].toUpperCase(),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: NestColors.deepWood,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      controller.user?.email ?? '-',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      _roleLabel(controller.currentRole),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: NestColors.deepWood.withValues(alpha: 0.65),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              const Icon(Icons.person_outlined, size: 20, color: NestColors.deepWood),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _displayName(controller),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              TextButton.icon(
                                onPressed: controller.isBusy
                                    ? null
                                    : () => _showNicknameEditDialog(controller),
                                icon: const Icon(Icons.edit_outlined, size: 16),
                                label: const Text('변경'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 32),
                  // ── About & Legal ──
                  Text(
                    '앱 정보',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.info_outline, size: 20),
                          title: const Text('버전'),
                          trailing: Text(
                            'v${AppConfig.appVersion}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.description_outlined, size: 20),
                          title: const Text('이용약관'),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () => _showLegalDialog(
                            context,
                            title: '이용약관',
                            content: '이용약관은 앱 내 또는 공식 웹사이트에서 확인하실 수 있습니다.\n\n문의: contact@lionandthelab.com',
                          ),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.privacy_tip_outlined, size: 20),
                          title: const Text('개인정보처리방침'),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                          onTap: () => _showLegalDialog(
                            context,
                            title: '개인정보처리방침',
                            content: '개인정보처리방침은 앱 내 또는 공식 웹사이트에서 확인하실 수 있습니다.\n\n문의: contact@lionandthelab.com',
                          ),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        ListTile(
                          leading: const Icon(Icons.mail_outline, size: 20),
                          title: const Text('문의하기'),
                          subtitle: const Text('contact@lionandthelab.com'),
                          trailing: const Icon(Icons.chevron_right, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      '${AppConfig.appName} · ${AppConfig.brandLine}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '© 2026 Lion and the Lab',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MainPanel extends StatefulWidget {
  const _MainPanel({
    required this.controller,
    required this.tabLabel,
    required this.tab,
    required this.onLogout,
    required this.onRefresh,
    required this.onSelectHomeschool,
    required this.onSelectTerm,
    required this.onSelectClassGroup,
    required this.onSelectViewRole,
    required this.selectedChildId,
    required this.onSelectChild,
    required this.onOpenParentAnnouncements,
  });

  final NestController controller;
  final String tabLabel;
  final Widget tab;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String? value) onSelectHomeschool;
  final Future<void> Function(String? value) onSelectTerm;
  final Future<void> Function(String? value) onSelectClassGroup;
  final Future<void> Function(String? value) onSelectViewRole;
  final String? selectedChildId;
  final ValueChanged<String?> onSelectChild;
  final VoidCallback onOpenParentAnnouncements;

  @override
  State<_MainPanel> createState() => _MainPanelState();
}

class _MainPanelState extends State<_MainPanel> {
  Widget _buildParentChildSwitchButton(NestController controller) {
    if (!controller.isParentView) {
      return const SizedBox.shrink();
    }

    final children = controller.myChildren.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    if (children.isEmpty) {
      return Chip(
        label: const Text('내 아이 미연동'),
        avatar: const Icon(Icons.child_care_outlined, size: 14),
        visualDensity: VisualDensity.compact,
      );
    }

    final selected = children
        .where((child) => child.id == widget.selectedChildId)
        .firstOrNull;
    final label = selected == null
        ? '아이 선택'
        : '${selected.name} (${selected.familyName})';

    return PopupMenuButton<String>(
      tooltip: '아이 선택',
      onSelected: widget.onSelectChild,
      itemBuilder: (context) => children
          .map(
            (child) => PopupMenuItem<String>(
              value: child.id,
              child: Row(
                children: [
                  Icon(
                    child.id == widget.selectedChildId
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${child.name} (${child.familyName})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Chip(
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
        avatar: const Icon(Icons.child_friendly_outlined, size: 14),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildParentViewTargetSwitchButton(NestController controller) {
    if (!controller.isParentView ||
        !controller.hasAdminLikeMembershipInSelectedHomeschool) {
      return const SizedBox.shrink();
    }

    final candidates = controller.parentViewCandidateUserIds;
    if (candidates.isEmpty) {
      return Chip(
        label: const Text('부모 대상 없음'),
        avatar: const Icon(Icons.family_restroom_outlined, size: 14),
        visualDensity: VisualDensity.compact,
      );
    }

    final activeUserId = controller.activeParentViewTargetUserId;
    final activeLabel = controller.findMemberDisplayName(activeUserId);

    return PopupMenuButton<String>(
      tooltip: '부모 대상 전환',
      onSelected: (userId) async {
        try {
          await controller.selectParentViewTargetUserId(userId);
        } catch (_) {
          _showPanelMessage(controller.statusMessage);
        }
      },
      itemBuilder: (context) => candidates
          .map(
            (userId) => PopupMenuItem<String>(
              value: userId,
              child: Row(
                children: [
                  Icon(
                    userId == activeUserId
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      controller.findMemberDisplayName(userId),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Chip(
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text('부모: $activeLabel', overflow: TextOverflow.ellipsis),
        ),
        avatar: const Icon(Icons.family_restroom_outlined, size: 14),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  Widget _buildTeacherViewTargetSwitchButton(NestController controller) {
    if (!controller.isTeacherView ||
        !controller.hasAdminLikeMembershipInSelectedHomeschool) {
      return const SizedBox.shrink();
    }

    final candidates = controller.teacherViewCandidateProfiles;
    if (candidates.isEmpty) {
      return Chip(
        label: const Text('교사 대상 없음'),
        avatar: const Icon(Icons.school_outlined, size: 14),
        visualDensity: VisualDensity.compact,
      );
    }

    final activeTeacherId = controller.activeTeacherViewTargetProfileId;
    final activeLabel = activeTeacherId == null
        ? '선택'
        : controller.findTeacherName(activeTeacherId);

    return PopupMenuButton<String>(
      tooltip: '교사 대상 전환',
      onSelected: (teacherId) async {
        try {
          await controller.selectTeacherViewTargetProfileId(teacherId);
        } catch (_) {
          _showPanelMessage(controller.statusMessage);
        }
      },
      itemBuilder: (context) => candidates
          .map(
            (teacher) => PopupMenuItem<String>(
              value: teacher.id,
              child: Row(
                children: [
                  Icon(
                    teacher.id == activeTeacherId
                        ? Icons.check_circle
                        : Icons.circle_outlined,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      teacher.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
      child: Chip(
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text('교사: $activeLabel', overflow: TextOverflow.ellipsis),
        ),
        avatar: const Icon(Icons.school_outlined, size: 14),
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  void _showPanelMessage(String text) {
    if (!mounted || text.trim().isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _panelTitle(NestController controller) {
    if (controller.isAdminLike) {
      return '관리';
    }
    if (controller.isTeacherView) {
      return '교사';
    }
    if (controller.isParentView) {
      return '학부모';
    }
    return '홈';
  }

  String _displayName(NestController controller) {
    final fromDirectory = controller.findMemberDisplayName(controller.user?.id);
    if (fromDirectory.trim().isNotEmpty &&
        fromDirectory != controller.user?.id) {
      return fromDirectory;
    }

    final metadata = controller.user?.userMetadata ?? const <String, dynamic>{};
    final metadataName = metadata['full_name'] ?? metadata['name'];
    if (metadataName is String && metadataName.trim().isNotEmpty) {
      return metadataName.trim();
    }

    final email = controller.user?.email ?? '';
    if (email.contains('@')) {
      return email.split('@').first;
    }
    return '사용자';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final panelTitle = _panelTitle(controller);
    final displayName = _displayName(controller);

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.nest_cam_wired_stand, size: 20),
                const SizedBox(width: 4),
                Text(
                  panelTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _ContextSelector(
                    controller: controller,
                    onSelectHomeschool: widget.onSelectHomeschool,
                    onSelectTerm: widget.onSelectTerm,
                    onSelectClassGroup: widget.onSelectClassGroup,
                    onSelectViewRole: widget.onSelectViewRole,
                    extraChips: [
                      _buildParentChildSwitchButton(controller),
                      _buildParentViewTargetSwitchButton(controller),
                      _buildTeacherViewTargetSwitchButton(controller),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: '새로고침',
                  onPressed: controller.isBusy ? null : widget.onRefresh,
                  icon: const Icon(Icons.refresh, size: 20),
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  padding: EdgeInsets.zero,
                ),
                PopupMenuButton<String>(
                  tooltip: displayName,
                  icon: CircleAvatar(
                    radius: 14,
                    backgroundColor: NestColors.dustyRose,
                    child: Text(
                      displayName.characters.first,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: NestColors.deepWood,
                      ),
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'logout') {
                      unawaited(widget.onLogout());
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem<String>(
                      enabled: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$displayName 님',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: NestColors.deepWood,
                            ),
                          ),
                          Text(
                            _labelForRole(controller.currentRole ?? '-'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: NestColors.deepWood.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    if (controller.availableViewRoles.length > 1)
                      ...controller.availableViewRoles.map(
                        (role) => PopupMenuItem<String>(
                          value: 'role:$role',
                          onTap: () => unawaited(widget.onSelectViewRole(role)),
                          child: Row(
                            children: [
                              Icon(
                                controller.currentRole == role
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(_labelForRole(role)),
                            ],
                          ),
                        ),
                      ),
                    if (controller.availableViewRoles.length > 1)
                      const PopupMenuDivider(),
                    const PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 16),
                          SizedBox(width: 8),
                          Text('로그아웃'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (controller.isBusy)
            const LinearProgressIndicator(minHeight: 2),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (child, animation) =>
                        nestFadeSlideTransition(
                          child,
                          animation,
                          beginOffset: const Offset(0.015, 0),
                        ),
                    child: KeyedSubtree(
                      key: ValueKey<String>(widget.tabLabel),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: widget.tab,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: NestBusyOverlay(visible: controller.isBusy),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextSelector extends StatefulWidget {
  const _ContextSelector({
    required this.controller,
    required this.onSelectHomeschool,
    required this.onSelectTerm,
    required this.onSelectClassGroup,
    required this.onSelectViewRole,
    this.extraChips = const [],
  });

  final NestController controller;
  final Future<void> Function(String? value) onSelectHomeschool;
  final Future<void> Function(String? value) onSelectTerm;
  final Future<void> Function(String? value) onSelectClassGroup;
  final Future<void> Function(String? value) onSelectViewRole;
  final List<Widget> extraChips;

  @override
  State<_ContextSelector> createState() => _ContextSelectorState();
}

class _ContextSelectorState extends State<_ContextSelector> {
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    final homeschoolOptions = controller.memberships
        .map(
          (membership) => _ContextOption(
            id: membership.homeschoolId,
            title: membership.homeschool.name,
            subtitle: _labelForRole(membership.role),
          ),
        )
        .toList(growable: false);
    final termOptions = controller.terms
        .map(
          (term) => _ContextOption(
            id: term.id,
            title: term.name,
            subtitle: _labelForTermStatus(term.status),
          ),
        )
        .toList(growable: false);
    final classOptions = controller.classGroups
        .map((group) => _ContextOption(id: group.id, title: group.name))
        .toList(growable: false);
    final roleOptions = controller.availableViewRoles
        .map(
          (role) => _ContextOption(
            id: role,
            title: _labelForRole(role),
          ),
        )
        .toList(growable: false);

    final items = [
      _ContextCardData(
        icon: Icons.home_outlined,
        label: '홈스쿨',
        value: homeschoolOptions
            .where((row) => row.id == controller.selectedHomeschoolId)
            .map((row) => row.title)
            .firstOrNull,
        help: '운영 단위가 되는 홈스쿨을 선택합니다.',
        options: homeschoolOptions,
        onSelect: widget.onSelectHomeschool,
      ),
      _ContextCardData(
        icon: Icons.calendar_month_outlined,
        label: '학기',
        value: termOptions
            .where((row) => row.id == controller.selectedTermId)
            .map((row) => row.title)
            .firstOrNull,
        help: '현재 운영 중인 학기를 선택합니다.',
        options: termOptions,
        onSelect: widget.onSelectTerm,
      ),
      _ContextCardData(
        icon: Icons.groups_2_outlined,
        label: '반',
        value: classOptions
            .where((row) => row.id == controller.selectedClassGroupId)
            .map((row) => row.title)
            .firstOrNull,
        help: '시간표/공지/활동을 볼 기준 반을 선택합니다.',
        options: classOptions,
        onSelect: widget.onSelectClassGroup,
      ),
      _ContextCardData(
        icon: Icons.person_outline,
        label: '뷰 역할',
        value: roleOptions
            .where((row) => row.id == controller.currentRole)
            .map((row) => row.title)
            .firstOrNull,
        help: '같은 계정이라도 부모/교사/관리자 화면을 전환합니다.',
        options: roleOptions,
        onSelect: widget.onSelectViewRole,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ActionChip(
                avatar: Icon(item.icon, size: 16),
                label: Text(
                  '${item.label}: ${item.value ?? '-'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onPressed: controller.isBusy || item.options.isEmpty
                    ? null
                    : () => _openContextPicker(
                          title: item.label,
                          help: item.help,
                          options: item.options,
                          currentId: item.options
                              .where((row) => row.title == item.value)
                              .map((row) => row.id)
                              .firstOrNull,
                          onSelect: item.onSelect,
                        ),
              ),
            ),
          ),
          ...widget.extraChips,
        ],
      ),
    );
  }

  Future<void> _openContextPicker({
    required String title,
    required String help,
    required List<_ContextOption> options,
    required String? currentId,
    required Future<void> Function(String? value) onSelect,
  }) async {
    if (options.isEmpty) {
      return;
    }

    var query = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filtered = query.trim().isEmpty
                ? options
                : options
                      .where(
                        (option) =>
                            option.title.toLowerCase().contains(
                              query.trim().toLowerCase(),
                            ) ||
                            option.subtitle.toLowerCase().contains(
                              query.trim().toLowerCase(),
                            ),
                      )
                      .toList(growable: false);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    help,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.72),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (value) => setSheetState(() => query = value),
                    decoration: const InputDecoration(
                      labelText: '검색',
                      hintText: '이름으로 빠르게 찾기',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: filtered.isEmpty
                        ? const Center(child: Text('검색 결과가 없습니다.'))
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final option = filtered[index];
                              final selected = option.id == currentId;
                              return ListTile(
                                dense: true,
                                leading: selected
                                    ? const Icon(Icons.check_circle)
                                    : const Icon(Icons.circle_outlined),
                                title: Text(option.title),
                                subtitle: option.subtitle.isEmpty
                                    ? null
                                    : Text(option.subtitle),
                                onTap: () async {
                                  Navigator.of(context).pop();
                                  await onSelect(option.id);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ContextCardData {
  const _ContextCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.help,
    required this.options,
    required this.onSelect,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String help;
  final List<_ContextOption> options;
  final Future<void> Function(String? value) onSelect;
}

class _ContextOption {
  const _ContextOption({
    required this.id,
    required this.title,
    this.subtitle = '',
  });

  final String id;
  final String title;
  final String subtitle;
}

Icon _iconForLabel(String label, {required bool filled}) {
  return switch (label) {
    '대시보드' => Icon(
      filled ? Icons.nest_cam_wired_stand : Icons.nest_cam_wired_stand_outlined,
    ),
    'Dashboard' => Icon(
      filled ? Icons.nest_cam_wired_stand : Icons.nest_cam_wired_stand_outlined,
    ),
    '시간표' => Icon(
      filled ? Icons.calendar_view_week : Icons.calendar_view_week_outlined,
    ),
    '학습 현황' => Icon(filled ? Icons.insights : Icons.insights_outlined),
    '소식' => Icon(filled ? Icons.newspaper : Icons.newspaper_outlined),
    '교사 허브' => Icon(filled ? Icons.school : Icons.school_outlined),
    'Teacher Hub' => Icon(filled ? Icons.school : Icons.school_outlined),
    'Timetable' => Icon(filled ? Icons.view_week : Icons.view_week_outlined),
    'Schedule' => Icon(filled ? Icons.view_week : Icons.view_week_outlined),
    '학기 설정' => Icon(filled ? Icons.account_tree : Icons.account_tree_outlined),
    'Term Setup' => Icon(
      filled ? Icons.account_tree : Icons.account_tree_outlined,
    ),
    '시스템' => Icon(filled ? Icons.tune : Icons.tune_outlined),
    'System' => Icon(filled ? Icons.tune : Icons.tune_outlined),
    '커뮤니티' => Icon(filled ? Icons.forum : Icons.forum_outlined),
    'Community' => Icon(filled ? Icons.forum : Icons.forum_outlined),
    'SNS' => Icon(filled ? Icons.forum : Icons.forum_outlined),
    'SNS Admin' => Icon(
      filled ? Icons.admin_panel_settings : Icons.admin_panel_settings_outlined,
    ),
    'Members' => Icon(filled ? Icons.group : Icons.group_outlined),
    'Families' => Icon(filled ? Icons.diversity_3 : Icons.diversity_3_outlined),
    'Ops' => Icon(filled ? Icons.manage_search : Icons.manage_search_outlined),
    '갤러리' => Icon(filled ? Icons.photo_library : Icons.photo_library_outlined),
    'Gallery' => Icon(
      filled ? Icons.photo_library : Icons.photo_library_outlined,
    ),
    'Media Setup' => Icon(filled ? Icons.cloud_done : Icons.cloud_outlined),
    _ => Icon(filled ? Icons.cloud_done : Icons.cloud_outlined),
  };
}

String _labelForRole(String role) {
  return switch (role) {
    'HOMESCHOOL_ADMIN' => '관리자',
    'STAFF' => '스태프',
    'TEACHER' => '교사',
    'GUEST_TEACHER' => '외부교사',
    'PARENT' => '부모',
    _ => role,
  };
}

String _labelForTermStatus(String status) {
  return switch (status) {
    'ACTIVE' => '진행 중',
    'UPCOMING' => '예정',
    'COMPLETED' => '완료',
    'ARCHIVED' => '보관',
    _ => status,
  };
}

class _WarmScenery extends StatelessWidget {
  const _WarmScenery();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF2EA),
            NestColors.creamyWhite,
            Color(0xFFF2EEE6),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -120,
            top: -100,
            child: _SceneBlob(
              size: 380,
              color: NestColors.dustyRose.withValues(alpha: 0.2),
            ),
          ),
          Positioned(
            left: -130,
            bottom: -120,
            child: _SceneBlob(
              size: 420,
              color: NestColors.mutedSage.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }
}

class _SceneBlob extends StatelessWidget {
  const _SceneBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 84, spreadRadius: 14)],
      ),
    );
  }
}
