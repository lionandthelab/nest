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
      // 오늘이 Spring 종료(06-30)와 가을 시작(09-01) 사이 → 빈 미래 학기가 아니라
      // 방금 끝난 Spring을 골라야 한다.
      final t = defaultTermForToday([spring, fall], DateTime(2026, 7, 7));
      expect(t?.name, '2026 Spring');
    });

    test('order-independent: fall-first list still picks Spring in the gap', () {
      final t = defaultTermForToday([fall, spring], DateTime(2026, 7, 7));
      expect(t?.name, '2026 Spring');
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
      final sorted = [
        term('dated', '2026-03-02'),
        term('undated', null),
      ]..sort(compareTermsByStartDate);
      expect(sorted.first.name, 'undated');
    });

    test('two undated terms compare equal', () {
      expect(compareTermsByStartDate(term('x', null), term('y', null)), 0);
    });
  });
}
