// 안내 슬라이드용 "실제 화면" 캡처 하네스.
// CI 기본 `flutter test`(=test/ 디렉토리)에는 포함되지 않는다.
// 실행: cd frontend && flutter test tool/screenshots/guide_shots_test.dart
// 결과 PNG: scripts/shots/*.png (실제 위젯 + 실제 폰트로 렌더).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/tabs/dashboard_tab.dart';
import 'package:nest_frontend/src/ui/tabs/members_tab.dart';

const _shotsDir = 'shots'; // frontend/shots → 이후 scripts/shots 로 복사

// 화면에 보일 참여 코드. 실제 코드는 소스에 남기지 않도록 env 로 주입.
// 예: GUIDE_CODE=44UDMV flutter test tool/screenshots/guide_shots_test.dart
final _guideCode = Platform.environment['GUIDE_CODE'] ?? 'DEMO12';

/// resolveJoinCode 만 캔드 값으로 응답하는 페이크 리포지토리(네트워크 없음).
class _FakeRepo extends NestRepository {
  _FakeRepo(super.client);

  @override
  Future<({String homeschoolId, String name})?> resolveJoinCode(
    String code,
  ) async =>
      (homeschoolId: 'joy', name: 'JOY 홈스쿨');
}

Future<void> _loadFont(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)));
  await loader.load();
}

Future<void> _loadFonts() async {
  await _loadFont('BlackHanSans', 'assets/fonts/BlackHanSans-Regular.ttf');
  await _loadFont('Jua', 'assets/fonts/Jua-Regular.ttf');
  await _loadFont('DoHyeon', 'assets/fonts/DoHyeon-Regular.ttf');

  // SDK 번들 폰트: Material 아이콘(네모 방지) + Roboto(가운뎃점·말줄임표 폴백).
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final matFonts = '$flutterRoot/bin/cache/artifacts/material_fonts';
    final iconFont = '$matFonts/MaterialIcons-Regular.otf';
    if (File(iconFont).existsSync()) {
      await _loadFont('MaterialIcons', iconFont);
    }
    final roboto = '$matFonts/Roboto-Regular.ttf';
    if (File(roboto).existsSync()) {
      await _loadFont('Roboto', roboto);
    }
  }
}

Future<void> _shoot(WidgetTester tester, GlobalKey key, String name) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory(_shotsDir);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    File('$_shotsDir/$name').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  late SupabaseClient client;

  setUpAll(() async {
    await _loadFonts();
    client = SupabaseClient(
      'https://avursvhmilcsssabqtkx.supabase.co',
      'anon-key-not-used-in-harness',
    );
  });

  tearDownAll(() async {
    await client.dispose();
  });

  // Jua/DoHyeon/BlackHanSans 에 없는 문장부호(·, …)는 Roboto 로 폴백.
  final base = NestTheme.light();
  final theme = base.copyWith(
    textTheme: base.textTheme.apply(fontFamilyFallback: const ['Roboto']),
  );

  Widget frame(GlobalKey key, Widget child, {Color? bg}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      // builder 로 Navigator(다이얼로그 오버레이 포함)까지 RepaintBoundary 안에 넣는다.
      builder: (context, navChild) =>
          RepaintBoundary(key: key, child: navChild!),
      home: Scaffold(
        backgroundColor: bg ?? NestColors.creamyWhite,
        body: child,
      ),
    );
  }

  testWidgets('parent: 참여 코드 합류 카드 (코드 확인 + 역할 선택)', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(440, 560);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = NestController(repository: _FakeRepo(client));
    final key = GlobalKey();

    await tester.pumpWidget(frame(
      key,
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: JoinByCodeCard(controller: controller),
      ),
    ));
    await tester.pumpAndSettle();

    // 코드 입력 → 확인 → 역할 선택 상태로 구동.
    await tester.enterText(find.byType(TextField).first, _guideCode);
    await tester.tap(find.widgetWithText(FilledButton, '확인'));
    await tester.pumpAndSettle();

    await _shoot(tester, key, 'parent_join_code.png');
  });

  testWidgets('admin: 참여 코드 공유 카드', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(440, 245);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _seedAdmin(client);
    final key = GlobalKey();

    await tester.pumpWidget(frame(key, MembersTab(controller: controller)));
    await tester.pumpAndSettle();

    await _shoot(tester, key, 'admin_join_code.png');
  });

  testWidgets('admin: 가입 승인 다이얼로그 (역할 + 가정 연결)', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    // 승인 버튼이 리스트 뷰 캐시 범위 안에 빌드되도록 넉넉하게.
    tester.view.physicalSize = const Size(460, 1300);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = _seedAdmin(client);
    final key = GlobalKey();

    await tester.pumpWidget(frame(key, MembersTab(controller: controller)));
    await tester.pumpAndSettle();

    // FilledButton.icon 의 런타임 타입은 _FilledButtonWithIcon 이라 텍스트로 탭.
    await tester.tap(find.text('승인'));
    await tester.pumpAndSettle();
    // 가정 하나 선택 → 승인 버튼 활성화 상태로.
    // (권한 관리 카드에도 드롭다운이 있으므로 다이얼로그 내부로 한정.)
    await tester.tap(find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(DropdownButtonFormField<String>),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('예서네 가정').last);
    await tester.pumpAndSettle();

    // 다이얼로그만 담기게 화면을 좁혀서 캡처.
    tester.view.physicalSize = const Size(460, 640);
    await tester.pumpAndSettle();

    await _shoot(tester, key, 'admin_approve_dialog.png');
  });
}

NestController _seedAdmin(SupabaseClient client) {
  final controller = NestController(repository: NestRepository(client));
  final hs = Homeschool(
    id: 'joy',
    name: 'JOY 홈스쿨',
    timezone: 'Asia/Seoul',
    joinCode: _guideCode,
  );
  controller.memberships = [
    Membership(
      userId: 'admin',
      homeschoolId: 'joy',
      role: 'HOMESCHOOL_ADMIN',
      status: 'ACTIVE',
      homeschool: hs,
    ),
  ];
  controller.selectedHomeschoolId = 'joy';
  controller.currentRole = 'HOMESCHOOL_ADMIN';
  controller.families = const [
    Family(
      id: 'f1',
      homeschoolId: 'joy',
      familyName: '예서네 가정',
      note: '',
      createdAt: null,
    ),
    Family(
      id: 'f2',
      homeschoolId: 'joy',
      familyName: '하준이네 가정',
      note: '',
      createdAt: null,
    ),
  ];
  controller.joinRequests = [
    HomeschoolJoinRequest(
      id: 'r1',
      homeschoolId: 'joy',
      requesterUserId: 'u1',
      requesterEmail: 'yeseo.mom@example.com',
      requesterName: '김민지',
      requestNote: '예서 엄마예요 :)',
      status: 'PENDING',
      createdAt: DateTime(2026, 7, 3, 10, 20),
      requestedRole: 'PARENT',
    ),
  ];
  return controller;
}
