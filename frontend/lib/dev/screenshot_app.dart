// 매뉴얼 스크린샷/데모 전용 엔트리포인트 (프로덕션 빌드에 포함되지 않음 —
// `-t lib/dev/screenshot_app.dart`로 지정했을 때만 빌드된다).
//
// 실제 위젯 트리(HomePage 이하)를 네트워크/로그인 없이 렌더링한다.
// NestRepository를 픽스처를 돌려주는 가짜로 바꿔치기하고, 컨트롤러 공개
// 필드에 데모 데이터를 채운 뒤 HomePage를 직접 띄운다.
//
// 실행:
//   flutter run -d web-server --web-port=8123 -t lib/dev/screenshot_app.dart
// 쿼리 파라미터:
//   ?role=parent (기본) | ?role=teacher

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../src/models/nest_models.dart';
import '../src/services/nest_cache.dart';
import '../src/services/nest_repository.dart';
import '../src/state/nest_controller.dart';
import '../src/ui/home_page.dart';
import '../src/ui/nest_theme.dart';

// ── 픽스처 ──────────────────────────────────────────────────────────────

const _hsId = 'hs-demo';
const _parentUserId = 'u-parent';
const _teacherUserId = 'u-teacher';

final _terms = [
  Term.fromMap({
    'id': 'term-spring',
    'homeschool_id': _hsId,
    'name': '2026-봄학기',
    'status': 'ACTIVE',
    'start_date': '2026-03-02',
    'end_date': '2026-06-30',
  }),
  Term.fromMap({
    'id': 'term-summer',
    'homeschool_id': _hsId,
    'name': '2026-여름학기',
    'status': 'ACTIVE',
    'start_date': '2026-07-01',
    'end_date': '2026-08-31',
  }),
  Term.fromMap({
    'id': 'term-fall',
    'homeschool_id': _hsId,
    'name': '2026-가을학기',
    'status': 'DRAFT',
    'start_date': '2026-09-01',
    'end_date': '2026-11-30',
  }),
];

final _classGroups = [
  ClassGroup.fromMap({
    'id': 'cg-saessak',
    'term_id': 'term-summer',
    'name': '새싹반',
    'capacity': 8,
  }),
  ClassGroup.fromMap({
    'id': 'cg-yeolmae',
    'term_id': 'term-summer',
    'name': '열매반',
    'capacity': 8,
  }),
];

final _courses = [
  for (final row in [
    ['c-kor', '국어'],
    ['c-math', '수학'],
    ['c-sci', '과학'],
    ['c-eng', '영어'],
    ['c-art', '미술'],
    ['c-pe', '체육'],
  ])
    Course.fromMap({
      'id': row[0],
      'homeschool_id': _hsId,
      'name': row[1],
      'default_duration_min': 50,
    }),
];

// 월(1)~금(5) × 3교시.
final _timeSlots = [
  for (var day = 1; day <= 5; day++)
    for (final row in [
      ['a', '09:00:00', '09:50:00'],
      ['b', '10:00:00', '10:50:00'],
      ['c', '11:00:00', '11:50:00'],
    ])
      TimeSlot.fromMap({
        'id': 'slot-$day-${row[0]}',
        'term_id': 'term-summer',
        'day_of_week': day,
        'start_time': row[1],
        'end_time': row[2],
      }),
];

ClassSession _session(String id, String cg, String course, String slot) =>
    ClassSession.fromMap({
      'id': id,
      'class_group_id': cg,
      'course_id': course,
      'time_slot_id': slot,
      'title': '',
      'source_type': 'MANUAL',
      'status': 'PLANNED',
      'location': '거실',
    });

// 새싹반 주간 시간표.
final _saessakSessions = [
  _session('ss-1', 'cg-saessak', 'c-kor', 'slot-1-a'),
  _session('ss-2', 'cg-saessak', 'c-math', 'slot-1-b'),
  _session('ss-3', 'cg-saessak', 'c-eng', 'slot-1-c'),
  _session('ss-4', 'cg-saessak', 'c-math', 'slot-2-a'),
  _session('ss-5', 'cg-saessak', 'c-sci', 'slot-2-b'),
  _session('ss-6', 'cg-saessak', 'c-art', 'slot-2-c'),
  _session('ss-7', 'cg-saessak', 'c-kor', 'slot-3-a'),
  _session('ss-8', 'cg-saessak', 'c-math', 'slot-3-b'),
  _session('ss-9', 'cg-saessak', 'c-eng', 'slot-3-c'),
  _session('ss-10', 'cg-saessak', 'c-sci', 'slot-4-a'),
  _session('ss-11', 'cg-saessak', 'c-kor', 'slot-4-b'),
  _session('ss-12', 'cg-saessak', 'c-pe', 'slot-5-a'),
  _session('ss-13', 'cg-saessak', 'c-art', 'slot-5-b'),
];

// 열매반 주간 시간표.
final _yeolmaeSessions = [
  _session('ym-1', 'cg-yeolmae', 'c-math', 'slot-1-a'),
  _session('ym-2', 'cg-yeolmae', 'c-kor', 'slot-1-b'),
  _session('ym-3', 'cg-yeolmae', 'c-sci', 'slot-2-a'),
  _session('ym-4', 'cg-yeolmae', 'c-eng', 'slot-2-b'),
  _session('ym-5', 'cg-yeolmae', 'c-kor', 'slot-3-a'),
  _session('ym-6', 'cg-yeolmae', 'c-math', 'slot-3-b'),
  _session('ym-7', 'cg-yeolmae', 'c-pe', 'slot-4-a'),
  _session('ym-8', 'cg-yeolmae', 'c-art', 'slot-4-b'),
  _session('ym-9', 'cg-yeolmae', 'c-sci', 'slot-5-a'),
  _session('ym-10', 'cg-yeolmae', 'c-eng', 'slot-5-b'),
];

final _sessions = [..._saessakSessions, ..._yeolmaeSessions];

final _teacherProfiles = [
  TeacherProfile.fromMap({
    'id': 'tp-boram',
    'homeschool_id': _hsId,
    'user_id': _teacherUserId,
    'display_name': '이보람',
    'teacher_type': 'REGULAR',
    'specialties': ['수학', '과학'],
    'bio': '',
  }),
  TeacherProfile.fromMap({
    'id': 'tp-sol',
    'homeschool_id': _hsId,
    'user_id': 'u-sol',
    'display_name': '김솔',
    'teacher_type': 'REGULAR',
    'specialties': ['국어', '영어'],
    'bio': '',
  }),
  TeacherProfile.fromMap({
    'id': 'tp-han',
    'homeschool_id': _hsId,
    'user_id': 'u-han',
    'display_name': '박한결',
    'teacher_type': 'GUEST',
    'specialties': ['미술', '체육'],
    'bio': '',
  }),
];

String _teacherFor(String courseId) => switch (courseId) {
      'c-math' || 'c-sci' => 'tp-boram',
      'c-kor' || 'c-eng' => 'tp-sol',
      _ => 'tp-han',
    };

final _assignments = [
  for (final session in _sessions)
    SessionTeacherAssignment.fromMap({
      'id': 'as-${session.id}',
      'class_session_id': session.id,
      'teacher_profile_id': _teacherFor(session.courseId),
      'assignment_role': 'MAIN',
    }),
];

final _families = [
  Family.fromMap({
    'id': 'fam-kim',
    'homeschool_id': _hsId,
    'family_name': '김씨네',
    'note': '',
    'created_at': '2026-01-05T00:00:00Z',
  }),
];

final _children = [
  ChildProfile.fromMap({
    'id': 'child-yeseung',
    'family_id': 'fam-kim',
    'name': '예승',
    'birth_date': '2018-04-12',
    'status': 'ACTIVE',
    'profile_note': '',
    'created_at': '2026-01-05T00:00:00Z',
    'families': {'family_name': '김씨네'},
  }),
  ChildProfile.fromMap({
    'id': 'child-yejun',
    'family_id': 'fam-kim',
    'name': '예준',
    'birth_date': '2020-09-02',
    'status': 'ACTIVE',
    'profile_note': '',
    'created_at': '2026-01-05T00:00:00Z',
    'families': {'family_name': '김씨네'},
  }),
];

final _enrollments = [
  ClassEnrollment.fromMap({
    'id': 'en-1',
    'class_group_id': 'cg-saessak',
    'child_id': 'child-yeseung',
    'created_at': '2026-07-01T00:00:00Z',
  }),
  ClassEnrollment.fromMap({
    'id': 'en-2',
    'class_group_id': 'cg-yeolmae',
    'child_id': 'child-yejun',
    'created_at': '2026-07-01T00:00:00Z',
  }),
];

final _announcements = [
  Announcement.fromMap({
    'id': 'an-1',
    'homeschool_id': _hsId,
    'class_group_id': null,
    'author_user_id': _teacherUserId,
    'title': '여름학기 운영 안내',
    'body': '7월 1일부터 여름학기 시간표로 운영합니다. 준비물은 반별 공지를 확인해 주세요.',
    'pinned': true,
    'created_at': '2026-07-01T09:00:00Z',
  }),
  Announcement.fromMap({
    'id': 'an-2',
    'homeschool_id': _hsId,
    'class_group_id': 'cg-saessak',
    'author_user_id': _teacherUserId,
    'title': '새싹반 과학 실험 준비물',
    'body': '수요일 과학 시간에 쓸 페트병 1개를 챙겨 주세요.',
    'pinned': false,
    'created_at': '2026-07-15T10:00:00Z',
  }),
];

Membership _membership(String userId, String role) => Membership.fromMap({
      'user_id': userId,
      'homeschool_id': _hsId,
      'role': role,
      'status': 'ACTIVE',
      'homeschools': {
        'id': _hsId,
        'name': '우리집 홈스쿨',
        'join_code': 'DEMO01',
        'timezone': 'Asia/Seoul',
      },
    });

// ── 가짜 리포지토리 ─────────────────────────────────────────────────────

class _FakeNestRepository extends NestRepository {
  _FakeNestRepository()
      : super(
          SupabaseClient(
            'http://localhost',
            'demo-key',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          ),
        );

  @override
  Future<List<Term>> fetchTerms({required String homeschoolId}) async => _terms;

  @override
  Future<List<ClassGroup>> fetchClassGroups({required String termId}) async =>
      _classGroups.where((g) => g.termId == termId).toList();

  @override
  Future<List<Course>> fetchCourses({required String homeschoolId}) async =>
      _courses;

  @override
  Future<List<Classroom>> fetchClassrooms({required String termId}) async =>
      const [];

  @override
  Future<List<TimeSlot>> fetchTimeSlots({required String termId}) async =>
      _timeSlots.where((s) => s.termId == termId).toList();

  @override
  Future<List<ClassSession>> fetchSessions({
    required String classGroupId,
  }) async =>
      _sessions.where((s) => s.classGroupId == classGroupId).toList();

  @override
  Future<List<ClassSession>> fetchSessionsForClassGroups({
    required List<String> classGroupIds,
  }) async =>
      _sessions.where((s) => classGroupIds.contains(s.classGroupId)).toList();

  @override
  Future<List<Proposal>> fetchProposals({required String termId}) async =>
      const [];

  @override
  Future<List<ClassEnrollment>> fetchClassEnrollments({
    required List<String> classGroupIds,
  }) async =>
      _enrollments.where((e) => classGroupIds.contains(e.classGroupId)).toList();

  @override
  Future<List<SessionTeacherAssignment>> fetchSessionTeacherAssignments({
    required List<String> classSessionIds,
  }) async =>
      _assignments
          .where((a) => classSessionIds.contains(a.classSessionId))
          .toList();

  @override
  Future<List<TeachingPlan>> fetchTeachingPlans({
    required List<String> classSessionIds,
  }) async =>
      const [];

  @override
  Future<List<Announcement>> fetchAnnouncements({
    required String homeschoolId,
  }) async =>
      _announcements;

  @override
  Future<List<AcademicEvent>> fetchAcademicEvents({
    required String homeschoolId,
    String? termId,
  }) async =>
      const [];

  @override
  Future<List<GalleryItem>> fetchGalleryItems({
    required String homeschoolId,
    required String? classGroupId,
  }) async =>
      const [];

  @override
  Future<Map<String, List<String>>> fetchMediaChildrenByAsset({
    required List<String> mediaAssetIds,
  }) async =>
      const {};

  @override
  Future<List<CommunityPost>> fetchCommunityPosts({
    required String homeschoolId,
  }) async =>
      const [];

  @override
  Future<List<SelfStudyPlan>> fetchSelfStudyPlans({
    required String termId,
  }) async =>
      const [];

  @override
  Future<List<SelfStudySlot>> fetchSelfStudySlots({
    required List<String> planIds,
  }) async =>
      const [];

  @override
  Future<List<SelfStudySlotExclusion>> fetchSelfStudyExclusions({
    required List<String> slotIds,
  }) async =>
      const [];

  @override
  Future<List<SelfStudySupervision>> fetchSelfStudySupervisions({
    required List<String> planIds,
  }) async =>
      const [];
}

// ── 엔트리포인트 ────────────────────────────────────────────────────────

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[demo] binding ready');
  // NestCache는 모든 메서드가 _prefs null에 안전하므로 초기화를 기다리지 않는다
  // (SharedPreferences 초기화가 지연/실패해도 데모 렌더링에는 영향 없음).
  unawaited(
    NestCache.initialize().then((_) => debugPrint('[demo] cache ready')),
  );

  final role = Uri.base.queryParameters['role'] ?? 'parent';
  final isTeacher = role == 'teacher';

  final controller = NestController(repository: _FakeNestRepository());

  controller.user = User(
    id: isTeacher ? _teacherUserId : _parentUserId,
    appMetadata: const {},
    userMetadata: {'full_name': isTeacher ? '이보람' : '김하늘'},
    aud: 'authenticated',
    createdAt: '2026-01-01T00:00:00Z',
  );
  controller.memberships = [
    _membership(
      isTeacher ? _teacherUserId : _parentUserId,
      isTeacher ? 'TEACHER' : 'PARENT',
    ),
  ];
  controller.selectedHomeschoolId = _hsId;
  controller.currentRole = isTeacher ? 'TEACHER' : 'PARENT';
  controller.terms = _terms;
  controller.selectedTermId = 'term-summer';
  controller.classGroups = _classGroups;
  controller.selectedClassGroupId = 'cg-saessak';
  controller.courses = _courses;
  controller.timeSlots = _timeSlots;
  controller.sessions = _sessions;
  controller.classEnrollments = _enrollments;
  controller.families = _families;
  controller.children = _children;
  controller.familyGuardianUserIdsByFamily = {
    'fam-kim': [_parentUserId],
  };
  controller.teacherProfiles = _teacherProfiles;
  controller.sessionTeacherAssignments = _assignments;
  controller.announcements = _announcements;

  debugPrint('[demo] runApp');
  runApp(
    MaterialApp(
      title: 'Nest 데모',
      debugShowCheckedModeBanner: false,
      theme: NestTheme.light(),
      home: HomePage(controller: controller),
    ),
  );
}
