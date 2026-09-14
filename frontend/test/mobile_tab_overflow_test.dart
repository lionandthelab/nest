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

  // 공지 배너는 [아이콘][제목·본문][반 이름 · 날짜][펼침] 을 한 줄에 늘어놓는데,
  // 반 이름 칸에 폭 제약이 없다. 반 이름이 길면 그 칸이 줄어들지 않아 줄이 넘친다.
  testWidgets('반 이름이 긴 공지 배너도 360폭에서 넘치지 않는다', (tester) async {
    final controller = _controller(role: 'PARENT');
    controller.classGroups = [
      ClassGroup.fromMap({
        'id': 'cg-long',
        'term_id': 't-1',
        'name': '초등 4-6학년 말씀선포 합반',
        'capacity': 12,
      }),
    ];
    controller.announcements = [
      Announcement.fromMap({
        'id': 'a-long',
        'homeschool_id': 'hs-1',
        'class_group_id': 'cg-long',
        'title': '이번 주 암송 구절 안내드립니다',
        'body': '고린도전서 13장 1절과 2절을 외워 오세요. 금요일에 함께 확인합니다.',
        'pinned': false,
        'created_at': '2026-09-10T00:00:00Z',
      }),
    ];

    await _pump(
      tester,
      ParentHomeTab(
        controller: controller,
        selectedChildId: null,
        childClassBundles: const {},
        isLoadingChildClasses: false,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  // 넘침을 막느라 반 이름 칸에 폭을 너무 내주면, 이번엔 제목·본문이 좁아져
  // 쓸데없이 일찍 줄바꿈된다(Flexible 로 두면 제목과 반씩 나눠 갖는다).
  //
  // 폭을 값으로 못박지 않는 이유: 위젯 테스트의 기본 폰트는 모든 글자가 같은 폭의
  // 네모라 글자 폭이 실제 렌더링과 다르다. 대신 "메타 칸이 상한을 넘지 않는다" 는
  // 레이아웃 불변식만 검증한다.
  testWidgets('공지 배너에서 반 이름 칸이 상한을 넘지 않는다', (tester) async {
    final controller = _controller(role: 'PARENT');

    await _pump(
      tester,
      ParentHomeTab(
        controller: controller,
        selectedChildId: null,
        childClassBundles: const {},
        isLoadingChildClasses: false,
      ),
    );

    final meta = find.textContaining('전체 ·');
    expect(meta, findsOneWidget);
    expect(tester.getSize(meta).width, lessThanOrEqualTo(96));
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
