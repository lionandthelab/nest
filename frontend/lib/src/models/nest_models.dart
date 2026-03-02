import 'dart:typed_data';

DateTime? parseDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

class Homeschool {
  const Homeschool({
    required this.id,
    required this.name,
    required this.timezone,
  });

  final String id;
  final String name;
  final String timezone;

  factory Homeschool.fromMap(Map<String, dynamic> map) {
    return Homeschool(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'Unnamed Homeschool',
      timezone: (map['timezone'] as String?) ?? 'Asia/Seoul',
    );
  }
}

class Membership {
  const Membership({
    required this.homeschoolId,
    required this.role,
    required this.status,
    required this.homeschool,
  });

  final String homeschoolId;
  final String role;
  final String status;
  final Homeschool homeschool;

  factory Membership.fromMap(Map<String, dynamic> map) {
    final nested = map['homeschools'];
    final homeschoolMap = nested is Map<String, dynamic>
        ? nested
        : <String, dynamic>{};

    final fallbackId =
        (map['homeschool_id'] as String?) ??
        (homeschoolMap['id'] as String?) ??
        '';

    return Membership(
      homeschoolId: fallbackId,
      role: (map['role'] as String?) ?? 'PARENT',
      status: (map['status'] as String?) ?? 'ACTIVE',
      homeschool: Homeschool.fromMap({
        'id': fallbackId,
        'name': homeschoolMap['name'],
        'timezone': homeschoolMap['timezone'],
      }),
    );
  }
}

class Term {
  const Term({
    required this.id,
    required this.homeschoolId,
    required this.name,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  final String id;
  final String homeschoolId;
  final String name;
  final String status;
  final DateTime? startDate;
  final DateTime? endDate;

  factory Term.fromMap(Map<String, dynamic> map) {
    return Term(
      id: map['id'] as String,
      homeschoolId: (map['homeschool_id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Unnamed Term',
      status: (map['status'] as String?) ?? 'DRAFT',
      startDate: parseDateTime(map['start_date']),
      endDate: parseDateTime(map['end_date']),
    );
  }
}

class ClassGroup {
  const ClassGroup({
    required this.id,
    required this.termId,
    required this.name,
    required this.capacity,
  });

  final String id;
  final String termId;
  final String name;
  final int capacity;

  factory ClassGroup.fromMap(Map<String, dynamic> map) {
    return ClassGroup(
      id: map['id'] as String,
      termId: (map['term_id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Unnamed Class',
      capacity: (map['capacity'] as int?) ?? 12,
    );
  }
}

class Course {
  const Course({
    required this.id,
    required this.homeschoolId,
    required this.name,
    required this.defaultDurationMin,
  });

  final String id;
  final String homeschoolId;
  final String name;
  final int defaultDurationMin;

  factory Course.fromMap(Map<String, dynamic> map) {
    return Course(
      id: map['id'] as String,
      homeschoolId: (map['homeschool_id'] as String?) ?? '',
      name: (map['name'] as String?) ?? 'Unnamed Course',
      defaultDurationMin: (map['default_duration_min'] as int?) ?? 50,
    );
  }
}

class TimeSlot {
  const TimeSlot({
    required this.id,
    required this.termId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
  });

  final String id;
  final String termId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;

  factory TimeSlot.fromMap(Map<String, dynamic> map) {
    return TimeSlot(
      id: map['id'] as String,
      termId: (map['term_id'] as String?) ?? '',
      dayOfWeek: (map['day_of_week'] as int?) ?? 0,
      startTime: (map['start_time'] as String?) ?? '00:00:00',
      endTime: (map['end_time'] as String?) ?? '00:00:00',
    );
  }
}

class ClassSession {
  const ClassSession({
    required this.id,
    required this.classGroupId,
    required this.courseId,
    required this.timeSlotId,
    required this.title,
    required this.sourceType,
    required this.status,
  });

  final String id;
  final String classGroupId;
  final String courseId;
  final String timeSlotId;
  final String title;
  final String sourceType;
  final String status;

  factory ClassSession.fromMap(Map<String, dynamic> map) {
    return ClassSession(
      id: map['id'] as String,
      classGroupId: (map['class_group_id'] as String?) ?? '',
      courseId: (map['course_id'] as String?) ?? '',
      timeSlotId: (map['time_slot_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      sourceType: (map['source_type'] as String?) ?? 'MANUAL',
      status: (map['status'] as String?) ?? 'PLANNED',
    );
  }
}

class Proposal {
  const Proposal({
    required this.id,
    required this.termId,
    required this.prompt,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String termId;
  final String prompt;
  final String status;
  final DateTime? createdAt;

  factory Proposal.fromMap(Map<String, dynamic> map) {
    return Proposal(
      id: map['id'] as String,
      termId: (map['term_id'] as String?) ?? '',
      prompt: (map['prompt'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'GENERATED',
      createdAt: parseDateTime(map['created_at']),
    );
  }
}

class ProposalSession {
  const ProposalSession({
    required this.id,
    required this.proposalId,
    required this.classGroupId,
    required this.courseId,
    required this.timeSlotId,
  });

  final String id;
  final String proposalId;
  final String classGroupId;
  final String courseId;
  final String timeSlotId;

  factory ProposalSession.fromMap(Map<String, dynamic> map) {
    return ProposalSession(
      id: map['id'] as String,
      proposalId: (map['proposal_id'] as String?) ?? '',
      classGroupId: (map['class_group_id'] as String?) ?? '',
      courseId: (map['course_id'] as String?) ?? '',
      timeSlotId: (map['time_slot_id'] as String?) ?? '',
    );
  }
}

class DriveIntegration {
  const DriveIntegration({
    required this.id,
    required this.status,
    required this.rootFolderId,
    required this.folderPolicy,
    required this.connectedAt,
    required this.googleAccessToken,
    required this.googleRefreshToken,
    required this.googleTokenExpiresAt,
  });

  final String id;
  final String status;
  final String? rootFolderId;
  final String? folderPolicy;
  final DateTime? connectedAt;
  final String? googleAccessToken;
  final String? googleRefreshToken;
  final DateTime? googleTokenExpiresAt;

  bool get hasAccessToken => (googleAccessToken ?? '').isNotEmpty;
  bool get hasRefreshToken => (googleRefreshToken ?? '').isNotEmpty;

  factory DriveIntegration.fromMap(Map<String, dynamic> map) {
    return DriveIntegration(
      id: (map['id'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'DISCONNECTED',
      rootFolderId: map['root_folder_id'] as String?,
      folderPolicy: map['folder_policy'] as String?,
      connectedAt: parseDateTime(map['connected_at']),
      googleAccessToken: map['google_access_token'] as String?,
      googleRefreshToken: map['google_refresh_token'] as String?,
      googleTokenExpiresAt: parseDateTime(map['google_token_expires_at']),
    );
  }
}

class GalleryItem {
  const GalleryItem({
    required this.id,
    required this.title,
    required this.description,
    required this.mediaType,
    required this.driveWebViewLink,
    required this.classGroupId,
    required this.capturedAt,
  });

  final String id;
  final String title;
  final String description;
  final String mediaType;
  final String? driveWebViewLink;
  final String? classGroupId;
  final DateTime? capturedAt;

  bool get isVideo => mediaType == 'VIDEO';

  factory GalleryItem.fromMap(Map<String, dynamic> map) {
    return GalleryItem(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      mediaType: (map['media_type'] as String?) ?? 'PHOTO',
      driveWebViewLink: map['drive_web_view_link'] as String?,
      classGroupId: map['class_group_id'] as String?,
      capturedAt: parseDateTime(map['captured_at']),
    );
  }
}

class PendingMediaFile {
  const PendingMediaFile({
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  final String name;
  final String mimeType;
  final Uint8List bytes;

  int get sizeBytes => bytes.length;
  bool get isVideo => mimeType.startsWith('video/');
}

class GeneratedSessionDraft {
  const GeneratedSessionDraft({
    required this.classGroupId,
    required this.courseId,
    required this.timeSlotId,
    required this.teacherMainId,
    required this.teacherAssistantIds,
    required this.hardConflicts,
    required this.softWarnings,
  });

  final String classGroupId;
  final String courseId;
  final String timeSlotId;
  final String? teacherMainId;
  final List<dynamic> teacherAssistantIds;
  final List<dynamic> hardConflicts;
  final List<dynamic> softWarnings;

  Map<String, dynamic> toProposalRow(String proposalId) {
    return {
      'proposal_id': proposalId,
      'class_group_id': classGroupId,
      'course_id': courseId,
      'time_slot_id': timeSlotId,
      'teacher_main_id': teacherMainId,
      'teacher_assistant_ids_json': teacherAssistantIds,
      'hard_conflicts_json': hardConflicts,
      'soft_warnings_json': softWarnings,
    };
  }
}

class GeneratedProposalDraft {
  const GeneratedProposalDraft({
    required this.source,
    required this.sessions,
    required this.hardConflicts,
    required this.softWarnings,
  });

  final String source;
  final List<GeneratedSessionDraft> sessions;
  final List<dynamic> hardConflicts;
  final List<dynamic> softWarnings;
}

enum DragPayloadType { course, session }

class DragPayload {
  const DragPayload({required this.type, required this.id});

  final DragPayloadType type;
  final String id;
}
