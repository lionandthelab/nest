import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../state/nest_controller.dart';
import 'nest_theme.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/drive_tab.dart';
import 'tabs/gallery_tab.dart';
import 'tabs/timetable_tab.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});

  final NestController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  static const _labels = <String>['Dashboard', 'Timetable', 'Gallery', 'Drive'];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final pages = [
          DashboardTab(controller: widget.controller),
          TimetableTab(controller: widget.controller),
          GalleryTab(controller: widget.controller),
          DriveTab(controller: widget.controller),
        ];

        final width = MediaQuery.sizeOf(context).width;
        final desktopLike = width >= 1080;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              const _WarmScenery(),
              SafeArea(
                child: desktopLike
                    ? _DesktopScaffold(
                        currentIndex: _currentIndex,
                        onSelectIndex: (value) =>
                            setState(() => _currentIndex = value),
                        labels: _labels,
                        controller: widget.controller,
                        tab: pages[_currentIndex],
                        onLogout: _handleLogout,
                        onRefresh: _handleRefresh,
                        onSelectHomeschool: _handleHomeschoolChange,
                        onSelectTerm: _handleTermChange,
                        onSelectClassGroup: _handleClassGroupChange,
                      )
                    : _MobileScaffold(
                        currentIndex: _currentIndex,
                        onSelectIndex: (value) =>
                            setState(() => _currentIndex = value),
                        labels: _labels,
                        controller: widget.controller,
                        tab: pages[_currentIndex],
                        onLogout: _handleLogout,
                        onRefresh: _handleRefresh,
                        onSelectHomeschool: _handleHomeschoolChange,
                        onSelectTerm: _handleTermChange,
                        onSelectClassGroup: _handleClassGroupChange,
                      ),
              ),
            ],
          ),
        );
      },
    );
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

  void _showMessage(String message) {
    if (!mounted || message.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _DesktopScaffold extends StatelessWidget {
  const _DesktopScaffold({
    required this.currentIndex,
    required this.onSelectIndex,
    required this.labels,
    required this.controller,
    required this.tab,
    required this.onLogout,
    required this.onRefresh,
    required this.onSelectHomeschool,
    required this.onSelectTerm,
    required this.onSelectClassGroup,
  });

  final int currentIndex;
  final ValueChanged<int> onSelectIndex;
  final List<String> labels;
  final NestController controller;
  final Widget tab;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String? value) onSelectHomeschool;
  final Future<void> Function(String? value) onSelectTerm;
  final Future<void> Function(String? value) onSelectClassGroup;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 8, 16),
          child: NavigationRail(
            selectedIndex: currentIndex,
            onDestinationSelected: onSelectIndex,
            useIndicator: true,
            backgroundColor: Colors.white.withValues(alpha: 0.7),
            leading: const Padding(
              padding: EdgeInsets.all(10),
              child: Icon(Icons.nest_cam_wired_stand_outlined, size: 30),
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
              tab: tab,
              onLogout: onLogout,
              onRefresh: onRefresh,
              onSelectHomeschool: onSelectHomeschool,
              onSelectTerm: onSelectTerm,
              onSelectClassGroup: onSelectClassGroup,
            ),
          ),
        ),
      ],
    );
  }
}

class _MobileScaffold extends StatelessWidget {
  const _MobileScaffold({
    required this.currentIndex,
    required this.onSelectIndex,
    required this.labels,
    required this.controller,
    required this.tab,
    required this.onLogout,
    required this.onRefresh,
    required this.onSelectHomeschool,
    required this.onSelectTerm,
    required this.onSelectClassGroup,
  });

  final int currentIndex;
  final ValueChanged<int> onSelectIndex;
  final List<String> labels;
  final NestController controller;
  final Widget tab;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String? value) onSelectHomeschool;
  final Future<void> Function(String? value) onSelectTerm;
  final Future<void> Function(String? value) onSelectClassGroup;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _MainPanel(
              controller: controller,
              tab: tab,
              onLogout: onLogout,
              onRefresh: onRefresh,
              onSelectHomeschool: onSelectHomeschool,
              onSelectTerm: onSelectTerm,
              onSelectClassGroup: onSelectClassGroup,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Card(
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: onSelectIndex,
              height: 72,
              destinations: labels
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

class _MainPanel extends StatelessWidget {
  const _MainPanel({
    required this.controller,
    required this.tab,
    required this.onLogout,
    required this.onRefresh,
    required this.onSelectHomeschool,
    required this.onSelectTerm,
    required this.onSelectClassGroup,
  });

  final NestController controller;
  final Widget tab;
  final Future<void> Function() onLogout;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String? value) onSelectHomeschool;
  final Future<void> Function(String? value) onSelectTerm;
  final Future<void> Function(String? value) onSelectClassGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${AppConfig.appName} Administration',
                            style: theme.textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.user?.email ?? '-',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: NestColors.deepWood.withValues(
                                alpha: 0.72,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy ? null : onRefresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('새로고침'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy ? null : onLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('로그아웃'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _ContextSelector(
                  controller: controller,
                  onSelectHomeschool: onSelectHomeschool,
                  onSelectTerm: onSelectTerm,
                  onSelectClassGroup: onSelectClassGroup,
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Chip(
                        label: Text('역할: ${controller.currentRole ?? 'None'}'),
                        avatar: const Icon(Icons.verified_user, size: 16),
                      ),
                      Chip(
                        label: Text(controller.statusMessage),
                        avatar: controller.isBusy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.info_outline, size: 16),
                      ),
                    ],
                  ),
                ),
                if (controller.isBusy)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: LinearProgressIndicator(minHeight: 3),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(padding: const EdgeInsets.all(16), child: tab),
          ),
        ],
      ),
    );
  }
}

class _ContextSelector extends StatelessWidget {
  const _ContextSelector({
    required this.controller,
    required this.onSelectHomeschool,
    required this.onSelectTerm,
    required this.onSelectClassGroup,
  });

  final NestController controller;
  final Future<void> Function(String? value) onSelectHomeschool;
  final Future<void> Function(String? value) onSelectTerm;
  final Future<void> Function(String? value) onSelectClassGroup;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 860;

    final homeschoolItems = controller.memberships
        .map(
          (membership) => DropdownMenuItem<String>(
            value: membership.homeschoolId,
            child: Text(membership.homeschool.name),
          ),
        )
        .toList(growable: false);

    final termItems = controller.terms
        .map(
          (term) => DropdownMenuItem<String>(
            value: term.id,
            child: Text('${term.name} (${term.status})'),
          ),
        )
        .toList(growable: false);

    final classItems = controller.classGroups
        .map(
          (group) => DropdownMenuItem<String>(
            value: group.id,
            child: Text(group.name),
          ),
        )
        .toList(growable: false);

    final fields = [
      _SelectorField(
        label: '홈스쿨',
        value: controller.selectedHomeschoolId,
        items: homeschoolItems,
        onChanged: controller.isBusy ? null : onSelectHomeschool,
      ),
      _SelectorField(
        label: '학기',
        value: controller.selectedTermId,
        items: termItems,
        onChanged: controller.isBusy ? null : onSelectTerm,
      ),
      _SelectorField(
        label: '반',
        value: controller.selectedClassGroupId,
        items: classItems,
        onChanged: controller.isBusy ? null : onSelectClassGroup,
      ),
    ];

    if (compact) {
      return Column(
        children: fields
            .map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: field,
              ),
            )
            .toList(growable: false),
      );
    }

    return Row(
      children: fields
          .map(
            (field) => Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 10),
                child: field,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _SelectorField extends StatelessWidget {
  const _SelectorField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: items.any((item) => item.value == value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: items,
      onChanged: onChanged,
      hint: Text(items.isEmpty ? '데이터 없음' : '$label 선택'),
    );
  }
}

Icon _iconForLabel(String label, {required bool filled}) {
  return switch (label) {
    'Dashboard' => Icon(filled ? Icons.dashboard : Icons.dashboard_outlined),
    'Timetable' => Icon(filled ? Icons.view_week : Icons.view_week_outlined),
    'Gallery' => Icon(
      filled ? Icons.photo_library : Icons.photo_library_outlined,
    ),
    _ => Icon(filled ? Icons.cloud_done : Icons.cloud_outlined),
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
