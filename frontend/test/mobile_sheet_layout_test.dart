import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/tabs/family_admin_tab.dart';
import 'package:nest_frontend/src/ui/widgets/nest_sheet.dart';

NestController _adminController() {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final controller = NestController(repository: NestRepository(client));
  controller.currentRole = 'HOMESCHOOL_ADMIN';
  controller.selectedHomeschoolId = 'hs-1';
  controller.selectedTermId = 't-1';
  controller.memberships = [
    Membership.fromMap({
      'user_id': 'u-1',
      'homeschool_id': 'hs-1',
      'role': 'HOMESCHOOL_ADMIN',
      'status': 'ACTIVE',
      'homeschools': {'id': 'hs-1', 'name': '테스트스쿨', 'timezone': 'Asia/Seoul'},
    }),
  ];
  controller.terms = [
    Term.fromMap({
      'id': 't-1',
      'homeschool_id': 'hs-1',
      'name': '2026 가을학기',
      'status': 'ACTIVE',
      'start_date': '2026-09-01',
      'end_date': '2027-01-31',
    }),
  ];
  // 목록이 비어 있으면 카드가 빈 상태만 그려 레이아웃을 검증하지 못한다.
  // 실제로 길어지기 쉬운 이름을 넣어 좁은 폭에서의 줄바꿈까지 확인한다.
  controller.families = [
    Family.fromMap({
      'id': 'f-1',
      'homeschool_id': 'hs-1',
      'family_name': '김민준·박서연 가정 (둘째 포함)',
      'note': '주 3회 등원, 목요일은 오후 수업만 참여합니다.',
    }),
  ];
  controller.children = [
    ChildProfile.fromMap({
      'id': 'c-1',
      'homeschool_id': 'hs-1',
      'family_id': 'f-1',
      'name': '김하늘별',
      'birth_date': '2018-04-02',
      'profile_note': '알레르기: 땅콩 · 수요일 조기 하원',
    }),
  ];
  controller.classGroups = [
    ClassGroup.fromMap({
      'id': 'g-1',
      'homeschool_id': 'hs-1',
      'term_id': 't-1',
      'name': '초등 통합반 목요일 오후 심화 프로젝트',
    }),
  ];
  controller.courses = [
    Course.fromMap({
      'id': 'co-1',
      'homeschool_id': 'hs-1',
      'name': '자연 관찰과 기록하기(생태 프로젝트)',
    }),
  ];
  controller.classrooms = [
    Classroom.fromMap({
      'id': 'r-1',
      'homeschool_id': 'hs-1',
      'name': '2층 창가 프로젝트실',
      'capacity': 12,
    }),
  ];
  return controller;
}

Future<void> _pumpTab(WidgetTester tester, NestController controller) async {
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
      home: Scaffold(body: FamilyAdminTab(controller: controller)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('학기 설정 화면이 360폭에서 가로 넘침 없이 그려진다', (tester) async {
    final controller = _adminController();
    await _pumpTab(tester, controller);

    expect(tester.takeException(), isNull);
    // 섹션 제목과 액션 버튼이 한 줄에 몰려 잘리지 않고 모두 보인다.
    expect(find.text('가정 관리'), findsOneWidget);
    expect(find.text('가정 추가'), findsOneWidget);
    expect(find.text('새로고침'), findsOneWidget);
  });

  testWidgets('학기 설정 5개 단위 모두 360폭에서 넘침 없이 그려진다', (tester) async {
    final controller = _adminController();
    await _pumpTab(tester, controller);

    for (final chip in ['2. 선생님', '3. 반', '4. 과목', '5. 교실', '1. 가정']) {
      final finder = find.widgetWithText(ChoiceChip, chip);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$chip 단위에서 넘침');
    }
  });

  testWidgets('단위별 추가 시트가 모두 360폭에서 넘침 없이 열린다', (tester) async {
    final controller = _adminController();
    await _pumpTab(tester, controller);

    const cases = <(String, String)>[
      ('2. 선생님', '선생님 추가'),
      ('3. 반', '반 추가'),
      ('4. 과목', '과목 추가'),
      ('5. 교실', '교실 추가'),
    ];

    for (final (chip, addLabel) in cases) {
      final chipFinder = find.widgetWithText(ChoiceChip, chip);
      await tester.ensureVisible(chipFinder);
      await tester.pumpAndSettle();
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();

      final addButton = find.text(addLabel).first;
      await tester.ensureVisible(addButton);
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$addLabel 시트에서 넘침');
      expect(find.byType(NestSheet), findsOneWidget, reason: addLabel);
      expect(tester.getSize(find.byKey(nestSheetSurfaceKey)).width, 360);

      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('가정 추가 시트가 360폭에서 전체 너비로 열리고 넘치지 않는다', (tester) async {
    final controller = _adminController();
    await _pumpTab(tester, controller);

    final addButton = find.text('가정 추가').first;
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(NestSheet), findsOneWidget);

    // 모바일에서는 좌우 여백 없이 화면 전체 너비를 쓴다.
    final surface = tester.getRect(find.byKey(nestSheetSurfaceKey));
    expect(surface.width, 360);
    expect(surface.bottom, 780);

    // 입력 필드와 저장 버튼이 한 화면 안에 같이 보인다.
    expect(find.text('가정 이름'), findsOneWidget);
    final saveButton = find.text('생성');
    expect(saveButton, findsOneWidget);
    expect(tester.getRect(saveButton).bottom, lessThanOrEqualTo(780));
  });
}
