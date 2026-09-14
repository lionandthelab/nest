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

  testWidgets('가정 추가 시트가 360폭에서 전체 너비로 열리고 넘치지 않는다', (tester) async {
    final controller = _adminController();
    await _pumpTab(tester, controller);

    final addButton = find.widgetWithText(ElevatedButton, '가정 추가').first;
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
    expect(find.widgetWithText(TextField, '가정 이름'), findsOneWidget);
    final saveButton = find.widgetWithText(FilledButton, '생성');
    expect(saveButton, findsOneWidget);
    expect(tester.getRect(saveButton).bottom, lessThanOrEqualTo(780));
  });
}
