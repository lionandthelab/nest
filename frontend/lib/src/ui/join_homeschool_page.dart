import 'package:flutter/material.dart';

import '../state/nest_controller.dart';
import 'nest_theme.dart';
import 'tabs/dashboard_tab.dart';

/// 이미 소속이 있는 사용자가 다른 홈스쿨에 합류하는 화면.
///
/// 온보딩 대시보드는 소속이 없을 때만 보이므로, 개인 홈스쿨을 만든 관리자도
/// 참여 코드 · 받은 초대 · 이름 검색으로 다른 홈스쿨에 들어갈 수 있게 한다.
class JoinHomeschoolPage extends StatelessWidget {
  const JoinHomeschoolPage({super.key, required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NestColors.creamyWhite,
      appBar: AppBar(
        title: const Text('다른 홈스쿨 가입'),
        backgroundColor: NestColors.creamyWhite,
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  if (controller.pendingInvites.isNotEmpty) ...[
                    PendingInvitesCard(controller: controller),
                    const SizedBox(height: 16),
                  ],
                  JoinByCodeCard(controller: controller),
                  const SizedBox(height: 16),
                  HomeschoolSearchJoinCard(controller: controller),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
