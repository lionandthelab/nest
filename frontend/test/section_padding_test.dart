import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/tabs/community_tab.dart';
import 'package:nest_frontend/src/ui/tabs/ops_tab.dart';

NestController _admin() {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final controller = NestController(repository: NestRepository(client));
  controller.currentRole = 'HOMESCHOOL_ADMIN';
  controller.selectedHomeschoolId = 'hs-1';
  return controller;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: NestTheme.light(),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump();
}

void main() {
  // 시스템 탭의 다른 섹션(카드 안 16px)과 같은 선에서 제목이 시작해야 한다.
  testWidgets('감사 로그 제목이 화면 왼쪽 끝에 붙지 않는다', (tester) async {
    await _pump(tester, OpsTab(controller: _admin()));

    final title = find.text('감사 로그');
    expect(title, findsOneWidget);
    expect(tester.getTopLeft(title).dx, greaterThanOrEqualTo(16));
    expect(
      find.ancestor(of: title, matching: find.byType(Card)),
      findsOneWidget,
    );
  });

  testWidgets('게시글 관리 제목이 화면 왼쪽 끝에 붙지 않는다', (tester) async {
    await _pump(tester, CommunityTab(controller: _admin()));

    final title = find.text('게시글 관리');
    expect(title, findsOneWidget);
    expect(tester.getTopLeft(title).dx, greaterThanOrEqualTo(16));
    expect(
      find.ancestor(of: title, matching: find.byType(Card)),
      findsOneWidget,
    );
  });
}
