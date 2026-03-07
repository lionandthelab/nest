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

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactSelector = constraints.maxWidth < 900;
        return Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '시스템 설정',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Google Drive 연동, SNS 모더레이션, 권한/운영 관리를 한 곳에서 처리합니다.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (compactSelector)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _sectionButtons
                              .map(
                                (button) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(button.label),
                                    selected: _section == button.key,
                                    onSelected: (_) {
                                      setState(() {
                                        _section = button.key;
                                      });
                                    },
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      )
                    else
                      SegmentedButton<String>(
                        segments: _sectionButtons
                            .map(
                              (button) => ButtonSegment(
                                value: button.key,
                                label: Text(button.label),
                              ),
                            )
                            .toList(growable: false),
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
      },
    );
  }
}

class _SystemSectionButton {
  const _SystemSectionButton({required this.key, required this.label});

  final String key;
  final String label;
}

const _sectionButtons = <_SystemSectionButton>[
  _SystemSectionButton(key: 'SNS', label: 'SNS 관리'),
  _SystemSectionButton(key: 'DRIVE', label: 'Google Drive'),
  _SystemSectionButton(key: 'MEMBERS', label: '권한'),
  _SystemSectionButton(key: 'OPS', label: '운영'),
];
