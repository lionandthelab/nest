import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';
import 'package:nest_frontend/src/ui/models/admin_self_setup.dart';
import 'package:nest_frontend/src/ui/nest_theme.dart';
import 'package:nest_frontend/src/ui/widgets/admin_self_setup_card.dart';

NestController _admin({List<String> extraRoles = const []}) {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final controller = NestController(repository: NestRepository(client));
  controller.user = User(
    id: 'u-1',
    appMetadata: const {},
    userMetadata: const {'real_name': '김하늘'},
    aud: 'authenticated',
    createdAt: '2026-09-24T00:00:00Z',
  );
  controller.currentRole = 'HOMESCHOOL_ADMIN';
  controller.selectedHomeschoolId = 'hs-1';
  controller.selectedTermId = 't-1';
  controller.memberships = [
    for (final role in ['HOMESCHOOL_ADMIN', ...extraRoles])
      Membership.fromMap({
        'user_id': 'u-1',
        'homeschool_id': 'hs-1',
        'role': role,
        'status': 'ACTIVE',
        'homeschools': {'id': 'hs-1', 'name': '하늘 홈스쿨'},
      }),
  ];
  controller.terms = [
    Term.fromMap({
      'id': 't-1',
      'homeschool_id': 'hs-1',
      'name': '2026 가을학기',
      'status': 'DRAFT',
    }),
  ];
  return controller;
}

Future<void> _pumpCard(WidgetTester tester, NestController controller) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: NestTheme.light(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: AdminSelfSetupCard(controller: controller),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('관리자 빠른 설정 판단', () {
    test('새 홈스쿨이면 가정·학부모·선생님·교실을 모두 권한다', () {
      expect(
        pendingSelfSetupActions(
          hasOwnFamily: false,
          isParent: false,
          hasTeacherProfile: false,
          hasTerm: true,
          classroomCount: 0,
        ),
        [
          SelfSetupAction.family,
          SelfSetupAction.parent,
          SelfSetupAction.teacher,
          SelfSetupAction.classroom,
        ],
      );
    });

    test('이미 된 항목은 다시 권하지 않는다', () {
      expect(
        pendingSelfSetupActions(
          hasOwnFamily: true,
          isParent: true,
          hasTeacherProfile: true,
          hasTerm: true,
          classroomCount: 1,
        ),
        isEmpty,
      );
    });

    test('학기가 없으면 교실은 권하지 않는다 (교실은 학기 소속)', () {
      expect(
        pendingSelfSetupActions(
          hasOwnFamily: true,
          isParent: true,
          hasTeacherProfile: true,
          hasTerm: false,
          classroomCount: 0,
        ),
        isEmpty,
      );
    });
  });

  test('새 학기 틀을 만들 때 교실 "집"이 하나 들어간다', () {
    final rows = NestRepository.bootstrapClassroomRows(termId: 't-1');
    expect(rows, hasLength(1));
    expect(rows.single['term_id'], 't-1');
    expect(rows.single['name'], '집');
  });

  group('빠른 설정 카드', () {
    testWidgets('새 관리자에게 네 버튼을 바로 보여 준다', (tester) async {
      await _pumpCard(tester, _admin());

      expect(find.text('우리 가정 만들기'), findsOneWidget);
      expect(find.text('학부모로 등록'), findsOneWidget);
      expect(find.text('선생님으로 등록'), findsOneWidget);
      expect(find.text("'집' 교실 추가"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('내 가정·학부모·선생님·교실이 있으면 카드가 사라진다', (tester) async {
      final controller = _admin(extraRoles: ['PARENT']);
      controller.families = [
        Family.fromMap({
          'id': 'f-1',
          'homeschool_id': 'hs-1',
          'family_name': '김하늘 가정',
        }),
      ];
      controller.familyGuardianUserIdsByFamily = const {
        'f-1': ['u-1'],
      };
      controller.teacherProfiles = [
        TeacherProfile.fromMap({
          'id': 'tp-1',
          'homeschool_id': 'hs-1',
          'user_id': 'u-1',
          'display_name': '김하늘',
          'teacher_type': 'PARENT_TEACHER',
        }),
      ];
      controller.classrooms = [
        Classroom.fromMap({'id': 'c-1', 'term_id': 't-1', 'name': '집'}),
      ];

      await _pumpCard(tester, controller);

      expect(find.text('우리 가정 만들기'), findsNothing);
      expect(find.text('선생님으로 등록'), findsNothing);
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('학부모 역할만 있으면 그 버튼만 빠진다', (tester) async {
      await _pumpCard(tester, _admin(extraRoles: ['PARENT']));

      expect(find.text('학부모로 등록'), findsNothing);
      expect(find.text('우리 가정 만들기'), findsOneWidget);
      expect(find.text('선생님으로 등록'), findsOneWidget);
    });
  });
}
