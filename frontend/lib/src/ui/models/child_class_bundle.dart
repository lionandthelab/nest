import '../../models/nest_models.dart';

class ChildClassBundle {
  const ChildClassBundle({
    required this.classGroup,
    required this.sessions,
    required this.assignments,
    required this.announcements,
    this.changes = const [],
    this.absences = const [],
  });

  final ClassGroup classGroup;
  final List<ClassSession> sessions;
  final List<SessionTeacherAssignment> assignments;
  final List<Announcement> announcements;

  /// 이 반 수업들에 걸린 변경 공지. 기본값 const [] 이라 아직 변경 공지를
  /// 로드하지 않는 호출부도 그대로 동작한다.
  final List<ClassSessionChange> changes;

  /// 이 반 수업들에 대한 결석 신고(보이는 범위는 RLS 가 정한다).
  final List<AbsenceReport> absences;

  /// 특정 수업에 걸린 변경 공지만 추린다.
  List<ClassSessionChange> changesForSession(String sessionId) {
    return changes
        .where((change) => change.classSessionId == sessionId)
        .toList(growable: false);
  }

  /// (수업, 날짜)에 해당하는 살아 있는 결석 신고를 찾는다.
  /// 철회(CANCELED)된 신고는 없는 것으로 취급한다 — DB 의 부분 unique 인덱스
  /// (`status <> 'CANCELED'`)와 같은 기준이라 최대 1건만 매칭된다.
  AbsenceReport? absenceFor({
    required String sessionId,
    required DateTime date,
  }) {
    final day = DateTime(date.year, date.month, date.day);
    for (final report in absences) {
      if (report.classSessionId != sessionId || report.isCanceled) {
        continue;
      }
      final occurrence = report.occurrenceDate;
      final occurrenceDay = DateTime(
        occurrence.year,
        occurrence.month,
        occurrence.day,
      );
      if (occurrenceDay == day) {
        return report;
      }
    }
    return null;
  }
}
