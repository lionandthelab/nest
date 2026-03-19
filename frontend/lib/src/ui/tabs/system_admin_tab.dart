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

class _SystemAdminTabState extends State<SystemAdminTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  static const _tabs = [
    Tab(text: '멤버 관리'),
    Tab(text: 'SNS 관리'),
    Tab(text: '드라이브 관리'),
    Tab(text: '운영 로그'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

    return Column(
      children: [
        Material(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: TabBar(
            controller: _tabController,
            tabs: _tabs,
            isScrollable: false,
            labelColor: NestColors.deepWood,
            unselectedLabelColor: NestColors.deepWood.withValues(alpha: 0.55),
            indicatorColor: NestColors.dustyRose,
            indicatorWeight: 3,
            dividerHeight: 0,
            labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              MembersTab(controller: controller),
              CommunityTab(controller: controller),
              DriveTab(controller: controller),
              OpsTab(controller: controller),
            ],
          ),
        ),
      ],
    );
  }
}
