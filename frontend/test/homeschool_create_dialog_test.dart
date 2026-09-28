import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/widgets/homeschool_create_dialog.dart';

NestController _controller() {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return NestController(repository: NestRepository(client));
}

class _FakeOnboardingController extends NestController {
  _FakeOnboardingController({this.driveConnected = false})
      : super(
          repository: NestRepository(
            SupabaseClient(
              'http://localhost',
              'test-key',
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            ),
          ),
        );

  final bool driveConnected;
  bool bootstrapCalled = false;
  bool loadDriveCalled = false;

  @override
  Future<void> bootstrapFrame({
    required String homeschoolName,
    required String termName,
    required String startDate,
    required String endDate,
    required String className,
    required String coursesCsv,
  }) async {
    bootstrapCalled = true;
  }

  @override
  Future<void> loadDriveIntegration() async {
    loadDriveCalled = true;
    if (driveConnected) {
      driveIntegration = const DriveIntegration(
        id: 'd-1',
        homeschoolId: 'hs-1',
        status: 'CONNECTED',
      );
    }
  }
}

void main() {
  testWidgets('create dialog shows the start action and can close', (
    tester,
  ) async {
    final controller = _controller();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () {
                  showHomeschoolCreateDialog(
                    context: context,
                    controller: controller,
                  );
                },
                child: const Text('열기'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    expect(find.text('우리집 홈스쿨 시작하기'), findsOneWidget);
    expect(find.text('바로 시작하기'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('우리집 홈스쿨 시작하기'), findsNothing);
  });

  testWidgets('생성 완료 후 Google Drive 연동 온보딩 스텝으로 전환된다', (
    tester,
  ) async {
    final controller = _FakeOnboardingController(driveConnected: false);
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showHomeschoolCreateDialog(
                    context: context,
                    controller: controller,
                  );
                },
                child: const Text('열기'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    // 1단계 폼 화면 확인
    expect(find.text('우리집 홈스쿨 시작하기'), findsOneWidget);
    expect(find.text('바로 시작하기'), findsOneWidget);

    // 바로 시작하기 탭 -> 생성 진행
    await tester.tap(find.text('바로 시작하기'));
    await tester.pumpAndSettle();

    // bootstrapFrame 및 loadDriveIntegration 호출 확인
    expect(controller.bootstrapCalled, isTrue);
    expect(controller.loadDriveCalled, isTrue);

    // 2단계: Drive 온보딩 화면 전환 확인
    expect(find.textContaining('개설 완료!'), findsOneWidget);
    expect(find.textContaining('사진 보관용 Google Drive 연동'), findsOneWidget);
    expect(find.text('Google Drive 연동하기 (권장)'), findsOneWidget);
    expect(find.text('나중에 하기 (홈스쿨 바로 시작)'), findsOneWidget);

    // '나중에 하기' 클릭 시 닫히며 true 반환
    await tester.tap(find.text('나중에 하기 (홈스쿨 바로 시작)'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });

  testWidgets('Drive가 이미 연동된 경우 온보딩에서 연동 완료 표시', (
    tester,
  ) async {
    final controller = _FakeOnboardingController(driveConnected: true);
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showHomeschoolCreateDialog(
                    context: context,
                    controller: controller,
                  );
                },
                child: const Text('열기'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('바로 시작하기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('개설 완료!'), findsOneWidget);
    expect(find.text('Google Drive 연동 완료 (앨범 활성화됨)'), findsOneWidget);
    expect(find.text('홈스쿨 시작하기'), findsOneWidget);

    await tester.tap(find.text('홈스쿨 시작하기'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}

