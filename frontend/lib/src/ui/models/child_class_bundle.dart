import '../../models/nest_models.dart';

class ChildClassBundle {
  const ChildClassBundle({
    required this.classGroup,
    required this.sessions,
    required this.assignments,
    required this.announcements,
  });

  final ClassGroup classGroup;
  final List<ClassSession> sessions;
  final List<SessionTeacherAssignment> assignments;
  final List<Announcement> announcements;
}
