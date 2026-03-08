import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/nest_models.dart';

class BootstrapResult {
  const BootstrapResult({
    required this.homeschoolId,
    required this.termId,
    required this.classGroupId,
  });

  final String homeschoolId;
  final String termId;
  final String classGroupId;
}

class DriveUploadResult {
  const DriveUploadResult({
    required this.driveFileId,
    required this.driveWebViewLink,
  });

  final String driveFileId;
  final String? driveWebViewLink;
}

class CommunityReactionSnapshot {
  const CommunityReactionSnapshot({
    required this.likeCountsByPostId,
    required this.likedPostIds,
  });

  final Map<String, int> likeCountsByPostId;
  final Set<String> likedPostIds;
}

class NestRepository {
  NestRepository(this.client);

  final SupabaseClient client;
  bool? _classSessionLocationSupported;

  User? get currentUser => client.auth.currentUser;
  Session? get currentSession => client.auth.currentSession;
  Stream<AuthState> get authChanges => client.auth.onAuthStateChange;

  Future<void> signIn({required String email, required String password}) async {
    final response = await client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    if (response.user == null || response.session == null) {
      throw const AuthException('로그인 세션을 생성하지 못했습니다.');
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AppConfig.authEmailRedirectUrl,
    );

    if (response.user == null) {
      throw const AuthException('회원가입 계정을 생성하지 못했습니다.');
    }

    return response;
  }

  Future<void> signOut() => client.auth.signOut();

  Future<List<Membership>> fetchMemberships({required String userId}) async {
    final data = await client
        .from('homeschool_memberships')
        .select(
          'user_id, homeschool_id, role, status, homeschools(id, name, timezone)',
        )
        .eq('user_id', userId)
        .eq('status', 'ACTIVE');

    return _asRows(data).map(Membership.fromMap).toList(growable: false);
  }

  Future<List<Membership>> fetchHomeschoolMemberships({
    required String homeschoolId,
  }) async {
    final data = await client
        .from('homeschool_memberships')
        .select(
          'user_id, homeschool_id, role, status, homeschools(id, name, timezone)',
        )
        .eq('homeschool_id', homeschoolId)
        .order('created_at', ascending: true);

    return _asRows(data).map(Membership.fromMap).toList(growable: false);
  }

  Future<List<HomeschoolMemberDirectoryEntry>> searchHomeschoolMembers({
    required String homeschoolId,
    String query = '',
    int limit = 30,
  }) async {
    try {
      final data = await client.rpc(
        'search_homeschool_members',
        params: {
          'p_homeschool_id': homeschoolId,
          'p_query': query.trim(),
          'p_limit': limit,
        },
      );

      return _asRows(
        data,
      ).map(HomeschoolMemberDirectoryEntry.fromMap).toList(growable: false);
    } on PostgrestException {
      return const [];
    }
  }

  Future<void> grantMembershipRole({
    required String homeschoolId,
    required String userId,
    required String role,
  }) {
    return client.from('homeschool_memberships').upsert({
      'homeschool_id': homeschoolId,
      'user_id': userId,
      'role': role,
      'status': 'ACTIVE',
    }, onConflict: 'homeschool_id,user_id,role');
  }

  Future<void> revokeMembershipRole({
    required String homeschoolId,
    required String userId,
    required String role,
  }) {
    return client
        .from('homeschool_memberships')
        .delete()
        .eq('homeschool_id', homeschoolId)
        .eq('user_id', userId)
        .eq('role', role);
  }

  Future<List<HomeschoolInvite>> fetchHomeschoolInvites({
    required String homeschoolId,
  }) async {
    final data = await client
        .from('homeschool_invites')
        .select(
          'id, homeschool_id, invite_email, role, status, invite_token, '
          'expires_at, created_at, homeschools(id, name)',
        )
        .eq('homeschool_id', homeschoolId)
        .order('created_at', ascending: false)
        .limit(200);

    return _asRows(data).map(HomeschoolInvite.fromMap).toList(growable: false);
  }

  Future<List<HomeschoolInvite>> fetchPendingInvitesForEmail({
    required String email,
  }) async {
    final normalized = email.trim();
    if (normalized.isEmpty) {
      return const [];
    }

    final data = await client
        .from('homeschool_invites')
        .select(
          'id, homeschool_id, invite_email, role, status, invite_token, '
          'expires_at, created_at, homeschools(id, name)',
        )
        .ilike('invite_email', normalized)
        .eq('status', 'PENDING')
        .order('created_at', ascending: false)
        .limit(100);

    return _asRows(data).map(HomeschoolInvite.fromMap).toList(growable: false);
  }

  Future<HomeschoolInvite> createHomeschoolInvite({
    required String homeschoolId,
    required String inviteEmail,
    required String role,
    required String invitedByUserId,
    required DateTime expiresAt,
  }) async {
    final row = await client
        .from('homeschool_invites')
        .insert({
          'homeschool_id': homeschoolId,
          'invite_email': inviteEmail.trim().toLowerCase(),
          'role': role,
          'status': 'PENDING',
          'invited_by_user_id': invitedByUserId,
          'expires_at': expiresAt.toUtc().toIso8601String(),
        })
        .select(
          'id, homeschool_id, invite_email, role, status, invite_token, '
          'expires_at, created_at, homeschools(id, name)',
        )
        .single();

    return HomeschoolInvite.fromMap(_asMap(row));
  }

  Future<void> cancelHomeschoolInvite({required String inviteId}) {
    return client
        .from('homeschool_invites')
        .update({
          'status': 'CANCELED',
          'canceled_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', inviteId)
        .eq('status', 'PENDING');
  }

  Future<void> acceptHomeschoolInvite({required String inviteToken}) {
    return client.rpc(
      'accept_homeschool_invite',
      params: {'p_invite_token': inviteToken.trim()},
    );
  }

  Future<List<Family>> fetchFamilies({required String homeschoolId}) async {
    final data = await client
        .from('families')
        .select('id, homeschool_id, family_name, note, created_at')
        .eq('homeschool_id', homeschoolId)
        .order('created_at', ascending: false)
        .limit(300);

    return _asRows(data).map(Family.fromMap).toList(growable: false);
  }

  Future<Family> createFamily({
    required String homeschoolId,
    required String familyName,
    required String note,
  }) async {
    final row = await client
        .from('families')
        .insert({
          'homeschool_id': homeschoolId,
          'family_name': familyName.trim(),
          'note': note.trim(),
        })
        .select('id, homeschool_id, family_name, note, created_at')
        .single();

    return Family.fromMap(_asMap(row));
  }

  Future<Family> updateFamily({
    required String familyId,
    required String familyName,
    required String note,
  }) async {
    final row = await client
        .from('families')
        .update({'family_name': familyName.trim(), 'note': note.trim()})
        .eq('id', familyId)
        .select('id, homeschool_id, family_name, note, created_at')
        .single();

    return Family.fromMap(_asMap(row));
  }

  Future<List<ChildProfile>> fetchChildren({
    required String homeschoolId,
  }) async {
    final data = await client
        .from('children')
        .select(
          'id, family_id, name, birth_date, profile_note, status, created_at, '
          'families!inner(homeschool_id, family_name)',
        )
        .eq('families.homeschool_id', homeschoolId)
        .order('created_at', ascending: false)
        .limit(600);

    return _asRows(data).map(ChildProfile.fromMap).toList(growable: false);
  }

  Future<Map<String, List<String>>> fetchFamilyGuardianUserIds({
    required List<String> familyIds,
  }) async {
    if (familyIds.isEmpty) {
      return const {};
    }

    final data = await client
        .from('family_guardians')
        .select('family_id, user_id')
        .inFilter('family_id', familyIds);

    final grouped = <String, List<String>>{};
    for (final row in _asRows(data)) {
      final familyId = row['family_id'] as String?;
      final userId = row['user_id'] as String?;
      if (familyId == null || userId == null) {
        continue;
      }
      grouped.putIfAbsent(familyId, () => <String>[]);
      grouped[familyId]!.add(userId);
    }

    return grouped;
  }

  Future<ChildProfile> createChild({
    required String familyId,
    required String name,
    required String birthDate,
    required String profileNote,
  }) async {
    final data = await client.rpc(
      'create_child_admin',
      params: {
        'p_family_id': familyId,
        'p_name': name.trim(),
        'p_birth_date': birthDate,
        'p_profile_note': profileNote.trim(),
      },
    );

    return ChildProfile.fromMap(_asMap(data));
  }

  Future<ChildProfile> updateChild({
    required String childId,
    required String familyId,
    required String name,
    required String birthDate,
    required String profileNote,
  }) async {
    final row = await client
        .from('children')
        .update({
          'family_id': familyId,
          'name': name.trim(),
          'birth_date': birthDate,
          'profile_note': profileNote.trim(),
        })
        .eq('id', childId)
        .select(
          'id, family_id, name, birth_date, profile_note, status, created_at, '
          'families!inner(homeschool_id, family_name)',
        )
        .single();

    return ChildProfile.fromMap(_asMap(row));
  }

  Future<List<ClassEnrollment>> fetchClassEnrollments({
    required List<String> classGroupIds,
  }) async {
    if (classGroupIds.isEmpty) {
      return const [];
    }

    final data = await client
        .from('class_enrollments')
        .select('id, class_group_id, child_id, created_at')
        .inFilter('class_group_id', classGroupIds);

    return _asRows(data).map(ClassEnrollment.fromMap).toList(growable: false);
  }

  Future<void> upsertClassEnrollment({
    required String classGroupId,
    required String childId,
  }) {
    return client.from('class_enrollments').upsert({
      'class_group_id': classGroupId,
      'child_id': childId,
    }, onConflict: 'class_group_id,child_id');
  }

  Future<void> deleteClassEnrollment({
    required String classGroupId,
    required String childId,
  }) {
    return client
        .from('class_enrollments')
        .delete()
        .eq('class_group_id', classGroupId)
        .eq('child_id', childId);
  }

  Future<List<TeacherProfile>> fetchTeacherProfiles({
    required String homeschoolId,
  }) async {
    final data = await client
        .from('teacher_profiles')
        .select(
          'id, homeschool_id, user_id, display_name, teacher_type, specialties, bio, created_at',
        )
        .eq('homeschool_id', homeschoolId)
        .order('created_at', ascending: false)
        .limit(300);

    return _asRows(data).map(TeacherProfile.fromMap).toList(growable: false);
  }

  Future<TeacherProfile> createTeacherProfile({
    required String homeschoolId,
    required String displayName,
    required String teacherType,
    String? userId,
  }) async {
    final row = await client
        .from('teacher_profiles')
        .insert({
          'homeschool_id': homeschoolId,
          'user_id': _normalizeNullable(userId),
          'display_name': displayName.trim(),
          'teacher_type': teacherType,
          'specialties': const <String>[],
          'bio': '',
        })
        .select(
          'id, homeschool_id, user_id, display_name, teacher_type, specialties, bio, created_at',
        )
        .single();

    return TeacherProfile.fromMap(_asMap(row));
  }

  Future<TeacherProfile> updateTeacherProfile({
    required String teacherProfileId,
    required String displayName,
    required String teacherType,
    String? userId,
  }) async {
    final row = await client
        .from('teacher_profiles')
        .update({
          'display_name': displayName.trim(),
          'teacher_type': teacherType,
          'user_id': _normalizeNullable(userId),
        })
        .eq('id', teacherProfileId)
        .select(
          'id, homeschool_id, user_id, display_name, teacher_type, specialties, bio, created_at',
        )
        .single();

    return TeacherProfile.fromMap(_asMap(row));
  }

  Future<List<MemberUnavailabilityBlock>> fetchMemberUnavailabilityBlocks({
    required String homeschoolId,
  }) async {
    final data = await client
        .from('member_unavailability_blocks')
        .select(
          'id, homeschool_id, owner_kind, owner_id, day_of_week, start_time, end_time, note, created_at',
        )
        .eq('homeschool_id', homeschoolId)
        .order('day_of_week')
        .order('start_time')
        .limit(1200);

    return _asRows(
      data,
    ).map(MemberUnavailabilityBlock.fromMap).toList(growable: false);
  }

  Future<MemberUnavailabilityBlock> createMemberUnavailabilityBlock({
    required String homeschoolId,
    required String ownerKind,
    required String ownerId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required String note,
    required String createdByUserId,
  }) async {
    final row = await client
        .from('member_unavailability_blocks')
        .insert({
          'homeschool_id': homeschoolId,
          'owner_kind': ownerKind,
          'owner_id': ownerId,
          'day_of_week': dayOfWeek,
          'start_time': startTime,
          'end_time': endTime,
          'note': note.trim(),
          'created_by_user_id': createdByUserId,
        })
        .select(
          'id, homeschool_id, owner_kind, owner_id, day_of_week, start_time, end_time, note, created_at',
        )
        .single();

    return MemberUnavailabilityBlock.fromMap(_asMap(row));
  }

  Future<void> deleteMemberUnavailabilityBlock({required String blockId}) {
    return client
        .from('member_unavailability_blocks')
        .delete()
        .eq('id', blockId);
  }

  Future<List<SessionTeacherAssignment>> fetchSessionTeacherAssignments({
    required List<String> classSessionIds,
  }) async {
    if (classSessionIds.isEmpty) {
      return const [];
    }

    final data = await client
        .from('session_teacher_assignments')
        .select('id, class_session_id, teacher_profile_id, assignment_role')
        .inFilter('class_session_id', classSessionIds);

    return _asRows(
      data,
    ).map(SessionTeacherAssignment.fromMap).toList(growable: false);
  }

  Future<void> upsertSessionTeacherAssignment({
    required String classSessionId,
    required String teacherProfileId,
    required String assignmentRole,
  }) {
    return client.from('session_teacher_assignments').upsert({
      'class_session_id': classSessionId,
      'teacher_profile_id': teacherProfileId,
      'assignment_role': assignmentRole,
    }, onConflict: 'class_session_id,teacher_profile_id');
  }

  Future<void> setSessionMainTeacher({
    required String classSessionId,
    required String teacherProfileId,
  }) async {
    await client
        .from('session_teacher_assignments')
        .delete()
        .eq('class_session_id', classSessionId)
        .eq('assignment_role', 'MAIN')
        .neq('teacher_profile_id', teacherProfileId);

    await upsertSessionTeacherAssignment(
      classSessionId: classSessionId,
      teacherProfileId: teacherProfileId,
      assignmentRole: 'MAIN',
    );
  }

  Future<void> deleteSessionTeacherAssignment({
    required String classSessionId,
    required String teacherProfileId,
  }) {
    return client
        .from('session_teacher_assignments')
        .delete()
        .eq('class_session_id', classSessionId)
        .eq('teacher_profile_id', teacherProfileId);
  }

  Future<List<TeachingPlan>> fetchTeachingPlans({
    required List<String> classSessionIds,
  }) async {
    if (classSessionIds.isEmpty) {
      return const [];
    }

    final data = await client
        .from('teaching_plans')
        .select(
          'id, class_session_id, teacher_profile_id, objectives, materials, activities, created_at, updated_at',
        )
        .inFilter('class_session_id', classSessionIds)
        .order('created_at', ascending: false)
        .limit(500);

    return _asRows(data).map(TeachingPlan.fromMap).toList(growable: false);
  }

  Future<void> createTeachingPlan({
    required String classSessionId,
    required String teacherProfileId,
    required String objectives,
    required String materials,
    required String activities,
  }) {
    return client.from('teaching_plans').insert({
      'class_session_id': classSessionId,
      'teacher_profile_id': teacherProfileId,
      'objectives': objectives.trim(),
      'materials': materials.trim(),
      'activities': activities.trim(),
    });
  }

  Future<List<StudentActivityLog>> fetchStudentActivityLogs({
    required List<String> childIds,
  }) async {
    if (childIds.isEmpty) {
      return const [];
    }

    final data = await client
        .from('student_activity_logs')
        .select(
          'id, child_id, class_session_id, recorded_by_teacher_id, activity_type, content, recorded_at, created_at',
        )
        .inFilter('child_id', childIds)
        .order('recorded_at', ascending: false)
        .limit(800);

    return _asRows(
      data,
    ).map(StudentActivityLog.fromMap).toList(growable: false);
  }

  Future<void> createStudentActivityLog({
    required String childId,
    required String? classSessionId,
    required String recordedByTeacherId,
    required String activityType,
    required String content,
  }) {
    return client.from('student_activity_logs').insert({
      'child_id': childId,
      'class_session_id': _normalizeNullable(classSessionId),
      'recorded_by_teacher_id': recordedByTeacherId,
      'activity_type': activityType,
      'content': content.trim(),
    });
  }

  Future<List<Announcement>> fetchAnnouncements({
    required String homeschoolId,
  }) async {
    final data = await client
        .from('announcements')
        .select(
          'id, homeschool_id, class_group_id, author_user_id, title, body, pinned, created_at',
        )
        .eq('homeschool_id', homeschoolId)
        .order('pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(200);

    return _asRows(data).map(Announcement.fromMap).toList(growable: false);
  }

  Future<void> createAnnouncement({
    required String homeschoolId,
    required String? classGroupId,
    required String authorUserId,
    required String title,
    required String body,
    required bool pinned,
  }) {
    return client.from('announcements').insert({
      'homeschool_id': homeschoolId,
      'class_group_id': _normalizeNullable(classGroupId),
      'author_user_id': authorUserId,
      'title': title.trim(),
      'body': body.trim(),
      'pinned': pinned,
    });
  }

  Future<List<AuditLog>> fetchAuditLogs({
    required String homeschoolId,
    int limit = 200,
  }) async {
    final safeLimit = limit <= 0 ? 200 : limit;
    final data = await client
        .from('audit_logs')
        .select(
          'id, homeschool_id, actor_user_id, action_type, resource_type, resource_id, created_at',
        )
        .eq('homeschool_id', homeschoolId)
        .order('created_at', ascending: false)
        .limit(safeLimit);

    return _asRows(data).map(AuditLog.fromMap).toList(growable: false);
  }

  Future<void> insertAuditLog({
    required String homeschoolId,
    required String actorUserId,
    required String actionType,
    required String resourceType,
    required String resourceId,
    Map<String, dynamic>? beforeJson,
    Map<String, dynamic>? afterJson,
  }) {
    return client.from('audit_logs').insert({
      'homeschool_id': homeschoolId,
      'actor_user_id': actorUserId,
      'action_type': actionType,
      'resource_type': resourceType,
      'resource_id': resourceId,
      'before_json': beforeJson,
      'after_json': afterJson,
    });
  }

  Future<List<Term>> fetchTerms({required String homeschoolId}) async {
    final data = await client
        .from('terms')
        .select('id, homeschool_id, name, status, start_date, end_date')
        .eq('homeschool_id', homeschoolId)
        .order('start_date', ascending: false);

    return _asRows(data).map(Term.fromMap).toList(growable: false);
  }

  Future<List<ClassGroup>> fetchClassGroups({required String termId}) async {
    final data = await client
        .from('class_groups')
        .select('id, term_id, name, capacity')
        .eq('term_id', termId)
        .order('name');

    return _asRows(data).map(ClassGroup.fromMap).toList(growable: false);
  }

  Future<ClassGroup> createClassGroup({
    required String termId,
    required String name,
    required int capacity,
  }) async {
    final row = await client
        .from('class_groups')
        .insert({'term_id': termId, 'name': name.trim(), 'capacity': capacity})
        .select('id, term_id, name, capacity')
        .single();

    return ClassGroup.fromMap(_asMap(row));
  }

  Future<ClassGroup> updateClassGroup({
    required String classGroupId,
    required String name,
    required int capacity,
  }) async {
    final row = await client
        .from('class_groups')
        .update({'name': name.trim(), 'capacity': capacity})
        .eq('id', classGroupId)
        .select('id, term_id, name, capacity')
        .single();

    return ClassGroup.fromMap(_asMap(row));
  }

  Future<void> deleteClassGroup({required String classGroupId}) {
    return client.from('class_groups').delete().eq('id', classGroupId);
  }

  Future<List<Course>> fetchCourses({required String homeschoolId}) async {
    final data = await client
        .from('courses')
        .select('id, homeschool_id, name, default_duration_min')
        .eq('homeschool_id', homeschoolId)
        .order('name');

    return _asRows(data).map(Course.fromMap).toList(growable: false);
  }

  Future<Course> createCourse({
    required String homeschoolId,
    required String name,
    required int defaultDurationMin,
  }) async {
    final row = await client
        .from('courses')
        .insert({
          'homeschool_id': homeschoolId,
          'name': name.trim(),
          'default_duration_min': defaultDurationMin,
        })
        .select('id, homeschool_id, name, default_duration_min')
        .single();

    return Course.fromMap(_asMap(row));
  }

  Future<void> deleteCourse({required String courseId}) {
    return client.from('courses').delete().eq('id', courseId);
  }

  Future<List<TimeSlot>> fetchTimeSlots({required String termId}) async {
    final data = await client
        .from('time_slots')
        .select('id, term_id, day_of_week, start_time, end_time')
        .eq('term_id', termId)
        .order('day_of_week')
        .order('start_time');

    return _asRows(data).map(TimeSlot.fromMap).toList(growable: false);
  }

  Future<List<ClassSession>> fetchSessions({
    required String classGroupId,
  }) async {
    if (_classSessionLocationSupported == false) {
      final legacyData = await client
          .from('class_sessions')
          .select(
            'id, class_group_id, course_id, time_slot_id, title, source_type, status',
          )
          .eq('class_group_id', classGroupId)
          .neq('status', 'CANCELED');

      return _asRows(legacyData)
          .map((row) => ClassSession.fromMap({...row, 'location': null}))
          .toList(growable: false);
    }

    try {
      final data = await client
          .from('class_sessions')
          .select(
            'id, class_group_id, course_id, time_slot_id, title, source_type, status, location',
          )
          .eq('class_group_id', classGroupId)
          .neq('status', 'CANCELED');
      _classSessionLocationSupported = true;
      return _asRows(data).map(ClassSession.fromMap).toList(growable: false);
    } on PostgrestException catch (error) {
      if (_isMissingLocationColumn(error)) {
        _classSessionLocationSupported = false;
        final legacyData = await client
            .from('class_sessions')
            .select(
              'id, class_group_id, course_id, time_slot_id, title, source_type, status',
            )
            .eq('class_group_id', classGroupId)
            .neq('status', 'CANCELED');

        return _asRows(legacyData)
            .map((row) => ClassSession.fromMap({...row, 'location': null}))
            .toList(growable: false);
      }
      rethrow;
    }
  }

  Future<List<Proposal>> fetchProposals({required String termId}) async {
    final data = await client
        .from('timetable_proposals')
        .select('id, term_id, prompt, status, created_at')
        .eq('term_id', termId)
        .order('created_at', ascending: false)
        .limit(20);

    return _asRows(data).map(Proposal.fromMap).toList(growable: false);
  }

  Future<Map<String, List<ProposalSession>>> fetchProposalSessionsByProposal({
    required List<String> proposalIds,
  }) async {
    if (proposalIds.isEmpty) {
      return const {};
    }

    final data = await client
        .from('timetable_proposal_sessions')
        .select('id, proposal_id, class_group_id, course_id, time_slot_id')
        .inFilter('proposal_id', proposalIds);

    final grouped = <String, List<ProposalSession>>{};
    for (final row in _asRows(data)) {
      final proposalSession = ProposalSession.fromMap(row);
      grouped.putIfAbsent(
        proposalSession.proposalId,
        () => <ProposalSession>[],
      );
      grouped[proposalSession.proposalId]!.add(proposalSession);
    }

    return grouped;
  }

  Future<BootstrapResult> createBootstrapFrame({
    required String ownerUserId,
    required String? currentHomeschoolId,
    required String homeschoolName,
    required String termName,
    required String startDate,
    required String endDate,
    required String className,
    required List<String> courseNames,
  }) async {
    var homeschoolId = currentHomeschoolId;

    if (homeschoolId == null || homeschoolId.isEmpty) {
      final createdHomeschool = await client
          .from('homeschools')
          .insert({
            'name': homeschoolName,
            'owner_user_id': ownerUserId,
            'timezone': 'Asia/Seoul',
          })
          .select('id')
          .single();

      homeschoolId = _asMap(createdHomeschool)['id'] as String;
    }

    final createdTerm = await client
        .from('terms')
        .insert({
          'homeschool_id': homeschoolId,
          'name': termName,
          'start_date': startDate,
          'end_date': endDate,
          'status': 'DRAFT',
        })
        .select('id')
        .single();

    final termId = _asMap(createdTerm)['id'] as String;

    final createdClassGroup = await client
        .from('class_groups')
        .insert({'term_id': termId, 'name': className, 'capacity': 12})
        .select('id')
        .single();

    final classGroupId = _asMap(createdClassGroup)['id'] as String;

    if (courseNames.isNotEmpty) {
      final rows = courseNames
          .map(
            (name) => {
              'homeschool_id': homeschoolId,
              'name': name,
              'default_duration_min': 50,
            },
          )
          .toList(growable: false);

      await client
          .from('courses')
          .upsert(rows, onConflict: 'homeschool_id,name');
    }

    final defaultSlots = _defaultTimeSlots(termId: termId);
    await client
        .from('time_slots')
        .upsert(
          defaultSlots,
          onConflict: 'term_id,day_of_week,start_time,end_time',
        );

    return BootstrapResult(
      homeschoolId: homeschoolId,
      termId: termId,
      classGroupId: classGroupId,
    );
  }

  Future<GeneratedProposalDraft?> tryGenerateProposalWithEdgeFunction({
    required String termId,
    required String classGroupId,
    required String prompt,
  }) async {
    try {
      final response = await client.functions.invoke(
        'timetable-assistant-generate',
        body: {
          'term_id': termId,
          'class_group_id': classGroupId,
          'prompt': prompt,
        },
      );

      final body = _asMap(response.data);
      final sessionsRaw = body['sessions'];

      if (sessionsRaw is! List || sessionsRaw.isEmpty) {
        return null;
      }

      final sessions = sessionsRaw
          .whereType<Map>()
          .map((raw) => raw.map((key, value) => MapEntry('$key', value)))
          .map((map) {
            return GeneratedSessionDraft(
              classGroupId: (map['class_group_id'] as String?) ?? classGroupId,
              courseId: (map['course_id'] as String?) ?? '',
              timeSlotId: (map['time_slot_id'] as String?) ?? '',
              teacherMainId: map['teacher_main_id'] as String?,
              teacherAssistantIds:
                  (map['teacher_assistant_ids_json'] as List?)?.toList(
                    growable: false,
                  ) ??
                  const [],
              hardConflicts:
                  (map['hard_conflicts_json'] as List?)?.toList(
                    growable: false,
                  ) ??
                  const [],
              softWarnings:
                  (map['soft_warnings_json'] as List?)?.toList(
                    growable: false,
                  ) ??
                  const [],
            );
          })
          .where(
            (item) => item.courseId.isNotEmpty && item.timeSlotId.isNotEmpty,
          )
          .toList();

      if (sessions.isEmpty) {
        return null;
      }

      return GeneratedProposalDraft(
        source: (body['source'] as String?) ?? 'edge-function',
        sessions: sessions,
        hardConflicts:
            (body['hard_conflicts'] as List?)?.toList(growable: false) ??
            const [],
        softWarnings:
            (body['soft_warnings'] as List?)?.toList(growable: false) ??
            const [],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> persistProposal({
    required String termId,
    required String prompt,
    required String generatedByUserId,
    required GeneratedProposalDraft draft,
  }) async {
    final proposal = await client
        .from('timetable_proposals')
        .insert({
          'term_id': termId,
          'prompt': prompt,
          'status': 'GENERATED',
          'generated_by_user_id': generatedByUserId,
          'summary_json': {
            'source': draft.source,
            'hard_conflicts': draft.hardConflicts,
            'soft_warnings': draft.softWarnings,
          },
        })
        .select('id')
        .single();

    final proposalId = _asMap(proposal)['id'] as String;

    if (draft.sessions.isNotEmpty) {
      final rows = draft.sessions
          .map((session) => session.toProposalRow(proposalId))
          .toList(growable: false);

      await client.from('timetable_proposal_sessions').insert(rows);
    }
  }

  Future<void> setProposalStatus({
    required String proposalId,
    required String status,
  }) {
    return client
        .from('timetable_proposals')
        .update({'status': status})
        .eq('id', proposalId);
  }

  Future<void> createSession({
    required String classGroupId,
    required String courseId,
    required String timeSlotId,
    required String title,
    required String createdByUserId,
    String? location,
  }) async {
    await createSessionAndReturn(
      classGroupId: classGroupId,
      courseId: courseId,
      timeSlotId: timeSlotId,
      title: title,
      createdByUserId: createdByUserId,
      sourceType: 'MANUAL',
      location: location,
    );
  }

  Future<ClassSession> createSessionAndReturn({
    required String classGroupId,
    required String courseId,
    required String timeSlotId,
    required String title,
    required String createdByUserId,
    String sourceType = 'MANUAL',
    String? location,
  }) async {
    final normalizedLocation = _normalizeNullable(location) ?? '미정';
    final payload = {
      'class_group_id': classGroupId,
      'course_id': courseId,
      'time_slot_id': timeSlotId,
      'title': title,
      'source_type': sourceType,
      'status': 'PLANNED',
      'created_by_user_id': createdByUserId,
    };

    if (_classSessionLocationSupported == false) {
      final legacyRow = await client
          .from('class_sessions')
          .insert(payload)
          .select(
            'id, class_group_id, course_id, time_slot_id, title, source_type, status',
          )
          .single();
      final mapped = _asMap(legacyRow)..putIfAbsent('location', () => null);
      return ClassSession.fromMap(mapped);
    }

    try {
      final row = await client
          .from('class_sessions')
          .insert({...payload, 'location': normalizedLocation})
          .select(
            'id, class_group_id, course_id, time_slot_id, title, source_type, status, location',
          )
          .single();
      _classSessionLocationSupported = true;
      return ClassSession.fromMap(_asMap(row));
    } on PostgrestException catch (error) {
      if (_isMissingLocationColumn(error)) {
        _classSessionLocationSupported = false;
        final legacyRow = await client
            .from('class_sessions')
            .insert(payload)
            .select(
              'id, class_group_id, course_id, time_slot_id, title, source_type, status',
            )
            .single();
        final mapped = _asMap(legacyRow)..putIfAbsent('location', () => null);
        return ClassSession.fromMap(mapped);
      }
      if (_isLocationNullViolation(error)) {
        final retryRow = await client
            .from('class_sessions')
            .insert({...payload, 'location': '미정'})
            .select(
              'id, class_group_id, course_id, time_slot_id, title, source_type, status, location',
            )
            .single();
        _classSessionLocationSupported = true;
        return ClassSession.fromMap(_asMap(retryRow));
      }
      rethrow;
    }
  }

  Future<void> updateSessionLocation({
    required String sessionId,
    required String? location,
  }) async {
    if (_classSessionLocationSupported == false) {
      return;
    }

    final normalizedLocation = _normalizeNullable(location);

    try {
      await client
          .from('class_sessions')
          .update({'location': normalizedLocation})
          .eq('id', sessionId);
      _classSessionLocationSupported = true;
    } on PostgrestException catch (error) {
      if (_isMissingLocationColumn(error)) {
        _classSessionLocationSupported = false;
        return;
      }
      if (_isLocationNullViolation(error)) {
        await client
            .from('class_sessions')
            .update({'location': '미정'})
            .eq('id', sessionId);
        _classSessionLocationSupported = true;
        return;
      }
      rethrow;
    }
  }

  /// Fetch all non-canceled sessions for all class groups in a list of IDs.
  Future<List<ClassSession>> fetchSessionsForClassGroups({
    required List<String> classGroupIds,
  }) async {
    if (classGroupIds.isEmpty) return const [];
    if (_classSessionLocationSupported == false) {
      final legacyData = await client
          .from('class_sessions')
          .select(
            'id, class_group_id, course_id, time_slot_id, title, source_type, status',
          )
          .inFilter('class_group_id', classGroupIds)
          .neq('status', 'CANCELED');

      return _asRows(legacyData)
          .map((row) => ClassSession.fromMap({...row, 'location': null}))
          .toList(growable: false);
    }

    try {
      final data = await client
          .from('class_sessions')
          .select(
            'id, class_group_id, course_id, time_slot_id, title, source_type, status, location',
          )
          .inFilter('class_group_id', classGroupIds)
          .neq('status', 'CANCELED');
      _classSessionLocationSupported = true;
      return _asRows(data).map(ClassSession.fromMap).toList(growable: false);
    } on PostgrestException catch (error) {
      if (_isMissingLocationColumn(error)) {
        _classSessionLocationSupported = false;
        final legacyData = await client
            .from('class_sessions')
            .select(
              'id, class_group_id, course_id, time_slot_id, title, source_type, status',
            )
            .inFilter('class_group_id', classGroupIds)
            .neq('status', 'CANCELED');

        return _asRows(legacyData)
            .map((row) => ClassSession.fromMap({...row, 'location': null}))
            .toList(growable: false);
      }
      rethrow;
    }
  }

  Future<void> moveSession({
    required String sessionId,
    required String targetSlotId,
  }) {
    return client
        .from('class_sessions')
        .update({'time_slot_id': targetSlotId, 'source_type': 'MANUAL'})
        .eq('id', sessionId);
  }

  Future<void> cancelSession({required String sessionId}) {
    return client
        .from('class_sessions')
        .update({'status': 'CANCELED'})
        .eq('id', sessionId);
  }

  Future<String> createUploadSession({
    required String homeschoolId,
    required String uploaderUserId,
    required String mimeType,
    required int sizeBytes,
  }) async {
    final row = await client
        .from('media_upload_sessions')
        .insert({
          'homeschool_id': homeschoolId,
          'uploader_user_id': uploaderUserId,
          'status': 'UPLOADING',
          'mime_type': mimeType,
          'size_bytes': sizeBytes,
        })
        .select('id')
        .single();

    return _asMap(row)['id'] as String;
  }

  Future<DriveUploadResult> uploadToDrive({
    required String homeschoolId,
    required String uploadSessionId,
    required PendingMediaFile file,
  }) async {
    final response = await client.functions.invoke(
      'google-drive-upload',
      body: {
        'homeschool_id': homeschoolId,
        'upload_session_id': uploadSessionId,
        'file_name': file.name,
        'mime_type': file.mimeType,
        'file_base64': base64Encode(file.bytes),
      },
    );

    final body = _asMap(response.data);
    final driveFileId = body['drive_file_id'] as String?;

    if (driveFileId == null || driveFileId.isEmpty) {
      throw StateError('Drive 업로드 응답에 drive_file_id가 없습니다.');
    }

    return DriveUploadResult(
      driveFileId: driveFileId,
      driveWebViewLink: body['drive_web_view_link'] as String?,
    );
  }

  Future<String> insertMediaAsset({
    required String homeschoolId,
    required String uploadSessionId,
    required String uploaderUserId,
    required String? classGroupId,
    required DriveUploadResult uploadResult,
    required String title,
    required String description,
    required String mediaType,
  }) async {
    final row = await client
        .from('media_assets')
        .insert({
          'homeschool_id': homeschoolId,
          'upload_session_id': uploadSessionId,
          'drive_file_id': uploadResult.driveFileId,
          'drive_web_view_link': uploadResult.driveWebViewLink,
          'uploader_user_id': uploaderUserId,
          'class_group_id': classGroupId,
          'title': title,
          'description': description,
          'media_type': mediaType,
          'captured_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();

    return _asMap(row)['id'] as String;
  }

  Future<void> insertMediaChildren({
    required String mediaAssetId,
    required List<String> childIds,
  }) async {
    if (childIds.isEmpty) {
      return;
    }

    final rows = childIds
        .map((id) => {'media_asset_id': mediaAssetId, 'child_id': id})
        .toList(growable: false);

    await client.from('media_asset_children').insert(rows);
  }

  Future<void> updateUploadStatus({
    required String uploadSessionId,
    required String status,
  }) {
    return client
        .from('media_upload_sessions')
        .update({'status': status})
        .eq('id', uploadSessionId);
  }

  Future<List<GalleryItem>> fetchGalleryItems({
    required String homeschoolId,
    required String? classGroupId,
  }) async {
    final data = (classGroupId != null && classGroupId.isNotEmpty)
        ? await client
              .from('media_assets')
              .select(
                'id, title, description, media_type, drive_web_view_link, class_group_id, captured_at',
              )
              .eq('homeschool_id', homeschoolId)
              .eq('class_group_id', classGroupId)
              .order('captured_at', ascending: false)
              .limit(48)
        : await client
              .from('media_assets')
              .select(
                'id, title, description, media_type, drive_web_view_link, class_group_id, captured_at',
              )
              .eq('homeschool_id', homeschoolId)
              .order('captured_at', ascending: false)
              .limit(48);
    return _asRows(data).map(GalleryItem.fromMap).toList(growable: false);
  }

  Future<Map<String, List<String>>> fetchMediaChildrenByAsset({
    required List<String> mediaAssetIds,
  }) async {
    if (mediaAssetIds.isEmpty) {
      return const {};
    }

    final data = await client
        .from('media_asset_children')
        .select('media_asset_id, child_id')
        .inFilter('media_asset_id', mediaAssetIds);

    final grouped = <String, List<String>>{};
    for (final row in _asRows(data)) {
      final mediaAssetId = row['media_asset_id'] as String?;
      final childId = row['child_id'] as String?;
      if (mediaAssetId == null || childId == null) {
        continue;
      }
      grouped.putIfAbsent(mediaAssetId, () => <String>[]);
      grouped[mediaAssetId]!.add(childId);
    }

    return grouped;
  }

  Future<List<CommunityPost>> fetchCommunityPosts({
    required String homeschoolId,
  }) async {
    final data = await client
        .from('community_posts')
        .select(
          'id, homeschool_id, class_group_id, author_user_id, author_display_name, '
          'content, is_hidden, is_pinned, created_at, updated_at',
        )
        .eq('homeschool_id', homeschoolId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(120);

    return _asRows(data).map(CommunityPost.fromMap).toList(growable: false);
  }

  Future<List<CommunityReport>> fetchCommunityReports({
    required String homeschoolId,
  }) async {
    final data = await client
        .from('community_reports')
        .select(
          'id, post_id, homeschool_id, reporter_user_id, reporter_display_name, '
          'reason_category, reason_detail, status, created_at, updated_at, handled_by_user_id, handled_at',
        )
        .eq('homeschool_id', homeschoolId)
        .order('created_at', ascending: false)
        .limit(200);

    return _asRows(data).map(CommunityReport.fromMap).toList(growable: false);
  }

  Future<Map<String, List<CommunityPostMedia>>> fetchCommunityMediaByPost({
    required List<String> postIds,
  }) async {
    if (postIds.isEmpty) {
      return const {};
    }

    final data = await client
        .from('community_post_media')
        .select(
          'post_id, media_assets(id, media_type, drive_web_view_link, title, description)',
        )
        .inFilter('post_id', postIds);

    final out = <String, List<CommunityPostMedia>>{};

    for (final row in _asRows(data)) {
      final postId = row['post_id'] as String?;
      final mediaMap = _asMap(row['media_assets']);
      final mediaAssetId = mediaMap['id'] as String?;

      if (postId == null || mediaAssetId == null) {
        continue;
      }

      out.putIfAbsent(postId, () => <CommunityPostMedia>[]);
      out[postId]!.add(
        CommunityPostMedia.fromMap({
          'post_id': postId,
          'media_asset_id': mediaAssetId,
          'media_type': mediaMap['media_type'],
          'drive_web_view_link': mediaMap['drive_web_view_link'],
          'title': mediaMap['title'],
          'description': mediaMap['description'],
        }),
      );
    }

    return out;
  }

  Future<Map<String, List<CommunityComment>>> fetchCommunityCommentsByPost({
    required List<String> postIds,
  }) async {
    if (postIds.isEmpty) {
      return const {};
    }

    final data = await client
        .from('community_post_comments')
        .select(
          'id, post_id, author_user_id, author_display_name, content, created_at',
        )
        .inFilter('post_id', postIds)
        .order('created_at', ascending: true);

    final out = <String, List<CommunityComment>>{};
    for (final row in _asRows(data)) {
      final comment = CommunityComment.fromMap(row);
      out.putIfAbsent(comment.postId, () => <CommunityComment>[]);
      out[comment.postId]!.add(comment);
    }

    return out;
  }

  Future<CommunityReactionSnapshot> fetchCommunityReactions({
    required List<String> postIds,
    required String currentUserId,
  }) async {
    if (postIds.isEmpty) {
      return const CommunityReactionSnapshot(
        likeCountsByPostId: <String, int>{},
        likedPostIds: <String>{},
      );
    }

    final data = await client
        .from('community_post_reactions')
        .select('post_id, user_id, reaction_type')
        .inFilter('post_id', postIds)
        .eq('reaction_type', 'LIKE');

    final counts = <String, int>{};
    final liked = <String>{};

    for (final row in _asRows(data)) {
      final postId = row['post_id'] as String?;
      final userId = row['user_id'] as String?;
      if (postId == null || userId == null) {
        continue;
      }

      counts[postId] = (counts[postId] ?? 0) + 1;
      if (userId == currentUserId) {
        liked.add(postId);
      }
    }

    return CommunityReactionSnapshot(
      likeCountsByPostId: counts,
      likedPostIds: liked,
    );
  }

  Future<String> insertCommunityPost({
    required String homeschoolId,
    required String? classGroupId,
    required String authorUserId,
    required String authorDisplayName,
    required String content,
  }) async {
    final row = await client
        .from('community_posts')
        .insert({
          'homeschool_id': homeschoolId,
          'class_group_id': classGroupId,
          'author_user_id': authorUserId,
          'author_display_name': authorDisplayName,
          'content': content,
        })
        .select('id')
        .single();

    return _asMap(row)['id'] as String;
  }

  Future<void> linkCommunityPostMedia({
    required String postId,
    required String mediaAssetId,
  }) {
    return client.from('community_post_media').insert({
      'post_id': postId,
      'media_asset_id': mediaAssetId,
    });
  }

  Future<void> addCommunityComment({
    required String postId,
    required String authorUserId,
    required String authorDisplayName,
    required String content,
  }) {
    return client.from('community_post_comments').insert({
      'post_id': postId,
      'author_user_id': authorUserId,
      'author_display_name': authorDisplayName,
      'content': content,
    });
  }

  Future<void> upsertCommunityLike({
    required String postId,
    required String userId,
  }) {
    return client.from('community_post_reactions').upsert({
      'post_id': postId,
      'user_id': userId,
      'reaction_type': 'LIKE',
    }, onConflict: 'post_id,user_id');
  }

  Future<void> removeCommunityLike({
    required String postId,
    required String userId,
  }) {
    return client
        .from('community_post_reactions')
        .delete()
        .eq('post_id', postId)
        .eq('user_id', userId);
  }

  Future<void> createCommunityReport({
    required String postId,
    required String homeschoolId,
    required String reporterUserId,
    required String reporterDisplayName,
    required String reasonCategory,
    required String reasonDetail,
  }) {
    return client.from('community_reports').insert({
      'post_id': postId,
      'homeschool_id': homeschoolId,
      'reporter_user_id': reporterUserId,
      'reporter_display_name': reporterDisplayName,
      'reason_category': reasonCategory,
      'reason_detail': reasonDetail,
      'status': 'OPEN',
    });
  }

  Future<void> setCommunityReportStatus({
    required String reportId,
    required String status,
    required String handledByUserId,
  }) {
    return client
        .from('community_reports')
        .update({
          'status': status,
          'handled_by_user_id': handledByUserId,
          'handled_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', reportId);
  }

  Future<void> setCommunityPostHidden({
    required String postId,
    required bool hidden,
    required String handledByUserId,
  }) {
    return client
        .from('community_posts')
        .update({
          'is_hidden': hidden,
          'hidden_by_user_id': hidden ? handledByUserId : null,
          'hidden_at': hidden ? DateTime.now().toUtc().toIso8601String() : null,
        })
        .eq('id', postId);
  }

  Future<void> setCommunityPostPinned({
    required String postId,
    required bool pinned,
  }) {
    return client
        .from('community_posts')
        .update({'is_pinned': pinned})
        .eq('id', postId);
  }

  Future<void> deleteCommunityPost({required String postId}) {
    return client.from('community_posts').delete().eq('id', postId);
  }

  Future<DriveIntegration?> fetchDriveIntegration({
    required String homeschoolId,
  }) async {
    try {
      final richData = await client
          .from('drive_integrations')
          .select(
            'id, status, root_folder_id, folder_policy, connected_at, '
            'google_access_token, google_refresh_token, google_token_expires_at',
          )
          .eq('homeschool_id', homeschoolId)
          .maybeSingle();

      if (richData == null) {
        return null;
      }

      return DriveIntegration.fromMap(_asMap(richData));
    } on PostgrestException {
      final fallback = await client
          .from('drive_integrations')
          .select('id, status, root_folder_id, folder_policy, connected_at')
          .eq('homeschool_id', homeschoolId)
          .maybeSingle();

      if (fallback == null) {
        return null;
      }

      return DriveIntegration.fromMap(_asMap(fallback));
    }
  }

  Future<String> startGoogleDriveOauth({required String homeschoolId}) async {
    final response = await client.functions.invoke(
      'google-drive-connect-start',
      body: {'homeschool_id': homeschoolId},
    );

    final body = _asMap(response.data);
    final authUrl = body['auth_url'] as String?;

    if (authUrl == null || authUrl.isEmpty) {
      throw StateError('OAuth URL을 생성하지 못했습니다.');
    }

    return authUrl;
  }

  Future<void> upsertDriveIntegration({
    required String homeschoolId,
    required String userId,
    required String rootFolderId,
    required String folderPolicy,
    required String? accessToken,
    required String? refreshToken,
    required String? tokenExpiresAtIso,
  }) {
    return client.from('drive_integrations').upsert({
      'homeschool_id': homeschoolId,
      'provider': 'GOOGLE_DRIVE',
      'status': 'CONNECTED',
      'root_folder_id': rootFolderId,
      'folder_policy': folderPolicy,
      'connected_by_user_id': userId,
      'connected_at': DateTime.now().toUtc().toIso8601String(),
      'google_access_token': _normalizeNullable(accessToken),
      'google_refresh_token': _normalizeNullable(refreshToken),
      'google_token_expires_at': _normalizeNullable(tokenExpiresAtIso),
    }, onConflict: 'homeschool_id');
  }

  Future<void> disconnectDrive({required String homeschoolId}) {
    return client
        .from('drive_integrations')
        .update({
          'status': 'DISCONNECTED',
          'root_folder_id': null,
          'folder_policy': null,
          'google_access_token': null,
          'google_refresh_token': null,
          'google_token_expires_at': null,
        })
        .eq('homeschool_id', homeschoolId);
  }

  List<Map<String, dynamic>> _defaultTimeSlots({required String termId}) {
    const days = <int>[1, 2, 3, 4, 5];
    const times = <(String start, String end)>[
      ('09:30', '10:20'),
      ('10:30', '11:20'),
      ('11:30', '12:20'),
      ('13:30', '14:20'),
    ];

    final rows = <Map<String, dynamic>>[];
    for (final day in days) {
      for (final time in times) {
        rows.add({
          'term_id': termId,
          'day_of_week': day,
          'start_time': time.$1,
          'end_time': time.$2,
        });
      }
    }

    return rows;
  }
}

List<Map<String, dynamic>> _asRows(dynamic data) {
  if (data is List) {
    return data
        .whereType<Map>()
        .map((row) => row.map((key, value) => MapEntry('$key', value)))
        .toList(growable: false);
  }

  if (data is Map<String, dynamic>) {
    return [data];
  }

  return const [];
}

Map<String, dynamic> _asMap(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data;
  }

  if (data is Map) {
    return data.map((key, value) => MapEntry('$key', value));
  }

  return const {};
}

String? _normalizeNullable(String? value) {
  if (value == null) {
    return null;
  }

  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

bool _isMissingLocationColumn(PostgrestException error) {
  final message = error.message.toLowerCase();
  return message.contains('location') &&
      (message.contains('does not exist') || message.contains('not found'));
}

bool _isLocationNullViolation(PostgrestException error) {
  final message = error.message.toLowerCase();
  return message.contains('null value') && message.contains('location');
}
