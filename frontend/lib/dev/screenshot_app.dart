// 매뉴얼 스크린샷/데모 전용 엔트리포인트 (프로덕션 빌드에 포함되지 않음 —
// `-t lib/dev/screenshot_app.dart`로 지정했을 때만 빌드된다).
//
// 실제 위젯 트리(HomePage 이하)를 네트워크/로그인 없이 렌더링한다.
// NestRepository를 픽스처를 돌려주는 가짜로 바꿔치기하고, 컨트롤러 공개
// 필드에 데모 데이터를 채운 뒤 HomePage를 직접 띄운다.
//
// 실행:
//   flutter run -d web-server --web-port=8123 -t lib/dev/screenshot_app.dart
// 쿼리 파라미터(웹):
//   ?role=parent (기본) | ?role=teacher
// dart-define(네이티브 시뮬레이터 캡처용, 쿼리 파라미터보다 우선):
//   --dart-define=ROLE=parent|teacher  --dart-define=TAB=0 (초기 탭 인덱스)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../src/models/nest_models.dart';
import '../src/services/nest_cache.dart';
import '../src/services/album_organizer.dart';
import '../src/services/nest_repository.dart';
import '../src/state/nest_controller.dart';
import '../src/ui/home_page.dart';
import '../src/ui/nest_theme.dart';
import '../src/ui/widgets/notification_onboarding.dart';

// ── 픽스처 ──────────────────────────────────────────────────────────────

const _hsId = 'hs-demo';
const _parentUserId = 'u-parent';
const _teacherUserId = 'u-teacher';

// 학기 날짜는 오늘을 기준으로 잡는다.
//
// 고정 날짜로 두면 그 날짜가 지나는 순간 데모가 조용히 망가진다. 수업이 걸린
// 학기가 "지난 학기"가 되어 오늘의 수업·개인 일정이 비어 버리고, 개인 일정을
// 넣어도 학기 범위 밖이라 목록에 나타나지 않는다.
final _today = DateTime.now();
String _isoDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

/// 수업이 걸려 있는 "현재" 학기. 오늘이 항상 이 안에 들어온다.
final _currentTermStart = DateTime(_today.year, _today.month, 1);
final _currentTermEnd = DateTime(_today.year, _today.month + 4, 0);

final _terms = [
  Term.fromMap({
    'id': 'term-spring',
    'homeschool_id': _hsId,
    'name': '지난 학기',
    'status': 'ACTIVE',
    'start_date': _isoDate(DateTime(_today.year, _today.month - 8, 1)),
    'end_date': _isoDate(DateTime(_today.year, _today.month - 4, 0)),
  }),
  Term.fromMap({
    'id': 'term-summer',
    'homeschool_id': _hsId,
    'name': '이번 학기',
    'status': 'ACTIVE',
    'start_date': _isoDate(_currentTermStart),
    'end_date': _isoDate(_currentTermEnd),
  }),
  Term.fromMap({
    'id': 'term-fall',
    'homeschool_id': _hsId,
    'name': '다음 학기',
    'status': 'DRAFT',
    'start_date': _isoDate(DateTime(_today.year, _today.month + 4, 1)),
    'end_date': _isoDate(DateTime(_today.year, _today.month + 8, 0)),
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
    'title': '이번 학기 운영 안내',
    'body': '이번 주부터 새 시간표로 운영합니다. 준비물은 반별 공지를 확인해 주세요.',
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

final _academicEvents = [
  AcademicEvent.fromMap({
    'id': 'ae-1',
    'homeschool_id': _hsId,
    'term_id': 'term-summer',
    'title': '이번 학기 개강',
    'description': '',
    'event_date': _isoDate(_currentTermStart),
  }),
  AcademicEvent.fromMap({
    'id': 'ae-2',
    'homeschool_id': _hsId,
    'term_id': 'term-summer',
    'title': '가을 현장학습',
    'description': '전교생 숲 체험 — 여벌 옷과 수건을 챙겨 주세요.',
    'event_date': _isoDate(_currentTermStart.add(const Duration(days: 23))),
  }),
  AcademicEvent.fromMap({
    'id': 'ae-3',
    'homeschool_id': _hsId,
    'term_id': 'term-summer',
    'title': '이번 학기 발표회',
    'description': '',
    'event_date': _isoDate(_currentTermEnd.subtract(const Duration(days: 3))),
  }),
];

final _communityPosts = [
  CommunityPost.fromMap({
    'id': 'cp-1',
    'homeschool_id': _hsId,
    'class_group_id': null,
    'author_user_id': 'u-sol',
    'author_display_name': '김솔 선생님',
    'content':
        '오늘 국어 시간에 아이들이 직접 쓴 짧은 동시를 발표했어요. 표현이 정말 반짝반짝합니다. 사진은 갤러리에 올려두었어요 🌱',
    'is_hidden': false,
    'is_pinned': true,
    'created_at': '2026-07-20T13:20:00Z',
    'updated_at': '2026-07-20T13:20:00Z',
  }),
  CommunityPost.fromMap({
    'id': 'cp-2',
    'homeschool_id': _hsId,
    'class_group_id': 'cg-saessak',
    'author_user_id': _parentUserId,
    'author_display_name': '김하늘',
    'content': '이번 주 물놀이 현장학습 준비물, 수건 말고 더 챙길 게 있을까요? 처음이라 여쭤봐요 :)',
    'is_hidden': false,
    'is_pinned': false,
    'created_at': '2026-07-20T09:05:00Z',
    'updated_at': '2026-07-20T09:05:00Z',
  }),
  CommunityPost.fromMap({
    'id': 'cp-3',
    'homeschool_id': _hsId,
    'class_group_id': null,
    'author_user_id': 'u-han',
    'author_display_name': '박한결 선생님',
    'content': '다음 주 미술은 여름 풍경 그리기예요. 각자 좋아하는 색연필을 가져오면 더 즐겁게 할 수 있어요!',
    'is_hidden': false,
    'is_pinned': false,
    'created_at': '2026-07-19T16:40:00Z',
    'updated_at': '2026-07-19T16:40:00Z',
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
  }) async => _sessions.where((s) => s.classGroupId == classGroupId).toList();

  @override
  Future<List<ClassSession>> fetchSessionsForClassGroups({
    required List<String> classGroupIds,
  }) async =>
      _sessions.where((s) => classGroupIds.contains(s.classGroupId)).toList();

  @override
  Future<TermSchedulePack> fetchTermSchedulePack({
    required String termId,
  }) async => TermSchedulePack(sessions: _sessions, assignments: _assignments);

  @override
  Future<List<Proposal>> fetchProposals({required String termId}) async =>
      const [];

  @override
  Future<List<ClassEnrollment>> fetchClassEnrollments({
    required List<String> classGroupIds,
  }) async => _enrollments
      .where((e) => classGroupIds.contains(e.classGroupId))
      .toList();

  @override
  Future<List<SessionTeacherAssignment>> fetchSessionTeacherAssignments({
    required List<String> classSessionIds,
  }) async => _assignments
      .where((a) => classSessionIds.contains(a.classSessionId))
      .toList();

  @override
  Future<List<TeachingPlan>> fetchTeachingPlans({
    required List<String> classSessionIds,
  }) async => const [];

  @override
  Future<List<Announcement>> fetchAnnouncements({
    required String homeschoolId,
  }) async => _announcements;

  @override
  Future<List<AcademicEvent>> fetchAcademicEvents({
    required String homeschoolId,
    String? termId,
  }) async => const [];

  // ── 개인 일정: 유일하게 쓰기까지 흉내내는 영역 ──────────────────────────
  //
  // 나머지 기능은 읽기만 가짜로 바꿔도 화면이 나오는데, 개인 일정은 "추가" 를
  // 눌러 넣어 보는 것이 곧 확인이다. 쓰기를 그대로 두면 진짜 SupabaseClient 가
  // http://localhost 로 나가서 연결 거부(errno 61)로 떨어진다.
  final List<PersonalEvent> _personalEvents = [];
  int _personalEventSeq = 0;

  @override
  Future<List<PersonalEvent>> fetchPersonalEvents({
    required String homeschoolId,
    String? childId,
    DateTime? from,
    DateTime? to,
  }) async => _personalEvents
      .where((event) => childId == null || event.childId == childId)
      .where((event) => from == null || event.endsAt.isAfter(from))
      .where((event) => to == null || event.startsAt.isBefore(to))
      .toList();

  @override
  Future<PersonalEvent> createPersonalEvent({
    required String homeschoolId,
    required String ownerUserId,
    required String childId,
    required String title,
    required String notes,
    required DateTime startsAt,
    required DateTime endsAt,
    required String conflictPolicy,
  }) async {
    final event = PersonalEvent.fromMap({
      'id': 'pe-demo-${_personalEventSeq++}',
      'homeschool_id': homeschoolId,
      'owner_user_id': ownerUserId,
      'child_id': childId,
      'title': title.trim(),
      'notes': notes.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'conflict_policy': conflictPolicy,
      'source': 'NEST',
    });
    _personalEvents.add(event);
    return event;
  }

  @override
  Future<PersonalEvent> updatePersonalEvent({
    required String eventId,
    required String title,
    required String notes,
    required DateTime startsAt,
    required DateTime endsAt,
    required String conflictPolicy,
  }) async {
    final index = _personalEvents.indexWhere((event) => event.id == eventId);
    if (index < 0) {
      throw StateError('데모 데이터에 없는 일정입니다: $eventId');
    }
    final old = _personalEvents[index];
    final updated = PersonalEvent.fromMap({
      'id': old.id,
      'homeschool_id': old.homeschoolId,
      'owner_user_id': old.ownerUserId,
      'child_id': old.childId,
      'title': title.trim(),
      'notes': notes.trim(),
      'starts_at': startsAt.toUtc().toIso8601String(),
      'ends_at': endsAt.toUtc().toIso8601String(),
      'conflict_policy': conflictPolicy,
      'source': old.source,
    });
    _personalEvents[index] = updated;
    return updated;
  }

  @override
  Future<void> deletePersonalEvent({required String eventId}) async {
    _personalEvents.removeWhere((event) => event.id == eventId);
  }

  @override
  Future<CalendarIntegration?> fetchCalendarIntegration() async => null;

  NotificationPrefs _notificationPrefs = const NotificationPrefs();

  @override
  Future<NotificationPrefs> fetchNotificationPrefs() async =>
      _notificationPrefs;

  @override
  Future<void> upsertNotificationPrefs(NotificationPrefs prefs) async {
    _notificationPrefs = prefs;
  }

  @override
  Future<List<GalleryItem>> fetchAlbumPage({
    required String homeschoolId,
    String? termId,
    String? classGroupId,
    String? courseId,
    String? mediaType,
    AlbumCursor? cursor,
    int limit = 60,
  }) async => const [];

  @override
  Future<List<AlbumSummary>> fetchAlbumSummaries({
    required String homeschoolId,
  }) async => const [];

  @override
  Future<Map<String, List<String>>> fetchMediaChildrenByAsset({
    required List<String> mediaAssetIds,
  }) async => const {};

  @override
  Future<List<CommunityPost>> fetchCommunityPosts({
    required String homeschoolId,
  }) async => const [];

  @override
  Future<List<SelfStudyPlan>> fetchSelfStudyPlans({
    required String termId,
  }) async => const [];

  @override
  Future<List<SelfStudySlot>> fetchSelfStudySlots({
    required List<String> planIds,
  }) async => const [];

  @override
  Future<List<SelfStudySlotExclusion>> fetchSelfStudyExclusions({
    required List<String> slotIds,
  }) async => const [];

  @override
  Future<List<SelfStudySupervision>> fetchSelfStudySupervisions({
    required List<String> planIds,
  }) async => const [];
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

  // dart-define(ROLE)이 있으면 우선, 없으면 웹 쿼리 파라미터, 그것도 없으면 parent.
  const roleDefine = String.fromEnvironment('ROLE');
  final role = roleDefine.isNotEmpty
      ? roleDefine
      : (Uri.base.queryParameters['role'] ?? 'parent');
  final isTeacher = role == 'teacher';
  const initialTab = int.fromEnvironment('TAB');

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

  // 알림 화면을 확인하려면 상태를 골라 넣어야 한다.
  //   --dart-define=NOTIF=onboarding  첫 로그인 전체화면
  //   --dart-define=NOTIF=banner      홈 상단 권유 배너
  //   (기본)                          알림을 받고 있는 평소 상태
  const notif = String.fromEnvironment('NOTIF');
  controller.notificationPrefsLoaded = true;
  controller.notificationPrefs = switch (notif) {
    'onboarding' => const NotificationPrefs(),
    'banner' => NotificationPrefs(
      pushEnabled: false,
      notifOnboardedAt: DateTime.now(),
    ),
    _ => NotificationPrefs(notifOnboardedAt: DateTime.now()),
  };
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
  controller.allAnnouncements = _announcements;
  controller.academicEvents = _academicEvents;
  controller.communityPosts = _communityPosts;

  debugPrint('[demo] runApp');
  runApp(
    MaterialApp(
      title: 'Nest 데모',
      debugShowCheckedModeBanner: false,
      theme: NestTheme.light(),
      // 프로덕션(nest_app.dart)과 동일한 로케일 설정 — 'ko' 날짜 심볼 초기화용.
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // 프로덕션(nest_app.dart)과 같은 갈림길을 태운다. 데모가 HomePage 를 바로
      // 띄우면 알림 온보딩은 영영 확인할 수 없다.
      home: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => controller.needsNotifOnboarding
            ? NotificationOnboardingSheet(
                initial: controller.notificationPrefs,
                onDone: controller.updateNotificationPrefs,
              )
            : HomePage(controller: controller, initialTab: initialTab),
      ),
    ),
  );
}
