import 'dart:typed_data';

DateTime? parseDateTime(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}

bool parseBool(dynamic value, {bool fallback = false}) {
  if (value is bool) {
    return value;
  }
  if (value is num) {
    return value != 0;
  }
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == 't' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'f' || normalized == '0') {
      return false;
    }
  }
  return fallback;
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'timezone': timezone,
  };
}

class Membership {
  const Membership({
    required this.userId,
    required this.homeschoolId,
    required this.role,
    required this.status,
    required this.homeschool,
  });

  final String userId;
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
      userId: (map['user_id'] as String?) ?? '',
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

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'homeschool_id': homeschoolId,
    'role': role,
    'status': status,
    'homeschools': homeschool.toMap(),
  };
}

class HomeschoolMemberDirectoryEntry {
  const HomeschoolMemberDirectoryEntry({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.roles,
  });

  final String userId;
  final String email;
  final String fullName;
  final List<String> roles;

  String get displayLabel {
    final trimmedName = fullName.trim();
    if (trimmedName.isNotEmpty && email.trim().isNotEmpty) {
      return '$trimmedName <$email>';
    }
    if (trimmedName.isNotEmpty) {
      return trimmedName;
    }
    if (email.trim().isNotEmpty) {
      return email;
    }
    return userId;
  }

  factory HomeschoolMemberDirectoryEntry.fromMap(Map<String, dynamic> map) {
    return HomeschoolMemberDirectoryEntry(
      userId: (map['user_id'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      fullName: (map['full_name'] as String?) ?? '',
      roles:
          (map['roles'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'email': email,
    'full_name': fullName,
    'roles': roles,
  };
}

class HomeschoolInvite {
  const HomeschoolInvite({
    required this.id,
    required this.homeschoolId,
    required this.homeschoolName,
    required this.inviteEmail,
    required this.role,
    required this.status,
    required this.inviteToken,
    required this.expiresAt,
    required this.createdAt,
  });

  final String id;
  final String homeschoolId;
  final String homeschoolName;
  final String inviteEmail;
  final String role;
  final String status;
  final String inviteToken;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  bool get isPending => status == 'PENDING';
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get canAccept => isPending && !isExpired && inviteToken.isNotEmpty;

  factory HomeschoolInvite.fromMap(Map<String, dynamic> map) {
    final nested = map['homeschools'];
    final homeschoolMap = nested is Map<String, dynamic>
        ? nested
        : <String, dynamic>{};

    final fallbackId =
        (map['homeschool_id'] as String?) ??
        (homeschoolMap['id'] as String?) ??
        '';

    return HomeschoolInvite(
      id: (map['id'] as String?) ?? '',
      homeschoolId: fallbackId,
      homeschoolName:
          (homeschoolMap['name'] as String?) ??
          (map['homeschool_name'] as String?) ??
          'Unknown Homeschool',
      inviteEmail: (map['invite_email'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'PARENT',
      status: (map['status'] as String?) ?? 'PENDING',
      inviteToken: (map['invite_token'] as String?) ?? '',
      expiresAt: parseDateTime(map['expires_at']),
      createdAt: parseDateTime(map['created_at']),
    );
  }
}

class Family {
  const Family({
    required this.id,
    required this.homeschoolId,
    required this.familyName,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String homeschoolId;
  final String familyName;
  final String note;
  final DateTime? createdAt;

  factory Family.fromMap(Map<String, dynamic> map) {
    return Family(
      id: (map['id'] as String?) ?? '',
      homeschoolId: (map['homeschool_id'] as String?) ?? '',
      familyName: (map['family_name'] as String?) ?? 'Unnamed Family',
      note: (map['note'] as String?) ?? '',
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'homeschool_id': homeschoolId,
    'family_name': familyName,
    'note': note,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}

class ChildProfile {
  const ChildProfile({
    required this.id,
    required this.familyId,
    required this.familyName,
    required this.name,
    required this.birthDate,
    required this.profileNote,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String familyId;
  final String familyName;
  final String name;
  final DateTime? birthDate;
  final String profileNote;
  final String status;
  final DateTime? createdAt;

  factory ChildProfile.fromMap(Map<String, dynamic> map) {
    final nested = map['families'];
    final familyMap = nested is Map<String, dynamic>
        ? nested
        : <String, dynamic>{};

    return ChildProfile(
      id: (map['id'] as String?) ?? '',
      familyId: (map['family_id'] as String?) ?? '',
      familyName: (familyMap['family_name'] as String?) ?? 'Unknown Family',
      name: (map['name'] as String?) ?? 'Unnamed Child',
      birthDate: parseDateTime(map['birth_date']),
      profileNote: (map['profile_note'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'ACTIVE',
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'family_id': familyId,
    'families': {'family_name': familyName},
    'name': name,
    'birth_date': birthDate?.toUtc().toIso8601String(),
    'profile_note': profileNote,
    'status': status,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}

class ClassEnrollment {
  const ClassEnrollment({
    required this.id,
    required this.classGroupId,
    required this.childId,
    required this.createdAt,
  });

  final String id;
  final String classGroupId;
  final String childId;
  final DateTime? createdAt;

  factory ClassEnrollment.fromMap(Map<String, dynamic> map) {
    return ClassEnrollment(
      id: (map['id'] as String?) ?? '',
      classGroupId: (map['class_group_id'] as String?) ?? '',
      childId: (map['child_id'] as String?) ?? '',
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'class_group_id': classGroupId,
    'child_id': childId,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}

class TeacherProfile {
  const TeacherProfile({
    required this.id,
    required this.homeschoolId,
    required this.userId,
    required this.displayName,
    required this.teacherType,
    required this.specialties,
    required this.bio,
    required this.createdAt,
  });

  final String id;
  final String homeschoolId;
  final String? userId;
  final String displayName;
  final String teacherType;
  final List<String> specialties;
  final String bio;
  final DateTime? createdAt;

  bool get isParentTeacher => teacherType == 'PARENT_TEACHER';

  factory TeacherProfile.fromMap(Map<String, dynamic> map) {
    return TeacherProfile(
      id: (map['id'] as String?) ?? '',
      homeschoolId: (map['homeschool_id'] as String?) ?? '',
      userId: map['user_id'] as String?,
      displayName: (map['display_name'] as String?) ?? 'Teacher',
      teacherType: (map['teacher_type'] as String?) ?? 'GUEST_TEACHER',
      specialties:
          (map['specialties'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const [],
      bio: (map['bio'] as String?) ?? '',
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'homeschool_id': homeschoolId,
    'user_id': userId,
    'display_name': displayName,
    'teacher_type': teacherType,
    'specialties': specialties,
    'bio': bio,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}

class MemberUnavailabilityBlock {
  const MemberUnavailabilityBlock({
    required this.id,
    required this.homeschoolId,
    required this.ownerKind,
    required this.ownerId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String homeschoolId;
  final String ownerKind; // TEACHER_PROFILE | MEMBER_USER
  final String ownerId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final String note;
  final DateTime? createdAt;

  bool get isTeacherOwner => ownerKind == 'TEACHER_PROFILE';
  bool get isMemberOwner => ownerKind == 'MEMBER_USER';

  factory MemberUnavailabilityBlock.fromMap(Map<String, dynamic> map) {
    return MemberUnavailabilityBlock(
      id: (map['id'] as String?) ?? '',
      homeschoolId: (map['homeschool_id'] as String?) ?? '',
      ownerKind: (map['owner_kind'] as String?) ?? 'MEMBER_USER',
      ownerId: (map['owner_id'] as String?) ?? '',
      dayOfWeek: (map['day_of_week'] as int?) ?? 0,
      startTime: (map['start_time'] as String?) ?? '00:00:00',
      endTime: (map['end_time'] as String?) ?? '00:00:00',
      note: (map['note'] as String?) ?? '',
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'homeschool_id': homeschoolId,
    'owner_kind': ownerKind,
    'owner_id': ownerId,
    'day_of_week': dayOfWeek,
    'start_time': startTime,
    'end_time': endTime,
    'note': note,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}

class SessionTeacherAssignment {
  const SessionTeacherAssignment({
    required this.id,
    required this.classSessionId,
    required this.teacherProfileId,
    required this.assignmentRole,
  });

  final String id;
  final String classSessionId;
  final String teacherProfileId;
  final String assignmentRole;

  bool get isMain => assignmentRole == 'MAIN';

  factory SessionTeacherAssignment.fromMap(Map<String, dynamic> map) {
    return SessionTeacherAssignment(
      id: (map['id'] as String?) ?? '',
      classSessionId: (map['class_session_id'] as String?) ?? '',
      teacherProfileId: (map['teacher_profile_id'] as String?) ?? '',
      assignmentRole: (map['assignment_role'] as String?) ?? 'ASSISTANT',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'class_session_id': classSessionId,
    'teacher_profile_id': teacherProfileId,
    'assignment_role': assignmentRole,
  };
}

class TeachingPlan {
  const TeachingPlan({
    required this.id,
    required this.classSessionId,
    required this.teacherProfileId,
    required this.objectives,
    required this.materials,
    required this.activities,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String classSessionId;
  final String teacherProfileId;
  final String objectives;
  final String materials;
  final String activities;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TeachingPlan.fromMap(Map<String, dynamic> map) {
    return TeachingPlan(
      id: (map['id'] as String?) ?? '',
      classSessionId: (map['class_session_id'] as String?) ?? '',
      teacherProfileId: (map['teacher_profile_id'] as String?) ?? '',
      objectives: (map['objectives'] as String?) ?? '',
      materials: (map['materials'] as String?) ?? '',
      activities: (map['activities'] as String?) ?? '',
      createdAt: parseDateTime(map['created_at']),
      updatedAt: parseDateTime(map['updated_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'class_session_id': classSessionId,
    'teacher_profile_id': teacherProfileId,
    'objectives': objectives,
    'materials': materials,
    'activities': activities,
    'created_at': createdAt?.toUtc().toIso8601String(),
    'updated_at': updatedAt?.toUtc().toIso8601String(),
  };
}

class StudentActivityLog {
  const StudentActivityLog({
    required this.id,
    required this.childId,
    required this.classSessionId,
    required this.recordedByTeacherId,
    required this.activityType,
    required this.content,
    required this.recordedAt,
    required this.createdAt,
  });

  final String id;
  final String childId;
  final String? classSessionId;
  final String recordedByTeacherId;
  final String activityType;
  final String content;
  final DateTime? recordedAt;
  final DateTime? createdAt;

  factory StudentActivityLog.fromMap(Map<String, dynamic> map) {
    return StudentActivityLog(
      id: (map['id'] as String?) ?? '',
      childId: (map['child_id'] as String?) ?? '',
      classSessionId: map['class_session_id'] as String?,
      recordedByTeacherId: (map['recorded_by_teacher_id'] as String?) ?? '',
      activityType: (map['activity_type'] as String?) ?? 'OBSERVATION',
      content: (map['content'] as String?) ?? '',
      recordedAt: parseDateTime(map['recorded_at']),
      createdAt: parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'child_id': childId,
    'class_session_id': classSessionId,
    'recorded_by_teacher_id': recordedByTeacherId,
    'activity_type': activityType,
    'content': content,
    'recorded_at': recordedAt?.toUtc().toIso8601String(),
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
}

class Announcement {
  const Announcement({
    required this.id,
    required this.homeschoolId,
    required this.classGroupId,
    required this.authorUserId,
    required this.title,
    required this.body,
    required this.pinned,
    required this.createdAt,
  });

  final String id;
  final String homeschoolId;
  final String? classGroupId;
  final String authorUserId;
  final String title;
  final String body;
  final bool pinned;
  final DateTime? createdAt;

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: (map['id'] as String?) ?? '',
      homeschoolId: (map['homeschool_id'] as String?) ?? '',
      classGroupId: map['class_group_id'] as String?,
      authorUserId: (map['author_user_id'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      pinned: parseBool(map['pinned']),
      createdAt: parseDateTime(map['created_at']),
    );
  }
}

class AuditLog {
  const AuditLog({
    required this.id,
    required this.homeschoolId,
    required this.actorUserId,
    required this.actionType,
    required this.resourceType,
    required this.resourceId,
    required this.createdAt,
  });

  final String id;
  final String homeschoolId;
  final String? actorUserId;
  final String actionType;
  final String resourceType;
  final String resourceId;
  final DateTime? createdAt;

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: (map['id'] as String?) ?? '',
      homeschoolId: (map['homeschool_id'] as String?) ?? '',
      actorUserId: map['actor_user_id'] as String?,
      actionType: (map['action_type'] as String?) ?? '',
      resourceType: (map['resource_type'] as String?) ?? '',
      resourceId: (map['resource_id'] as String?) ?? '',
      createdAt: parseDateTime(map['created_at']),
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'homeschool_id': homeschoolId,
    'name': name,
    'status': status,
    'start_date': startDate?.toUtc().toIso8601String(),
    'end_date': endDate?.toUtc().toIso8601String(),
  };
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'term_id': termId,
    'name': name,
    'capacity': capacity,
  };
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'homeschool_id': homeschoolId,
    'name': name,
    'default_duration_min': defaultDurationMin,
  };
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'term_id': termId,
    'day_of_week': dayOfWeek,
    'start_time': startTime,
    'end_time': endTime,
  };
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'class_group_id': classGroupId,
    'course_id': courseId,
    'time_slot_id': timeSlotId,
    'title': title,
    'source_type': sourceType,
    'status': status,
  };
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'term_id': termId,
    'prompt': prompt,
    'status': status,
    'created_at': createdAt?.toUtc().toIso8601String(),
  };
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'proposal_id': proposalId,
    'class_group_id': classGroupId,
    'course_id': courseId,
    'time_slot_id': timeSlotId,
  };
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

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.homeschoolId,
    required this.classGroupId,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.content,
    required this.isHidden,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String homeschoolId;
  final String? classGroupId;
  final String authorUserId;
  final String authorDisplayName;
  final String content;
  final bool isHidden;
  final bool isPinned;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CommunityPost.fromMap(Map<String, dynamic> map) {
    return CommunityPost(
      id: map['id'] as String,
      homeschoolId: (map['homeschool_id'] as String?) ?? '',
      classGroupId: map['class_group_id'] as String?,
      authorUserId: (map['author_user_id'] as String?) ?? '',
      authorDisplayName: (map['author_display_name'] as String?) ?? 'Unknown',
      content: (map['content'] as String?) ?? '',
      isHidden: parseBool(map['is_hidden']),
      isPinned: parseBool(map['is_pinned']),
      createdAt: parseDateTime(map['created_at']),
      updatedAt: parseDateTime(map['updated_at']),
    );
  }
}

class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.postId,
    required this.homeschoolId,
    required this.reporterUserId,
    required this.reporterDisplayName,
    required this.reasonCategory,
    required this.reasonDetail,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.handledByUserId,
    required this.handledAt,
  });

  final String id;
  final String postId;
  final String homeschoolId;
  final String reporterUserId;
  final String reporterDisplayName;
  final String reasonCategory;
  final String reasonDetail;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? handledByUserId;
  final DateTime? handledAt;

  bool get isOpen => status == 'OPEN';

  factory CommunityReport.fromMap(Map<String, dynamic> map) {
    return CommunityReport(
      id: map['id'] as String,
      postId: (map['post_id'] as String?) ?? '',
      homeschoolId: (map['homeschool_id'] as String?) ?? '',
      reporterUserId: (map['reporter_user_id'] as String?) ?? '',
      reporterDisplayName:
          (map['reporter_display_name'] as String?) ?? 'Unknown',
      reasonCategory: (map['reason_category'] as String?) ?? 'OTHER',
      reasonDetail: (map['reason_detail'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'OPEN',
      createdAt: parseDateTime(map['created_at']),
      updatedAt: parseDateTime(map['updated_at']),
      handledByUserId: map['handled_by_user_id'] as String?,
      handledAt: parseDateTime(map['handled_at']),
    );
  }
}

class CommunityPostMedia {
  const CommunityPostMedia({
    required this.postId,
    required this.mediaAssetId,
    required this.mediaType,
    required this.driveWebViewLink,
    required this.title,
    required this.description,
  });

  final String postId;
  final String mediaAssetId;
  final String mediaType;
  final String? driveWebViewLink;
  final String title;
  final String description;

  bool get isVideo => mediaType == 'VIDEO';

  factory CommunityPostMedia.fromMap(Map<String, dynamic> map) {
    return CommunityPostMedia(
      postId: (map['post_id'] as String?) ?? '',
      mediaAssetId: (map['media_asset_id'] as String?) ?? '',
      mediaType: (map['media_type'] as String?) ?? 'PHOTO',
      driveWebViewLink: map['drive_web_view_link'] as String?,
      title: (map['title'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
    );
  }
}

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorUserId,
    required this.authorDisplayName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String postId;
  final String authorUserId;
  final String authorDisplayName;
  final String content;
  final DateTime? createdAt;

  factory CommunityComment.fromMap(Map<String, dynamic> map) {
    return CommunityComment(
      id: map['id'] as String,
      postId: (map['post_id'] as String?) ?? '',
      authorUserId: (map['author_user_id'] as String?) ?? '',
      authorDisplayName: (map['author_display_name'] as String?) ?? 'Unknown',
      content: (map['content'] as String?) ?? '',
      createdAt: parseDateTime(map['created_at']),
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

class ScheduleDraftIssue {
  const ScheduleDraftIssue({
    required this.code,
    required this.message,
    required this.severity,
    required this.sessionLocalId,
  });

  final String code;
  final String message;
  final String severity; // HARD | WARN
  final String? sessionLocalId;

  bool get isHard => severity == 'HARD';
}

class ScheduleOptionSession {
  const ScheduleOptionSession({
    required this.localId,
    required this.classGroupId,
    required this.courseId,
    required this.timeSlotId,
    required this.teacherMainId,
  });

  final String localId;
  final String classGroupId;
  final String courseId;
  final String timeSlotId;
  final String? teacherMainId;

  ScheduleOptionSession copyWith({
    String? localId,
    String? classGroupId,
    String? courseId,
    String? timeSlotId,
    String? teacherMainId,
    bool clearTeacherMainId = false,
  }) {
    return ScheduleOptionSession(
      localId: localId ?? this.localId,
      classGroupId: classGroupId ?? this.classGroupId,
      courseId: courseId ?? this.courseId,
      timeSlotId: timeSlotId ?? this.timeSlotId,
      teacherMainId: clearTeacherMainId
          ? null
          : (teacherMainId ?? this.teacherMainId),
    );
  }
}

class ScheduleOptionDraft {
  const ScheduleOptionDraft({
    required this.id,
    required this.label,
    required this.prompt,
    required this.sessions,
    required this.issues,
  });

  final String id;
  final String label;
  final String prompt;
  final List<ScheduleOptionSession> sessions;
  final List<ScheduleDraftIssue> issues;

  int get hardConflictCount => issues.where((issue) => issue.isHard).length;
  int get warningCount => issues.where((issue) => !issue.isHard).length;
  bool get hasHardConflicts => hardConflictCount > 0;

  ScheduleOptionDraft copyWith({
    String? id,
    String? label,
    String? prompt,
    List<ScheduleOptionSession>? sessions,
    List<ScheduleDraftIssue>? issues,
  }) {
    return ScheduleOptionDraft(
      id: id ?? this.id,
      label: label ?? this.label,
      prompt: prompt ?? this.prompt,
      sessions: sessions ?? this.sessions,
      issues: issues ?? this.issues,
    );
  }
}

enum DragPayloadType { course, session }

class DragPayload {
  const DragPayload({required this.type, required this.id});

  final DragPayloadType type;
  final String id;
}
