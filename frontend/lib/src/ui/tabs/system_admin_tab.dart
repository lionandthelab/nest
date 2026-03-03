import 'package:flutter/material.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'community_tab.dart';
import 'drive_tab.dart';
import 'members_tab.dart';
import 'ops_tab.dart';

class SystemAdminTab extends StatefulWidget {
  const SystemAdminTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<SystemAdminTab> createState() => _SystemAdminTabState();
}

class _SystemAdminTabState extends State<SystemAdminTab> {
  String _section = 'SNS';

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    if (!controller.isAdminLike) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('시스템 설정', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('이 화면은 관리자/스태프 전용입니다.'),
            ],
          ),
        ),
      );
    }

    final child = switch (_section) {
      'SNS' => CommunityTab(controller: controller),
      'DRIVE' => DriveTab(controller: controller),
      'MEMBERS' => MembersTab(controller: controller),
      'OPS' => OpsTab(controller: controller),
      _ => CommunityTab(controller: controller),
    };

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('시스템 설정', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'Google Drive 연동, SNS 모더레이션, 권한/운영 관리를 한 곳에서 처리합니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'SNS', label: Text('SNS 관리')),
                    ButtonSegment(value: 'DRIVE', label: Text('Google Drive')),
                    ButtonSegment(value: 'MEMBERS', label: Text('권한')),
                    ButtonSegment(value: 'OPS', label: Text('운영')),
                  ],
                  selected: {_section},
                  onSelectionChanged: (values) {
                    if (values.isEmpty) {
                      return;
                    }
                    setState(() {
                      _section = values.first;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey(_section), child: child),
          ),
        ),
      ],
    );
  }
}
