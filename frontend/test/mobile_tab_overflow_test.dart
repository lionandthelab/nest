import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/tabs/community_tab.dart';
import 'package:nest_frontend/src/ui/tabs/members_tab.dart';
import 'package:nest_frontend/src/ui/tabs/ops_tab.dart';
import 'package:nest_frontend/src/ui/tabs/parent_home_tab.dart';
import 'package:nest_frontend/src/ui/tabs/parent_progress_tab.dart';
import 'package:nest_frontend/src/ui/tabs/profile_settings_tab.dart';
import 'package:nest_frontend/src/ui/tabs/student_home_tab.dart';

/// 네트워크를 타지 않는 관리자 컨트롤러(다른 위젯 테스트와 같은 방식).
NestController _controller({String role = 'HOMESCHOOL_ADMIN'}) {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final controller = NestController(repository: NestRepository(client));
  controller.currentRole = role;
  controller.selectedHomeschoolId = 'hs-1';
  controller.selectedTermId = 't-1';
  controller.memberships = [
    Membership.fromMap({
      'user_id': 'u-1',
      'homeschool_id': 'hs-1',
      'role': role,
      'status': 'ACTIVE',
      'homeschools': {'id': 'hs-1', 'name': '테스트스쿨', 'timezone': 'Asia/Seoul'},
    }),
  ];
  controller.terms = [
    Term.fromMap({
      'id': 't-1',
      'homeschool_id': 'hs-1',
      'name': '2026 가을학기 통합 프로그램',
      'status': 'ACTIVE',
      'start_date': '2026-09-01',
      'end_date': '2027-01-31',
    }),
  ];
  controller.announcements = [
    Announcement.fromMap({
      'id': 'a-1',
      'homeschool_id': 'hs-1',
      'class_group_id': null,
      'title': '2026 가을학기 개학 안내와 준비물 목록 공유드립니다',
      'body':
          '개학일은 9월 1일 화요일이며, 첫 주는 단축 수업으로 운영합니다. '
          '준비물은 학기 안내문을 확인해 주세요.',
      'pinned': true,
      'created_at': '2026-08-20T00:00:00Z',
    }),
  ];
  return controller;
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: NestTheme.light(),
      locale: const Locale('ko'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: Scaffold(body: child),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('MembersTab이 360폭에서 넘치지 않는다', (tester) async {
    await _pump(tester, MembersTab(controller: _controller()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('OpsTab이 360폭에서 넘치지 않는다', (tester) async {
    await _pump(tester, OpsTab(controller: _controller()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('CommunityTab이 360폭에서 넘치지 않는다', (tester) async {
    await _pump(tester, CommunityTab(controller: _controller()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProfileSettingsTab이 360폭에서 넘치지 않는다', (tester) async {
    await _pump(tester, ProfileSettingsTab(controller: _controller()));
    expect(tester.takeException(), isNull);
  });

  testWidgets('ParentHomeTab이 360폭에서 넘치지 않는다', (tester) async {
    await _pump(
      tester,
      ParentHomeTab(
        controller: _controller(role: 'PARENT'),
        selectedChildId: null,
        childClassBundles: const {},
        isLoadingChildClasses: false,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ParentProgressTab은 자녀를 아직 못 고른 상태에서도 그려진다', (tester) async {
    await _pump(
      tester,
      ParentProgressTab(
        controller: _controller(role: 'PARENT'),
        selectedChildId: null,
        childClassBundles: const {},
        isLoadingChildClasses: false,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('StudentHomeTab이 360폭에서 넘치지 않는다', (tester) async {
    await _pump(
      tester,
      StudentHomeTab(
        controller: _controller(role: 'STUDENT'),
        selectedChildId: null,
        childClassBundles: const {},
        isLoadingChildClasses: false,
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
