import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/course_schedule_quick_adder.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/tabs/dashboard_tab.dart';

class _FakeProgressiveOnboardingController extends NestController {
  _FakeProgressiveOnboardingController()
      : super(
          repository: NestRepository(
            SupabaseClient(
              'http://localhost',
              'test-key',
              authOptions: const AuthClientOptions(autoRefreshToken: false),
            ),
          ),
        );

  bool bootstrapCalled = false;
  bool quickAddCalled = false;
  bool childRegistered = false;
  String? lastHomeschoolName;
  String? lastChildName;
  int lastPlacementCount = 0;

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
    lastHomeschoolName = homeschoolName;
  }

  @override
  Future<({int createdCourses, int createdSessions, int skippedSessions})>
      applyCourseAndScheduleQuickAdd({
    required List<CourseTemplateItem> coursesToEnsure,
    List<TemplateSlotPlacement> placements = const [],
    bool placeOnTimetable = true,
  }) async {
    quickAddCalled = true;
    lastPlacementCount = placements.length;
    return (
      createdCourses: coursesToEnsure.length,
      createdSessions: placements.length,
      skippedSessions: 0,
    );
  }

  @override
  Future<ChildProfile?> registerFirstChildOnboarding({
    required String childName,
    String? birthDate,
  }) async {
    childRegistered = true;
    lastChildName = childName;
    return null;
  }

  @override
  Future<void> loadDriveIntegration() async {}
}

void main() {
  testWidgets(
    'DashboardTab progressive onboarding unfolds Step 2 instantly and submits template + child',
    (tester) async {
      final controller = _FakeProgressiveOnboardingController();
      await tester.pumpWidget(
        MaterialApp(
          theme: NestTheme.light(),
          home: Scaffold(body: DashboardTab(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 확인
      expect(find.text('우리집 홈스쿨 이름을 정해 볼까요?'), findsOneWidget);
      expect(find.text('다음 · 수업 템플릿 고르기'), findsOneWidget);
      expect(find.text('기본 시간표(9시~18시)로 1초 만에 바로 열기'), findsOneWidget);

      // 추천 이름 칩 탭 -> 즉시 반영
      await tester.tap(find.text('조이 홈스쿨'));
      await tester.pump();

      // 다음 단계 버튼 탭 -> 네트워크 대기 없이 즉시 2단계 펼침
      await tester.tap(find.text('다음 · 수업 템플릿 고르기'));
      await tester.pumpAndSettle();

      expect(find.text('홈스쿨 이름: 조이 홈스쿨'), findsOneWidget);
      expect(find.text('어떤 수업으로 시간표를 채울까요?'), findsOneWidget);

      // 첫 아이 이름 입력
      await tester.enterText(
        find.widgetWithText(TextField, '첫 아이 이름 (선택)'),
        '하준',
      );
      await tester.pump();

      // 시작하기 버튼 탭
      final startButton = find.text('우리집 홈스쿨 시작하기');
      await tester.ensureVisible(startButton);
      await tester.pumpAndSettle();
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(controller.bootstrapCalled, isTrue);
      expect(controller.lastHomeschoolName, '조이 홈스쿨');
      expect(controller.quickAddCalled, isTrue);
      expect(controller.lastPlacementCount, greaterThan(0));
      expect(controller.childRegistered, isTrue);
      expect(controller.lastChildName, '하준');
    },
  );

  testWidgets(
    'DashboardTab 1-click quick start creates homeschool with default schedule from Step 1',
    (tester) async {
      final controller = _FakeProgressiveOnboardingController();
      await tester.pumpWidget(
        MaterialApp(
          theme: NestTheme.light(),
          home: Scaffold(body: DashboardTab(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();

      final quickButton = find.text('기본 시간표(9시~18시)로 1초 만에 바로 열기');
      await tester.ensureVisible(quickButton);
      await tester.tap(quickButton);
      await tester.pumpAndSettle();

      expect(controller.bootstrapCalled, isTrue);
      expect(controller.quickAddCalled, isTrue);
      expect(controller.lastPlacementCount, greaterThan(0));
    },
  );
}
