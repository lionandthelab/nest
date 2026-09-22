import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/tabs/album/album_drive_connect_sheet.dart';
import 'package:nest_frontend/src/ui/widgets/drive_integration_card.dart';

NestController _controller({required bool connected}) {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final controller = NestController(repository: NestRepository(client));
  controller.currentRole = 'HOMESCHOOL_ADMIN';
  controller.selectedHomeschoolId = 'hs-1';
  controller.driveIntegration = DriveIntegration.fromMap({
    'id': 'di-1',
    'homeschool_id': 'hs-1',
    'status': connected ? 'CONNECTED' : 'DISCONNECTED',
    'google_email': connected ? 'admin@example.com' : null,
    'connected_at': connected ? '2026-09-22T01:00:00.000Z' : null,
  });
  return controller;
}

Future<void> _openSheet(WidgetTester tester, NestController controller) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: NestTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showDriveConnectSheet(context: context, controller: controller),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('연결 전에는 무엇이 일어나는지 먼저 알린다', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openSheet(tester, _controller(connected: false));

    expect(find.text('사진을 어디에 보관할까요'), findsOneWidget);
    expect(find.text('원본은 관리자 Drive에'), findsOneWidget);
    expect(find.text('학기·수업·날짜 폴더로 자동 정리'), findsOneWidget);
    expect(find.text('Google 계정으로 연결'), findsOneWidget);

    // 접근 범위를 밝히는 문구가 있어야 한다 — 남의 Drive에 붙는 일이다.
    expect(find.text('Nest가 접근하는 범위'), findsOneWidget);
  });

  testWidgets('폴더 ID를 직접 붙여 넣으라고 하지 않는다', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openSheet(tester, _controller(connected: false));

    // 예전 카드에는 '루트 폴더 ID' 입력란이 있었다. 연결 경로에서 사라져야 한다.
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('폴더 ID'), findsNothing);
  });

  testWidgets('이미 연결돼 있으면 어느 계정인지 바로 보여 준다', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _openSheet(tester, _controller(connected: true));

    expect(find.text('연결됐습니다'), findsOneWidget);
    expect(find.text('admin@example.com'), findsOneWidget);
    expect(find.text('Drive에서 열어보기'), findsOneWidget);
    expect(find.text('연결 끊기'), findsOneWidget);
  });

  testWidgets('관리자 홈 카드가 미연결 상태를 분명히 말한다', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _controller(connected: false);
    await tester.pumpWidget(
      MaterialApp(
        theme: NestTheme.light(),
        home: Scaffold(
          body: DriveIntegrationCard(controller: controller),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('사진 저장 위치'), findsOneWidget);
    expect(
      find.text('아직 연결하지 않았습니다. 지금은 Nest에 저장됩니다.'),
      findsOneWidget,
    );
  });

  testWidgets('연결된 카드는 저장되는 계정을 보여 준다', (tester) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = _controller(connected: true);
    await tester.pumpWidget(
      MaterialApp(
        theme: NestTheme.light(),
        home: Scaffold(
          body: DriveIntegrationCard(controller: controller),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('admin@example.com 의 Drive에 보관 중'), findsOneWidget);
  });
}
