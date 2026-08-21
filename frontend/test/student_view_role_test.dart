import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nest_frontend/src/models/nest_models.dart';
import 'package:nest_frontend/src/services/nest_repository.dart';
import 'package:nest_frontend/src/state/nest_controller.dart';

Membership _membership(String userId, String role, {String status = 'ACTIVE'}) =>
    Membership.fromMap({
      'user_id': userId,
      'homeschool_id': 's1',
      'role': role,
      'status': status,
    });

ChildProfile _child(String id, String name, {String? userId}) =>
    ChildProfile.fromMap({
      'id': id,
      'family_id': 'f1',
      'name': name,
      'birth_date': '2015-03-01',
      'status': 'ACTIVE',
      'user_id': userId,
    });

ClassSessionChange _change({
  required String id,
  required String from,
  String? to,
  String sessionId = 'cs1',
  String changeType = 'NOTE',
  String? createdAt,
}) => ClassSessionChange.fromMap({
  'id': id,
  'class_session_id': sessionId,
  'change_type': changeType,
  'effective_from': from,
  'effective_to': to,
  'reason': id,
  'created_at': createdAt ?? '2026-08-01T00:00:00Z',
});

AbsenceReport _absence({
  required String id,
  required String childId,
  required String date,
  String sessionId = 'cs1',
  String status = 'SUBMITTED',
}) => AbsenceReport.fromMap({
  'id': id,
  'class_session_id': sessionId,
  'child_id': childId,
  'occurrence_date': date,
  'reported_by_user_id': 'u-parent',
  'status': status,
});

// 네트워크를 타지 않는 컨트롤러. 검증 대상 getter 들은 모두 메모리 캐시만
// 읽는다. autoRefreshToken 을 꺼야 GoTrue 타이머가 남지 않는다.
NestController _controller() {
  final client = SupabaseClient(
    'http://localhost',
    'test-key',
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  return NestController(repository: NestRepository(client));
}

void main() {
  group('STUDENT 뷰 역할', () {
    test('currentRole 이 STUDENT 일 때만 학생 뷰다', () {
      final controller = _controller();

      controller.currentRole = 'STUDENT';
      expect(controller.isStudentView, isTrue);
      expect(controller.isParentView, isFalse);
      expect(controller.isTeacherView, isFalse);
      expect(controller.isAdminLike, isFalse);

      controller.currentRole = 'PARENT';
      expect(controller.isStudentView, isFalse);
    });

    test('학생은 미디어 업로드와 커뮤니티 글쓰기를 할 수 없고 읽기는 가능하다', () {
      final controller = _controller();
      controller.currentRole = 'STUDENT';

      expect(controller.canUploadMedia, isFalse);
      expect(controller.canWriteCommunity, isFalse);
      expect(controller.canWriteAnnouncement, isFalse);
      expect(controller.canReadCommunity, isTrue);
      expect(controller.canReportAbsence, isTrue);
      expect(controller.canManageClassSessionChanges, isFalse);
    });

    test('hasStudentViewRole 은 활성 STUDENT 멤버십만 인정한다', () {
      final controller = _controller();
      controller.homeschoolMemberships = [
        _membership('u-student', 'STUDENT'),
        _membership('u-left', 'STUDENT', status: 'INACTIVE'),
        _membership('u-parent', 'PARENT'),
      ];

      expect(controller.hasStudentViewRole('u-student'), isTrue);
      expect(controller.hasStudentViewRole('u-left'), isFalse);
      expect(controller.hasStudentViewRole('u-parent'), isFalse);
      expect(controller.hasStudentViewRole('u-unknown'), isFalse);
    });

    test('STUDENT 는 뷰 역할 우선순위에서 가장 마지막이다', () {
      final controller = _controller();
      controller.memberships = [
        _membership('u-me', 'STUDENT'),
        _membership('u-me', 'PARENT'),
      ];
      controller.selectedHomeschoolId = 's1';

      expect(controller.availableViewRoles, ['PARENT', 'STUDENT']);
      expect(controller.rolesForHomeschool('s1'), ['PARENT', 'STUDENT']);
    });

    test('currentUserChildProfiles 는 내 계정에 연결된 아이만 이름 순으로 돌려준다', () {
      final controller = _controller();
      controller.children = [
        _child('c-2', '유나', userId: 'u-student'),
        _child('c-1', '서준', userId: 'u-student'),
        _child('c-3', '남의집아이', userId: 'u-other'),
        _child('c-4', '계정없는아이'),
      ];

      // user 가 null 이면(비로그인) 빈 목록.
      expect(controller.currentUserChildProfiles, isEmpty);
      expect(controller.activeStudentChildId, isNull);

      // 계정 연결 여부는 hasAccount 로 판정한다(계정 없는 c-4 는 후보에서 빠진다).
      // 정렬은 이름 기준: 남의집아이(c-3) → 서준(c-1) → 유나(c-2).
      expect(controller.studentViewCandidateChildren.map((c) => c.id), [
        'c-3',
        'c-1',
        'c-2',
      ]);
    });
  });

  group('effectiveChangeFor 우선순위', () {
    final date = DateTime(2026, 9, 3);

    test('단일 날짜 변경이 기간·학기 전체 변경을 이긴다', () {
      final controller = _controller();
      controller.classSessionChanges = [
        _change(id: 'rest-of-term', from: '2026-09-01'),
        _change(id: 'range', from: '2026-09-01', to: '2026-09-30'),
        _change(id: 'single', from: '2026-09-03', to: '2026-09-03'),
      ];

      final resolved = controller.effectiveChangeFor(
        sessionId: 'cs1',
        date: date,
      );
      expect(resolved?.id, 'single');
    });

    test('단일 날짜가 없으면 유한 기간이 학기 전체를 이긴다', () {
      final controller = _controller();
      controller.classSessionChanges = [
        _change(id: 'rest-of-term', from: '2026-09-01'),
        _change(id: 'range', from: '2026-09-01', to: '2026-09-30'),
      ];

      expect(
        controller.effectiveChangeFor(sessionId: 'cs1', date: date)?.id,
        'range',
      );
    });

    test('같은 순위면 나중에 등록한 변경이 이긴다', () {
      final controller = _controller();
      controller.classSessionChanges = [
        _change(
          id: 'old',
          from: '2026-09-03',
          to: '2026-09-03',
          createdAt: '2026-08-01T00:00:00Z',
        ),
        _change(
          id: 'new',
          from: '2026-09-03',
          to: '2026-09-03',
          createdAt: '2026-08-10T00:00:00Z',
        ),
      ];

      expect(
        controller.effectiveChangeFor(sessionId: 'cs1', date: date)?.id,
        'new',
      );
    });

    test('적용 기간 밖이거나 다른 수업이면 null 이다', () {
      final controller = _controller();
      controller.classSessionChanges = [
        _change(id: 'range', from: '2026-09-10', to: '2026-09-20'),
        _change(id: 'other', from: '2026-09-01', sessionId: 'cs2'),
      ];

      expect(controller.effectiveChangeFor(sessionId: 'cs1', date: date), isNull);
      expect(
        controller
            .effectiveChangeFor(sessionId: 'cs1', date: DateTime(2026, 9, 10))
            ?.id,
        'range',
      );
    });

    test('changesForSession 은 해당 수업 것만 시작일 순으로 돌려준다', () {
      final controller = _controller();
      controller.classSessionChanges = [
        _change(id: 'later', from: '2026-09-20'),
        _change(id: 'earlier', from: '2026-09-01'),
        _change(id: 'other', from: '2026-09-05', sessionId: 'cs2'),
      ];

      expect(controller.changesForSession('cs1').map((c) => c.id), [
        'earlier',
        'later',
      ]);
    });
  });

  group('결석 신고 조회 헬퍼', () {
    test('absencesForChild / absencesForSession 은 최근 회차부터 돌려준다', () {
      final controller = _controller();
      controller.absenceReports = [
        _absence(id: 'a1', childId: 'c-1', date: '2026-09-03'),
        _absence(id: 'a2', childId: 'c-1', date: '2026-09-10'),
        _absence(id: 'a3', childId: 'c-2', date: '2026-09-17'),
        _absence(
          id: 'a4',
          childId: 'c-1',
          date: '2026-09-24',
          sessionId: 'cs2',
        ),
      ];

      expect(controller.absencesForChild('c-1').map((r) => r.id), [
        'a4',
        'a2',
        'a1',
      ]);
      expect(controller.absencesForSession('cs1').map((r) => r.id), [
        'a3',
        'a2',
        'a1',
      ]);
    });

    test('absenceFor 는 철회된 신고를 무시한다', () {
      final controller = _controller();
      controller.absenceReports = [
        _absence(
          id: 'canceled',
          childId: 'c-1',
          date: '2026-09-03',
          status: 'CANCELED',
        ),
        _absence(id: 'live', childId: 'c-2', date: '2026-09-03'),
      ];

      final found = controller.absenceFor(
        sessionId: 'cs1',
        date: DateTime(2026, 9, 3, 13, 40),
      );
      expect(found?.id, 'live');
      expect(
        controller.absenceFor(sessionId: 'cs1', date: DateTime(2026, 9, 4)),
        isNull,
      );
    });

    test('absenceFor 는 childId 를 주면 그 아이의 신고만 고른다 (같은 반 형제)', () {
      final controller = _controller();
      // 같은 반, 같은 날짜에 형제 두 명이 각각 신고한 상황.
      controller.absenceReports = [
        _absence(id: 'sibling', childId: 'c-1', date: '2026-09-03'),
        _absence(id: 'mine', childId: 'c-2', date: '2026-09-03'),
      ];

      expect(
        controller
            .absenceFor(
              sessionId: 'cs1',
              date: DateTime(2026, 9, 3),
              childId: 'c-2',
            )
            ?.id,
        'mine',
      );
      expect(
        controller
            .absenceFor(
              sessionId: 'cs1',
              date: DateTime(2026, 9, 3),
              childId: 'c-1',
            )
            ?.id,
        'sibling',
      );
      // 신고하지 않은 아이는 형제 신고를 자기 것으로 보면 안 된다.
      expect(
        controller.absenceFor(
          sessionId: 'cs1',
          date: DateTime(2026, 9, 3),
          childId: 'c-3',
        ),
        isNull,
      );
    });

    test('pendingAbsencesForTeacher 는 관리자 뷰에서 전체 SUBMITTED 를 날짜 순으로 본다', () {
      final controller = _controller();
      controller.currentRole = 'HOMESCHOOL_ADMIN';
      controller.absenceReports = [
        _absence(id: 'late', childId: 'c-1', date: '2026-09-17'),
        _absence(id: 'early', childId: 'c-2', date: '2026-09-03'),
        _absence(
          id: 'done',
          childId: 'c-3',
          date: '2026-09-05',
          status: 'ACKNOWLEDGED',
        ),
      ];

      expect(controller.pendingAbsencesForTeacher().map((r) => r.id), [
        'early',
        'late',
      ]);
    });

    test('담당 교사 프로필이 없으면 대기 결석 신고도 없다', () {
      final controller = _controller();
      controller.currentRole = 'TEACHER';
      controller.absenceReports = [
        _absence(id: 'a1', childId: 'c-1', date: '2026-09-03'),
      ];

      expect(controller.pendingAbsencesForTeacher(), isEmpty);
    });
  });
}
