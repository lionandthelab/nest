import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/models/new_term_checklist.dart';
import 'package:nest_frontend/src/ui/models/tab_section_request.dart';
import 'package:nest_frontend/src/ui/tabs/admin_home_tab.dart';
import 'package:nest_frontend/src/ui/tabs/admin_news_tab.dart';

/// 네트워크를 타지 않는 위젯 테스트용 관리자 컨트롤러.
/// autoRefreshToken을 꺼야 GoTrue의 주기 타이머가 생기지 않아 pending-timer
/// 검증을 통과한다(term_select_chip_test와 같은 이유).
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
  controller.terms = [
    Term.fromMap({
      'id': 't-1',
      'homeschool_id': 'hs-1',
      'name': '2026 가을학기',
      'status': 'UPCOMING',
      'start_date': '2026-09-01',
      'end_date': '2027-01-31',
    }),
  ];
  return controller;
}

Announcement _announcement({
  required String id,
  required String title,
  bool pinned = false,
}) {
  return Announcement.fromMap({
    'id': id,
    'homeschool_id': 'hs-1',
    'class_group_id': null,
    'author_user_id': 'u-1',
    'title': title,
    'body': '본문 내용입니다.',
    'pinned': pinned,
    'created_at': '2026-08-20T09:00:00Z',
  });
}

AcademicEvent _event({
  required String id,
  required String title,
  required String date,
  String? endDate,
}) {
  return AcademicEvent.fromMap({
    'id': id,
    'homeschool_id': 'hs-1',
    'term_id': 't-1',
    'title': title,
    'description': '',
    'event_date': date,
    'end_date': endDate,
    'created_by_user_id': 'u-1',
    'created_at': '2026-08-20T09:00:00Z',
  });
}

/// 좁은 모바일 폭(360x780)으로 고정한 앱 셸.
/// DateFormat('...', 'ko')를 쓰는 화면이 있으므로 로컬라이제이션 델리게이트를
/// 붙여 ko 날짜 심볼이 초기화되게 한다.
Widget _mobileApp(Widget child) {
  return MaterialApp(
    locale: const Locale('ko', 'KR'),
    supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(10), child: child)),
  );
}

Future<void> _setMobileSize(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 780);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('AdminHomeTab (모바일 폭)', () {
    testWidgets('신학기 준비 체크리스트와 빠른 작업이 오버플로 없이 렌더된다', (tester) async {
      await _setMobileSize(tester);
      final controller = _adminController();

      await tester.pumpWidget(
        _mobileApp(AdminHomeTab(controller: controller, onNavigate: (_, {section}) {})),
      );
      await tester.pump();

      expect(find.text('신학기 준비'), findsOneWidget);
      expect(find.text('빠른 작업'), findsOneWidget);
      expect(find.text('공지 작성'), findsOneWidget);
      expect(find.text('학사일정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('빠른 작업을 누르면 대상 탭과 섹션이 함께 전달된다', (tester) async {
      await _setMobileSize(tester);
      final controller = _adminController();
      final navigations = <(String, String?)>[];

      await tester.pumpWidget(
        _mobileApp(
          AdminHomeTab(
            controller: controller,
            onNavigate: (tab, {section}) => navigations.add((tab, section)),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('학사일정'));
      await tester.pump();

      expect(navigations, [(NewTermTabs.news, NewTermSections.events)]);
    });

    testWidgets('체크리스트의 다음 단계는 학기가 있으면 가정·아이 등록이다', (tester) async {
      await _setMobileSize(tester);
      final controller = _adminController();
      final navigations = <(String, String?)>[];

      await tester.pumpWidget(
        _mobileApp(
          AdminHomeTab(
            controller: controller,
            onNavigate: (tab, {section}) => navigations.add((tab, section)),
          ),
        ),
      );
      await tester.pump();

      final nextStepButton = find.textContaining('다음 단계: 가정·아이 등록');
      expect(nextStepButton, findsOneWidget);

      await tester.tap(nextStepButton);
      await tester.pump();

      expect(navigations, [(NewTermTabs.termSetup, NewTermSections.family)]);
    });
  });

  group('AdminNewsTab (모바일 폭)', () {
    testWidgets('공지 목록이 고정 공지 우선으로 렌더된다', (tester) async {
      await _setMobileSize(tester);
      final controller = _adminController();
      controller.allAnnouncements = [
        _announcement(id: 'a-1', title: '준비물 안내'),
        _announcement(id: 'a-2', title: '개학식 안내', pinned: true),
      ];

      await tester.pumpWidget(_mobileApp(AdminNewsTab(controller: controller)));
      await tester.pump();

      expect(find.text('새 공지 작성'), findsOneWidget);
      final pinnedY = tester.getTopLeft(find.text('개학식 안내')).dy;
      final plainY = tester.getTopLeft(find.text('준비물 안내')).dy;
      expect(pinnedY, lessThan(plainY));
      expect(tester.takeException(), isNull);
    });

    testWidgets('섹션 요청을 주면 학사일정 세그먼트로 열린다', (tester) async {
      await _setMobileSize(tester);
      final controller = _adminController();
      controller.academicEvents = [
        _event(id: 'e-1', title: '개학식', date: '2099-03-02'),
      ];

      await tester.pumpWidget(
        _mobileApp(
          AdminNewsTab(
            controller: controller,
            sectionRequest: const TabSectionRequest(
              section: NewTermSections.events,
              nonce: 1,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('학사일정 추가'), findsOneWidget);
      expect(find.text('개학식'), findsOneWidget);
      expect(find.text('다가오는 일정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('학사일정 추가 시트는 달력 피커 필드를 쓴다', (tester) async {
      await _setMobileSize(tester);
      final controller = _adminController();

      await tester.pumpWidget(
        _mobileApp(
          AdminNewsTab(
            controller: controller,
            sectionRequest: const TabSectionRequest(
              section: NewTermSections.events,
              nonce: 1,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('학사일정 추가').first);
      await tester.pumpAndSettle();

      expect(find.text('일정 이름'), findsOneWidget);
      // 날짜는 타이핑이 아니라 눌러서 고르는 필드여야 한다.
      expect(find.text('날짜'), findsOneWidget);
      expect(find.text('여러 날 진행'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
