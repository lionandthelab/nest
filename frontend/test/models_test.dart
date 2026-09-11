import 'package:flutter_test/flutter_test.dart';
import 'package:nest_frontend/src/models/nest_models.dart';

void main() {
  group('model helpers', () {
    test('parseBool supports common string/number values', () {
      expect(parseBool(true), isTrue);
      expect(parseBool('true'), isTrue);
      expect(parseBool('1'), isTrue);
      expect(parseBool(1), isTrue);
      expect(parseBool('false'), isFalse);
      expect(parseBool('0'), isFalse);
      expect(parseBool(0), isFalse);
      expect(parseBool('unknown', fallback: true), isTrue);
    });

    test('HomeschoolInvite.fromMap parses nested homeschool payload', () {
      final invite = HomeschoolInvite.fromMap({
        'id': 'inv-1',
        'homeschool_id': 'school-1',
        'invite_email': 'parent@example.com',
        'role': 'PARENT',
        'status': 'PENDING',
        'invite_token': 'token-1',
        'expires_at': DateTime.now()
            .add(const Duration(days: 2))
            .toUtc()
            .toIso8601String(),
        'created_at': DateTime.now()
            .subtract(const Duration(days: 1))
            .toUtc()
            .toIso8601String(),
        'homeschools': {'id': 'school-1', 'name': 'Warm Nest'},
      });

      expect(invite.id, 'inv-1');
      expect(invite.homeschoolId, 'school-1');
      expect(invite.homeschoolName, 'Warm Nest');
      expect(invite.role, 'PARENT');
      expect(invite.isPending, isTrue);
      expect(invite.canAccept, isTrue);
      expect(invite.isExpired, isFalse);
    });

    test('HomeschoolInvite.canAccept is false when invite is expired', () {
      final invite = HomeschoolInvite.fromMap({
        'id': 'inv-2',
        'homeschool_id': 'school-2',
        'homeschool_name': 'Warm Nest 2',
        'invite_email': 'teacher@example.com',
        'role': 'TEACHER',
        'status': 'PENDING',
        'invite_token': 'token-2',
        'expires_at': DateTime.now()
            .subtract(const Duration(hours: 3))
            .toUtc()
            .toIso8601String(),
      });

      expect(invite.isPending, isTrue);
      expect(invite.isExpired, isTrue);
      expect(invite.canAccept, isFalse);
      expect(invite.homeschoolName, 'Warm Nest 2');
    });

    test('DriveIntegration.fromMap parses status and isConnected', () {
      final integration = DriveIntegration.fromMap({
        'id': 'drive-1',
        'homeschool_id': 'school-1',
        'status': 'CONNECTED',
        'root_folder_id': 'folder-abc',
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      expect(integration.id, 'drive-1');
      expect(integration.homeschoolId, 'school-1');
      expect(integration.status, 'CONNECTED');
      expect(integration.rootFolderId, 'folder-abc');
      expect(integration.isConnected, isTrue);
      expect(integration.googleEmail, isNull);
    });

    test('DriveIntegration.fromMap defaults to disconnected', () {
      final integration = DriveIntegration.fromMap({
        'id': 'drive-2',
        'homeschool_id': 'school-2',
      });

      expect(integration.status, 'DISCONNECTED');
      expect(integration.isConnected, isFalse);
      expect(integration.rootFolderId, isNull);
    });

    test('ChildProfile.fromMap reads nested family fields', () {
      final child = ChildProfile.fromMap({
        'id': 'child-1',
        'family_id': 'fam-1',
        'name': 'Mina',
        'birth_date': '2019-05-12',
        'profile_note': 'likes reading',
        'status': 'ACTIVE',
        'families': {'family_name': 'Kim Family', 'homeschool_id': 'school-1'},
      });

      expect(child.id, 'child-1');
      expect(child.familyId, 'fam-1');
      expect(child.familyName, 'Kim Family');
      expect(child.name, 'Mina');
      expect(child.status, 'ACTIVE');
    });

    test('TeacherProfile.fromMap supports parent-teacher type', () {
      final profile = TeacherProfile.fromMap({
        'id': 'teacher-1',
        'homeschool_id': 'school-1',
        'user_id': 'user-1',
        'display_name': 'Teacher Lee',
        'teacher_type': 'PARENT_TEACHER',
        'specialties': ['math', 'science'],
      });

      expect(profile.id, 'teacher-1');
      expect(profile.isParentTeacher, isTrue);
      expect(profile.specialties, hasLength(2));
      expect(profile.displayName, 'Teacher Lee');
    });

    test('HomeschoolMemberDirectoryEntry.fromMap parses label and roles', () {
      final entry = HomeschoolMemberDirectoryEntry.fromMap({
        'user_id': 'user-2',
        'email': 'teacher@example.com',
        'full_name': 'Teacher Kim',
        'roles': ['TEACHER', 'PARENT'],
      });

      expect(entry.userId, 'user-2');
      expect(entry.email, 'teacher@example.com');
      expect(entry.fullName, 'Teacher Kim');
      expect(entry.roles, containsAll(['TEACHER', 'PARENT']));
      expect(entry.displayLabel, 'Teacher Kim <teacher@example.com>');
    });

    test('HomeschoolDirectoryEntry.fromMap parses search payload fields', () {
      final entry = HomeschoolDirectoryEntry.fromMap({
        'id': 'school-3',
        'name': 'Nest Warm Home',
        'timezone': 'Asia/Seoul',
        'active_member_count': 17,
        'has_pending_request': true,
      });

      expect(entry.id, 'school-3');
      expect(entry.name, 'Nest Warm Home');
      expect(entry.activeMemberCount, 17);
      expect(entry.hasPendingRequest, isTrue);
    });
  });

  group('Term.phaseAt', () {
    Term term({String start = '2026-03-01', String end = '2026-07-31'}) {
      return Term.fromMap({
        'id': 't1',
        'homeschool_id': 's1',
        'name': '2026-1',
        'status': 'ACTIVE',
        'start_date': start,
        'end_date': end,
      });
    }

    test('before start date is upcoming', () {
      expect(term().phaseAt(DateTime(2026, 2, 15)), TermPhase.upcoming);
    });

    test('after end date is past', () {
      expect(term().phaseAt(DateTime(2026, 8, 15)), TermPhase.past);
    });

    test('within the range is current', () {
      expect(term().phaseAt(DateTime(2026, 5, 10)), TermPhase.current);
    });

    test('boundary days (start/end) are inclusive → current', () {
      expect(term().phaseAt(DateTime(2026, 3, 1)), TermPhase.current);
      expect(term().phaseAt(DateTime(2026, 7, 31)), TermPhase.current);
      // 하루 단위 비교이므로 종료일 당일 늦은 시각도 현재로 취급.
      expect(term().phaseAt(DateTime(2026, 7, 31, 23, 59)), TermPhase.current);
    });

    test('null dates fall back to current', () {
      final t = Term.fromMap({
        'id': 't2',
        'homeschool_id': 's1',
        'name': '미정',
        'status': 'DRAFT',
        'start_date': null,
        'end_date': null,
      });
      expect(t.phaseAt(DateTime(2026, 5, 10)), TermPhase.current);
    });

    test('isArchived reflects status', () {
      expect(term().isArchived, isFalse);
      expect(term(start: '2025-01-01', end: '2025-06-30').isArchived, isFalse);
      final archived = Term.fromMap({
        'id': 't3',
        'homeschool_id': 's1',
        'name': '보관',
        'status': 'ARCHIVED',
        'start_date': '2025-01-01',
        'end_date': '2025-06-30',
      });
      expect(archived.isArchived, isTrue);
    });
  });

  group('defaultTermForToday', () {
    Term term(String name, String start, String end) => Term.fromMap({
      'id': name,
      'homeschool_id': 's1',
      'name': name,
      'status': 'DRAFT',
      'start_date': start,
      'end_date': end,
    });

    final spring = term('2026 Spring', '2026-03-03', '2026-06-30');
    final fall = term('2026 가을', '2026-09-01', '2026-11-30');

    test('empty list returns null', () {
      expect(defaultTermForToday(const [], DateTime(2026, 7, 7)), isNull);
    });

    test('picks the current term when today is within a range', () {
      final t = defaultTermForToday([spring, fall], DateTime(2026, 5, 10));
      expect(t?.name, '2026 Spring');
    });

    test('gap between terms picks the most recently started (예승 버그)', () {
      // 오늘이 Spring 종료(06-30)와 가을 시작(09-01) 사이이고 개학까지 56일 남았다
      // → 아직 먼 미래 학기가 아니라 방금 끝난 Spring을 골라야 한다.
      final t = defaultTermForToday([spring, fall], DateTime(2026, 7, 7));
      expect(t?.name, '2026 Spring');
    });

    test(
      'order-independent: fall-first list still picks Spring in the gap',
      () {
        final t = defaultTermForToday([fall, spring], DateTime(2026, 7, 7));
        expect(t?.name, '2026 Spring');
      },
    );

    test('개학이 코앞이면 지난 학기가 아니라 다가오는 학기를 고른다', () {
      // 실제로 겪은 문제: 2026-08-25 에 로그인하면 7월 31일에 끝난 학기가 열렸다.
      // 개학(09-01)까지 7일이면 학교는 이미 새 학기 모드다.
      final t = defaultTermForToday([spring, fall], DateTime(2026, 8, 25));
      expect(t?.name, '2026 가을');
    });

    test('lookahead 경계: 45일 이내는 다가오는 학기, 그보다 멀면 지난 학기', () {
      // 09-01 기준 45일 전 = 07-18 (경계 포함), 46일 전 = 07-17.
      expect(
        defaultTermForToday([spring, fall], DateTime(2026, 7, 18))?.name,
        '2026 가을',
      );
      expect(
        defaultTermForToday([spring, fall], DateTime(2026, 7, 17))?.name,
        '2026 Spring',
      );
    });

    test('실제 JOY 학기 구성으로 2026-08-25 에 2026 가을이 열린다', () {
      // 운영 데이터 그대로. 사용자가 "회차 정보를 어디서 보는지 모르겠다"고 한 날,
      // 앱이 7월 31일에 끝난 학기를 열어 준 것이 원인이었다.
      final joySpring = term('2026 Spring', '2026-03-03', '2026-07-31');
      final joyFall = term('2026 가을', '2026-09-01', '2026-11-30');
      final joyNext = term('2027 가을', '2026-11-26', '2027-06-28');

      final t = defaultTermForToday([
        joyNext,
        joyFall,
        joySpring,
      ], DateTime(2026, 8, 25));
      expect(t?.name, '2026 가을');
    });

    test('기간이 겹치는 현재 학기가 둘이면 먼저 끝나는 쪽을 고른다', () {
      // 다음 학기 시작일을 앞 학기 종료일보다 이르게 만들어 둔 실수(JOY 실제 데이터).
      // 목록 순서에 기대면 아직 반이 없는 미래 학기로 학기 중에 튀어 버린다.
      final nextYear = term('2027 가을', '2026-11-26', '2027-06-28');
      final t = defaultTermForToday([nextYear, fall], DateTime(2026, 11, 27));
      expect(t?.name, '2026 가을');

      final reversed = defaultTermForToday([
        fall,
        nextYear,
      ], DateTime(2026, 11, 27));
      expect(reversed?.name, '2026 가을');
    });

    test('during the fall term picks fall', () {
      final t = defaultTermForToday([spring, fall], DateTime(2026, 10, 1));
      expect(t?.name, '2026 가을');
    });

    test('all future terms picks the earliest upcoming', () {
      final t = defaultTermForToday([fall, spring], DateTime(2026, 1, 1));
      expect(t?.name, '2026 Spring');
    });
  });

  group('resolveTermSelection', () {
    Term term(String name, String start, String end) => Term.fromMap({
      'id': name,
      'homeschool_id': 's1',
      'name': name,
      'status': 'DRAFT',
      'start_date': start,
      'end_date': end,
    });

    final spring = term('spring', '2026-03-03', '2026-06-30');
    final summer = term('summer', '2026-07-01', '2026-08-31');
    final duringSummer = DateTime(2026, 7, 19);

    test('empty terms returns null regardless of selection', () {
      expect(
        resolveTermSelection(
          terms: const [],
          currentSelectionId: 'spring',
          selectionIsExplicit: true,
          now: duringSummer,
        ),
        isNull,
      );
    });

    test('non-explicit selection snaps to the current term (캐시 복원 버그)', () {
      // 기기 캐시에 이전 학기(spring)가 남아 있어도, 이번 세션에서 사용자가
      // 직접 고른 게 아니면 오늘 기준 현재 학기(summer)로 재선택한다.
      expect(
        resolveTermSelection(
          terms: [spring, summer],
          currentSelectionId: 'spring',
          selectionIsExplicit: false,
          now: duringSummer,
        ),
        'summer',
      );
    });

    test('null selection also defaults to the current term', () {
      expect(
        resolveTermSelection(
          terms: [spring, summer],
          currentSelectionId: null,
          selectionIsExplicit: false,
          now: duringSummer,
        ),
        'summer',
      );
    });

    test('explicit valid selection is preserved', () {
      // 사용자가 이번 세션에서 지난 학기를 직접 골랐다면 그대로 둔다.
      expect(
        resolveTermSelection(
          terms: [spring, summer],
          currentSelectionId: 'spring',
          selectionIsExplicit: true,
          now: duringSummer,
        ),
        'spring',
      );
    });

    test('explicit but stale(삭제된 학기) selection falls back to default', () {
      expect(
        resolveTermSelection(
          terms: [spring, summer],
          currentSelectionId: 'deleted-term',
          selectionIsExplicit: true,
          now: duringSummer,
        ),
        'summer',
      );
    });

    test('follows defaultTermForToday in a gap between terms', () {
      // 학기 사이 공백에서는 방금 끝난 학기가 기본값 (defaultTermForToday 규칙).
      final fall = term('fall', '2026-09-10', '2026-11-30');
      expect(
        resolveTermSelection(
          terms: [spring, fall],
          currentSelectionId: 'spring',
          selectionIsExplicit: false,
          now: DateTime(2026, 7, 19),
        ),
        'spring',
      );
    });

    test('explicit flag with null selection still falls back to default', () {
      // deleteTerm이 실제로 만드는 상태: 명시 플래그가 켜진 채 선택이 비워짐.
      // 명시 플래그만으로 null 선택을 고정하지 않고 기본 학기로 내려가야 한다.
      expect(
        resolveTermSelection(
          terms: [spring, summer],
          currentSelectionId: null,
          selectionIsExplicit: true,
          now: duringSummer,
        ),
        'summer',
      );
    });

    test('term boundary days: end date keeps old term, next day snaps', () {
      // 인접 학기 전환 계약: 종료일 당일까지는 그 학기가 '현재'(기간 포함),
      // 다음 학기 시작일 아침에는 새 학기로 스냅된다.
      expect(
        resolveTermSelection(
          terms: [spring, summer],
          currentSelectionId: 'spring',
          selectionIsExplicit: false,
          now: DateTime(2026, 6, 30),
        ),
        'spring',
      );
      expect(
        resolveTermSelection(
          terms: [spring, summer],
          currentSelectionId: 'spring',
          selectionIsExplicit: false,
          now: DateTime(2026, 7, 1),
        ),
        'summer',
      );
    });
  });

  group('ChildProfile 학생 계정 연결', () {
    test('user_id 가 있으면 hasAccount 가 true', () {
      final child = ChildProfile.fromMap({
        'id': 'child-1',
        'family_id': 'fam-1',
        'name': '민서',
        'birth_date': '2014-03-02',
        'profile_note': '',
        'status': 'ACTIVE',
        'created_at': '2026-03-01T00:00:00+00:00',
        'user_id': '11111111-2222-3333-4444-555555555555',
        'families': {'family_name': '김 가정'},
      });

      expect(child.userId, '11111111-2222-3333-4444-555555555555');
      expect(child.hasAccount, isTrue);
    });

    test('user_id 가 null 이거나 키가 없으면 hasAccount 가 false', () {
      final explicitNull = ChildProfile.fromMap({
        'id': 'child-2',
        'family_id': 'fam-1',
        'name': '하준',
        'birth_date': '2016-08-11',
        'status': 'ACTIVE',
        'user_id': null,
        'families': {'family_name': '김 가정'},
      });
      final missingKey = ChildProfile.fromMap({
        'id': 'child-3',
        'family_id': 'fam-1',
        'name': '서윤',
        'birth_date': '2018-01-20',
        'families': {'family_name': '이 가정'},
      });

      expect(explicitNull.userId, isNull);
      expect(explicitNull.hasAccount, isFalse);
      expect(missingKey.userId, isNull);
      expect(missingKey.hasAccount, isFalse);
    });

    test('toMap 왕복이 user_id 와 중첩 families 를 모두 보존한다', () {
      final child = ChildProfile.fromMap({
        'id': 'child-4',
        'family_id': 'fam-2',
        'name': '지호',
        'birth_date': '2015-06-30',
        'profile_note': '견과류 알레르기',
        'status': 'ACTIVE',
        'user_id': 'user-9',
        'families': {'family_name': '박 가정'},
      });

      final roundTripped = ChildProfile.fromMap(child.toMap());

      expect(roundTripped.userId, 'user-9');
      expect(roundTripped.hasAccount, isTrue);
      expect(roundTripped.familyName, '박 가정');
      expect(roundTripped.profileNote, '견과류 알레르기');
    });
  });

  group('ClassSessionChange', () {
    Map<String, dynamic> row({
      String changeType = 'CANCELED',
      String from = '2026-09-03',
      String? to = '2026-09-03',
    }) {
      return {
        'id': 'chg-1',
        'class_session_id': 'sess-1',
        'change_type': changeType,
        'effective_from': from,
        'effective_to': to,
        'new_time_slot_id': null,
        'new_location': '',
        'substitute_teacher_id': null,
        'reason': '교사 출장',
        'created_by_user_id': 'user-1',
        'notified_at': null,
        'created_at': '2026-08-30T01:00:00+00:00',
      };
    }

    test('fromMap 이 PostgREST snake_case 행을 파싱한다', () {
      final change = ClassSessionChange.fromMap({
        ...row(changeType: 'ROOM_MOVED', from: '2026-09-07', to: null),
        'new_location': '2층 미술실',
        'substitute_teacher_id': 'teacher-2',
        'new_time_slot_id': 'slot-3',
      });

      expect(change.id, 'chg-1');
      expect(change.classSessionId, 'sess-1');
      expect(change.changeType, 'ROOM_MOVED');
      expect(change.effectiveFrom, DateTime(2026, 9, 7));
      expect(change.effectiveTo, isNull);
      expect(change.newLocation, '2층 미술실');
      expect(change.newTimeSlotId, 'slot-3');
      expect(change.substituteTeacherId, 'teacher-2');
      expect(change.reason, '교사 출장');
      expect(change.isRestOfTerm, isTrue);
      expect(change.isNotified, isFalse);
    });

    test('notified_at 이 있으면 isNotified 가 true', () {
      final change = ClassSessionChange.fromMap({
        ...row(),
        'notified_at': '2026-09-01T05:00:00+00:00',
      });
      expect(change.isNotified, isTrue);
    });

    test('changeTypeLabel 이 한국어 라벨을 준다', () {
      String label(String type) =>
          ClassSessionChange.fromMap(row(changeType: type)).changeTypeLabel;

      expect(label('CANCELED'), '휴강');
      expect(label('TIME_MOVED'), '시간 변경');
      expect(label('ROOM_MOVED'), '장소 변경');
      expect(label('TEACHER_SUBSTITUTE'), '보강 교사');
      expect(label('NOTE'), '안내');
    });

    test('appliesOn: "이번 주만"(from == to) 은 그 하루만 적용', () {
      final change = ClassSessionChange.fromMap(row());

      expect(change.appliesOn(DateTime(2026, 9, 2)), isFalse);
      expect(change.appliesOn(DateTime(2026, 9, 3)), isTrue);
      expect(change.appliesOn(DateTime(2026, 9, 4)), isFalse);
    });

    test('appliesOn: 구간 경계(시작일·종료일)는 포함', () {
      final change = ClassSessionChange.fromMap(
        row(from: '2026-09-03', to: '2026-09-24'),
      );

      expect(change.appliesOn(DateTime(2026, 9, 2)), isFalse);
      expect(change.appliesOn(DateTime(2026, 9, 3)), isTrue);
      expect(change.appliesOn(DateTime(2026, 9, 10)), isTrue);
      expect(change.appliesOn(DateTime(2026, 9, 24)), isTrue);
      expect(change.appliesOn(DateTime(2026, 9, 25)), isFalse);
    });

    test('appliesOn: effective_to 가 null 이면 이후 전부 적용', () {
      final change = ClassSessionChange.fromMap(
        row(from: '2026-09-03', to: null),
      );

      expect(change.appliesOn(DateTime(2026, 9, 2)), isFalse);
      expect(change.appliesOn(DateTime(2026, 9, 3)), isTrue);
      expect(change.appliesOn(DateTime(2027, 1, 1)), isTrue);
    });

    test('appliesOn: 시분초는 무시하고 날짜만 비교', () {
      final change = ClassSessionChange.fromMap(row());

      expect(change.appliesOn(DateTime(2026, 9, 3, 23, 59, 59)), isTrue);
      expect(change.appliesOn(DateTime(2026, 9, 2, 23, 59, 59)), isFalse);
    });
  });

  group('CourseLesson', () {
    Map<String, dynamic> row({
      String date = '2026-09-15',
      String title = '창세기 36장',
      String subtitle = '에서의 자손',
      String presenter = '리아',
      String content = '',
      bool confirmed = true,
    }) {
      return {
        'id': 'lesson-1',
        'course_id': 'course-1',
        'lesson_date': date,
        'title': title,
        'subtitle': subtitle,
        'presenter': presenter,
        'content': content,
        'is_confirmed': confirmed,
        'created_by_user_id': 'user-1',
        'created_at': '2026-08-24T01:00:00+00:00',
        'updated_at': '2026-08-24T01:00:00+00:00',
      };
    }

    test('fromMap 이 PostgREST snake_case 행을 파싱한다', () {
      final lesson = CourseLesson.fromMap(row(content: '성경 지참, 노트 준비'));

      expect(lesson.id, 'lesson-1');
      expect(lesson.courseId, 'course-1');
      expect(lesson.lessonDate, DateTime(2026, 9, 15));
      expect(lesson.title, '창세기 36장');
      expect(lesson.subtitle, '에서의 자손');
      expect(lesson.presenter, '리아');
      expect(lesson.content, '성경 지참, 노트 준비');
      expect(lesson.isConfirmed, isTrue);
    });

    test('lesson_date 는 시분초 없는 날짜로 파싱된다', () {
      final lesson = CourseLesson.fromMap(row(date: '2026-12-15'));

      expect(lesson.lessonDate.hour, 0);
      expect(lesson.lessonDate.minute, 0);
      expect(lesson.lessonDate, DateTime(2026, 12, 15));
    });

    test('headline 이 제목과 부제를 합친다', () {
      expect(CourseLesson.fromMap(row()).headline, '창세기 36장 · 에서의 자손');
      expect(CourseLesson.fromMap(row(subtitle: '')).headline, '창세기 36장');
      expect(CourseLesson.fromMap(row(title: '', subtitle: '')).headline, '');
    });

    test('isBlank: 제목·부제·담당·내용이 모두 비면 true', () {
      final blank = CourseLesson.fromMap(
        row(title: '', subtitle: '', presenter: '', content: ''),
      );
      expect(blank.isBlank, isTrue);

      final filled = CourseLesson.fromMap(
        row(title: '', subtitle: '', presenter: '오미령', content: ''),
      );
      expect(filled.isBlank, isFalse);
    });

    test('isOn: 시분초는 무시하고 날짜만 비교', () {
      final lesson = CourseLesson.fromMap(row(date: '2026-09-15'));

      expect(lesson.isOn(DateTime(2026, 9, 15, 23, 59, 59)), isTrue);
      expect(lesson.isOn(DateTime(2026, 9, 14, 23, 59, 59)), isFalse);
      expect(lesson.isOn(DateTime(2026, 9, 16)), isFalse);
    });

    test('toMap 이 date 컬럼을 YYYY-MM-DD 로 직렬화한다', () {
      final lesson = CourseLesson.fromMap(row(date: '2026-10-06'));
      final map = lesson.toMap();

      expect(map['lesson_date'], '2026-10-06');
      expect(map['course_id'], 'course-1');
      expect(map['is_confirmed'], isTrue);

      final roundTripped = CourseLesson.fromMap(map);
      expect(roundTripped.lessonDate, DateTime(2026, 10, 6));
      expect(roundTripped.headline, '창세기 36장 · 에서의 자손');
    });
  });

  group('AbsenceReport', () {
    Map<String, dynamic> row({String status = 'SUBMITTED'}) {
      return {
        'id': 'abs-1',
        'class_session_id': 'sess-1',
        'child_id': 'child-1',
        'occurrence_date': '2026-09-10',
        'reason': '병원 진료',
        'reported_by_user_id': 'user-7',
        'status': status,
        'acknowledged_by_user_id': null,
        'acknowledged_at': null,
        'notified_at': null,
        'created_at': '2026-09-08T02:30:00+00:00',
      };
    }

    test('fromMap 이 PostgREST snake_case 행을 파싱한다', () {
      final report = AbsenceReport.fromMap(row());

      expect(report.id, 'abs-1');
      expect(report.classSessionId, 'sess-1');
      expect(report.childId, 'child-1');
      expect(report.occurrenceDate, DateTime(2026, 9, 10));
      expect(report.reason, '병원 진료');
      expect(report.reportedByUserId, 'user-7');
      expect(report.acknowledgedByUserId, isNull);
      expect(report.acknowledgedAt, isNull);
      expect(report.isNotified, isFalse);
      expect(report.createdAt, isNotNull);
    });

    test('status 플래그와 statusLabel', () {
      final submitted = AbsenceReport.fromMap(row());
      expect(submitted.isSubmitted, isTrue);
      expect(submitted.isAcknowledged, isFalse);
      expect(submitted.isCanceled, isFalse);
      expect(submitted.statusLabel, '신고됨');

      final acknowledged = AbsenceReport.fromMap({
        ...row(status: 'ACKNOWLEDGED'),
        'acknowledged_by_user_id': 'teacher-user-1',
        'acknowledged_at': '2026-09-09T00:10:00+00:00',
        'notified_at': '2026-09-08T02:31:00+00:00',
      });
      expect(acknowledged.isAcknowledged, isTrue);
      expect(acknowledged.isSubmitted, isFalse);
      expect(acknowledged.statusLabel, '확인됨');
      expect(acknowledged.acknowledgedByUserId, 'teacher-user-1');
      expect(acknowledged.acknowledgedAt, isNotNull);
      expect(acknowledged.isNotified, isTrue);

      final canceled = AbsenceReport.fromMap(row(status: 'CANCELED'));
      expect(canceled.isCanceled, isTrue);
      expect(canceled.statusLabel, '취소됨');
    });

    test('status 기본값은 SUBMITTED', () {
      final report = AbsenceReport.fromMap({
        'id': 'abs-2',
        'class_session_id': 'sess-2',
        'child_id': 'child-2',
        'occurrence_date': '2026-09-11',
        'reported_by_user_id': 'user-8',
      });

      expect(report.status, 'SUBMITTED');
      expect(report.statusLabel, '신고됨');
      expect(report.reason, '');
    });
  });

  group('compareTermsByStartDate', () {
    Term term(String name, String? start) => Term.fromMap({
      'id': name,
      'homeschool_id': 's1',
      'name': name,
      'status': 'DRAFT',
      'start_date': start,
      'end_date': null,
    });

    test('orders by start date ascending', () {
      final sorted = [term('b', '2026-09-01'), term('a', '2026-03-02')]
        ..sort(compareTermsByStartDate);
      expect(sorted.map((t) => t.name).toList(), ['a', 'b']);
    });

    test('terms without start date come first', () {
      final sorted = [term('dated', '2026-03-02'), term('undated', null)]
        ..sort(compareTermsByStartDate);
      expect(sorted.first.name, 'undated');
    });

    test('two undated terms compare equal', () {
      expect(compareTermsByStartDate(term('x', null), term('y', null)), 0);
    });
  });

  group('NotificationPrefs / inbox', () {
    test('NotificationPrefs.fromMap uses true defaults', () {
      final prefs = NotificationPrefs.fromMap({});
      expect(prefs.pushEnabled, isTrue);
      expect(prefs.morningDigestEnabled, isTrue);
      expect(prefs.classReminderEnabled, isTrue);
    });

    test('NotificationInboxItem.deepLinkTab falls back by event', () {
      final reminder = NotificationInboxItem.fromMap({
        'id': 'n-1',
        'event_type': 'CLASS_REMINDER',
        'title': '수학 30분 전',
        'body': '2반',
        'created_at': '2026-09-08T00:00:00Z',
      });
      expect(reminder.deepLinkTab, '시간표');
      expect(reminder.title, '수학 30분 전');
    });

    test('AcademicEvent.fromMap reads kind, times, and coversDate', () {
      final event = AcademicEvent.fromMap({
        'id': 'ae-1',
        'homeschool_id': 'hs-1',
        'term_id': 't-1',
        'title': '현장학습',
        'description': '운동화',
        'event_date': '2026-09-15',
        'end_date': '2026-09-16',
        'kind': 'FIELD_TRIP',
        'start_time': '10:00:00',
        'end_time': '15:00:00',
        'publish_announcement': true,
        'show_on_timetable': true,
      });
      expect(event.kind, 'FIELD_TRIP');
      expect(event.isAllDay, isFalse);
      expect(event.coversDate(DateTime(2026, 9, 15)), isTrue);
      expect(event.coversDate(DateTime(2026, 9, 17)), isFalse);
    });

    test('PersonalEvent.fromMap and overlap helpers', () {
      final event = PersonalEvent.fromMap({
        'id': 'pe-1',
        'homeschool_id': 'hs-1',
        'owner_user_id': 'u-1',
        'child_id': 'c-1',
        'title': '피아노',
        'notes': '',
        'starts_at': '2026-09-14T09:10:00+09:00',
        'ends_at': '2026-09-14T10:00:00+09:00',
        'conflict_policy': 'PRIORITIZE_PERSONAL',
        'source': 'NEST',
      });
      expect(event.prioritizesPersonal, isTrue);
      expect(event.coversDate(DateTime(2026, 9, 14)), isTrue);
      expect(event.toMap()['child_id'], 'c-1');
    });

    test('TermSchedulePack.fromMap parses sessions and assignments', () {
      final pack = TermSchedulePack.fromMap({
        'sessions': [
          {
            'id': 's-1',
            'class_group_id': 'g-1',
            'course_id': 'c-1',
            'time_slot_id': 't-1',
            'title': '국어',
            'source_type': 'MANUAL',
            'status': 'PLANNED',
            'location': '거실',
          },
        ],
        'assignments': [
          {
            'id': 'a-1',
            'class_session_id': 's-1',
            'teacher_profile_id': 'tp-1',
            'assignment_role': 'MAIN',
          },
        ],
      });
      expect(pack.sessions, hasLength(1));
      expect(pack.sessions.first.location, '거실');
      expect(pack.assignments.single.isMain, isTrue);
    });

    test('TermSchedulePack.fromMap handles empty payloads', () {
      final pack = TermSchedulePack.fromMap({});
      expect(pack.sessions, isEmpty);
      expect(pack.assignments, isEmpty);
    });
  });
}
