import 'dart:typed_data';

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

class StorageUploadResult {
  const StorageUploadResult({
    required this.storagePath,
    required this.publicUrl,
  });

  final String storagePath;
  final String publicUrl;
}

class CommunityReactionSnapshot {
  const CommunityReactionSnapshot({
    required this.likeCountsByPostId,
    required this.likedPostIds,
  });

  final Map<String, int> likeCountsByPostId;
  final Set<String> likedPostIds;
}

/// Thrown by [NestRepository.applyTimetableDraft] when the optional
/// `apply_timetable_draft` RPC is not available on the server (e.g. the
/// Supabase migration has not been deployed yet). Callers must catch this and
/// fall back to the per-call commit loop, which always works.
class TimetableBatchUnsupported implements Exception {
  const TimetableBatchUnsupported();
}

class NestRepository {
  NestRepository(this.client);

  final SupabaseClient client;
  bool? _classSessionLocationSupported;
  bool? _applyTimetableDraftSupported;

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
    String? displayName,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AppConfig.authEmailRedirectUrl,
      data: displayName != null && displayName.trim().isNotEmpty
          ? {'full_name': displayName.trim()}
          : null,
    );

    if (response.user == null) {
      throw const AuthException('회원가입 계정을 생성하지 못했습니다.');
    }

    return response;
  }

  Future<void> updateDisplayName(String displayName) async {
    await client.auth.updateUser(
      UserAttributes(data: {'full_name': displayName.trim()}),
    );
  }

  Future<void> updatePhoneNumber(String phone) async {
    await client.auth.updateUser(
      UserAttributes(data: {'phone_number': phone.trim()}),
    );
  }

  /// 프로필 사진 업로드: 공개 'media' 버킷의 avatars/{userId}/ 경로에 저장하고,
  /// 공개 URL 을 사용자 메타데이터 avatar_url 에 기록한 뒤 URL 을 반환한다.
  /// 경로에 타임스탬프를 포함해 매번 고유 URL 이므로 캐시 무효화가 자연히 된다.
  Future<String> uploadAvatar({
    required String userId,
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) async {
    final ext = filename.contains('.')
        ? filename.substring(filename.lastIndexOf('.')).toLowerCase()
        : '.jpg';
    final path = 'avatars/$userId/${DateTime.now().millisecondsSinceEpoch}$ext';
    await client.storage.from('media').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    final url = client.storage.from('media').getPublicUrl(path);
    await client.auth.updateUser(UserAttributes(data: {'avatar_url': url}));
    return url;
  }

  Future<void> sendPasswordResetEmail({required String email}) {
    return client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: AppConfig.authEmailRedirectUrl,
    );
  }

  Future<void> signOut() => client.auth.signOut();

  Future<List<Membership>> fetchMemberships({required String userId}) async {
    final data = await client
        .from('homeschool_memberships')
        .select(
          'user_id, homeschool_id, role, status, homeschools(id, name, timezone, join_code)',
        )
        .eq('user_id', userId)
        .eq('status', 'ACTIVE');

    return _asRows(data).map(Membership.fromMap).toList();
  }

  Future<List<HomeschoolDirectoryEntry>> searchHomeschoolDirectory({
    String query = '',
    int limit = 24,
  }) async {
    final data = await client.rpc(
      'search_homeschool_directory',
      params: {'p_query': query.trim(), 'p_limit': limit},
    );
    return _asRows(
      data,
    ).map(HomeschoolDirectoryEntry.fromMap).toList();
  }

  Future<void> createHomeschoolJoinRequest({
    required String homeschoolId,
    required String requesterUserId,
    required String requesterEmail,
    required String requesterName,
    String requestNote = '',
  }) {
    return client.from('homeschool_join_requests').insert({
      'homeschool_id': homeschoolId,
      'requester_user_id': requesterUserId,
      'requester_email': requesterEmail.trim().toLowerCase(),
      'requester_name': requesterName.trim(),
      'request_note': requestNote.trim(),
      'status': 'PENDING',
    });
  }

  Future<List<HomeschoolJoinRequest>> fetchJoinRequests({
    required String homeschoolId,
  }) async {
    final data = await client
        .from('homeschool_join_requests')
        .select()
        .eq('homeschool_id', homeschoolId)
        .order('created_at', ascending: false);
    return _asRows(data)
        .map(HomeschoolJoinRequest.fromMap)
        .toList();
  }

  Future<void> updateJoinRequestStatus({
    required String requestId,
    required String status,
    required String reviewedByUserId,
  }) {
    return client.from('homeschool_join_requests').update({
      'status': status,
      'reviewed_by_user_id': reviewedByUserId,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
  }

  // ── 참여 코드로 간편 합류 ──

  /// 참여 코드 → 홈스쿨(id, name). 없으면 null.
  Future<({String homeschoolId, String name})?> resolveJoinCode(
    String code,
  ) async {
    final data = await client.rpc('resolve_join_code', params: {'p_code': code});
    final rows = _asRows(data);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      homeschoolId: (r['homeschool_id'] as String?) ?? '',
      name: (r['name'] as String?) ?? '',
    );
  }

  /// 코드 + 역할로 합류 요청 생성(중복/이미회원은 서버에서 처리). 홈스쿨명 반환.
  Future<({String homeschoolId, String name})?> requestJoinWithCode({
    required String code,
    required String role,
    String note = '',
  }) async {
    final data = await client.rpc('request_join_with_code', params: {
      'p_code': code,
      'p_role': role,
      'p_note': note,
    });
    final rows = _asRows(data);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return (
      homeschoolId: (r['homeschool_id'] as String?) ?? '',
      name: (r['name'] as String?) ?? '',
    );
  }

  /// 합류 요청 한 번에 승인: 멤버십 + (학부모면) 가정 연결.
  Future<void> approveJoinRequestWithFamily({
    required String requestId,
    required String role,
    String? familyId,
  }) async {
    await client.rpc('approve_join_request', params: {
      'p_request_id': requestId,
      'p_role': role,
      'p_family_id': familyId,
    });
  }

  /// 참여 코드 재발급(관리자). 새 코드 반환.
  Future<String> rotateJoinCode({required String homeschoolId}) async {
    final data = await client.rpc(
      'rotate_join_code',
      params: {'p_homeschool_id': homeschoolId},
    );
    return (data as String?) ?? '';
  }

  Future<List<Membership>> fetchHomeschoolMemberships({
    required String homeschoolId,
  }) async {
    final data = await client
        .from('homeschool_memberships')
        .select(
          'user_id, homeschool_id, role, status, homeschools(id, name, timezone, join_code)',
        )
        .eq('homeschool_id', homeschoolId)
        .order('created_at', ascending: true);

    return _asRows(data).map(Membership.fromMap).toList();
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
      ).map(HomeschoolMemberDirectoryEntry.fromMap).toList();
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
          'id, homeschool_id, homeschool_name, invite_email, role, status, invite_token, '
          'expires_at, created_at, homeschools(id, name)',
        )
        .eq('homeschool_id', homeschoolId)
        .order('created_at', ascending: false)
        .limit(200);

    return _asRows(data).map(HomeschoolInvite.fromMap).toList();
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
          'id, homeschool_id, homeschool_name, invite_email, role, status, invite_token, '
          'expires_at, created_at, homeschools(id, name)',
        )
        .ilike('invite_email', normalized)
        .eq('status', 'PENDING')
        .order('created_at', ascending: false)
        .limit(100);

    return _asRows(data).map(HomeschoolInvite.fromMap).toList();
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
          'id, homeschool_id, homeschool_name, invite_email, role, status, invite_token, '
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

    return _asRows(data).map(Family.fromMap).toList();
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

  Future<void> deleteFamily({required String familyId}) {
    return client.from('families').delete().eq('id', familyId);
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

    return _asRows(data).map(ChildProfile.fromMap).toList();
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

  Future<void> upsertFamilyGuardian({
    required String familyId,
    required String userId,
    required String guardianType,
  }) {
    return client.from('family_guardians').upsert({
      'family_id': familyId,
      'user_id': userId,
      'guardian_type': guardianType,
    }, onConflict: 'family_id,user_id');
  }

  Future<void> deleteFamilyGuardian({
    required String familyId,
    required String userId,
  }) {
    return client
        .from('family_guardians')
        .delete()
        .eq('family_id', familyId)
        .eq('user_id', userId);
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

  Future<void> createChildRegistrationRequest({
    required String homeschoolId,
    required String requesterUserId,
    required String familyName,
    required String childName,
    String? birthDate,
    String guardianType = 'GUARDIAN',
  }) {
    return client.from('child_registration_requests').insert({
      'homeschool_id': homeschoolId,
      'requester_user_id': requesterUserId,
      'family_name': familyName.trim(),
      'child_name': childName.trim(),
      'birth_date': birthDate,
      'guardian_type': guardianType,
      'status': 'PENDING',
    });
  }

  Future<List<Map<String, dynamic>>> fetchChildRegistrationRequests({
    required String homeschoolId,
  }) async {
    final data = await client
        .from('child_registration_requests')
        .select()
        .eq('homeschool_id', homeschoolId)
        .order('created_at', ascending: false);
    return _asRows(data);
  }

  Future<Map<String, dynamic>> approveChildRegistration({
    required String requestId,
  }) async {
    final data = await client.rpc(
      'approve_child_registration',
      params: {'p_request_id': requestId},
    );
    return _asMap(data);
  }

  Future<void> rejectChildRegistration({
    required String requestId,
    required String reviewedByUserId,
  }) {
    return client.from('child_registration_requests').update({
      'status': 'REJECTED',
      'reviewed_by_user_id': reviewedByUserId,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', requestId);
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

  Future<void> deleteChild({required String childId}) {
    return client.from('children').delete().eq('id', childId);
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

    return _asRows(data).map(ClassEnrollment.fromMap).toList();
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

    return _asRows(data).map(TeacherProfile.fromMap).toList();
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

  Future<void> deleteTeacherProfile({required String teacherProfileId}) {
    return client.from('teacher_profiles').delete().eq('id', teacherProfileId);
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
    ).map(MemberUnavailabilityBlock.fromMap).toList();
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
    ).map(SessionTeacherAssignment.fromMap).toList();
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

    return _asRows(data).map(TeachingPlan.fromMap).toList();
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
    ).map(StudentActivityLog.fromMap).toList();
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

    return _asRows(data).map(Announcement.fromMap).toList();
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

  // ── Academic Events (학사 일정) ──

  Future<List<AcademicEvent>> fetchAcademicEvents({
    required String homeschoolId,
    String? termId,
  }) async {
    var query = client
        .from('academic_events')
        .select()
        .eq('homeschool_id', homeschoolId);
    if (termId != null && termId.isNotEmpty) {
      query = query.eq('term_id', termId);
    }
    final data = await query.order('event_date', ascending: true).limit(200);
    return _asRows(data).map(AcademicEvent.fromMap).toList();
  }

  Future<void> createAcademicEvent({
    required String homeschoolId,
    required String? termId,
    required String title,
    required String description,
    required String eventDate,
    String? endDate,
    required String createdByUserId,
  }) {
    return client.from('academic_events').insert({
      'homeschool_id': homeschoolId,
      'term_id': _normalizeNullable(termId),
      'title': title.trim(),
      'description': description.trim(),
      'event_date': eventDate,
      'end_date': _normalizeNullable(endDate),
      'created_by_user_id': createdByUserId,
    });
  }

  Future<void> deleteAcademicEvent({required String eventId}) {
    return client.from('academic_events').delete().eq('id', eventId);
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

    return _asRows(data).map(AuditLog.fromMap).toList();
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

    return _asRows(data).map(Term.fromMap).toList();
  }

  Future<List<ClassGroup>> fetchClassGroups({required String termId}) async {
    final data = await client
        .from('class_groups')
        .select('id, term_id, name, capacity')
        .eq('term_id', termId)
        .order('name');

    return _asRows(data).map(ClassGroup.fromMap).toList();
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

    return _asRows(data).map(Course.fromMap).toList();
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

  Future<Course> updateCourse({
    required String courseId,
    required String name,
    required int defaultDurationMin,
  }) async {
    final row = await client
        .from('courses')
        .update({
          'name': name.trim(),
          'default_duration_min': defaultDurationMin,
        })
        .eq('id', courseId)
        .select('id, homeschool_id, name, default_duration_min')
        .single();

    return Course.fromMap(_asMap(row));
  }

  Future<void> deleteCourse({required String courseId}) {
    return client.from('courses').delete().eq('id', courseId);
  }

  Future<List<Classroom>> fetchClassrooms({required String termId}) async {
    final data = await client
        .from('classrooms')
        .select('id, term_id, name, capacity, note')
        .eq('term_id', termId)
        .order('name');

    return _asRows(data).map(Classroom.fromMap).toList();
  }

  Future<Classroom> createClassroom({
    required String termId,
    required String name,
    required int capacity,
    required String note,
  }) async {
    final row = await client
        .from('classrooms')
        .insert({
          'term_id': termId,
          'name': name.trim(),
          'capacity': capacity,
          'note': note.trim(),
        })
        .select('id, term_id, name, capacity, note')
        .single();

    return Classroom.fromMap(_asMap(row));
  }

  Future<Classroom> updateClassroom({
    required String classroomId,
    required String name,
    required int capacity,
    required String note,
  }) async {
    final row = await client
        .from('classrooms')
        .update({
          'name': name.trim(),
          'capacity': capacity,
          'note': note.trim(),
        })
        .eq('id', classroomId)
        .select('id, term_id, name, capacity, note')
        .single();

    return Classroom.fromMap(_asMap(row));
  }

  Future<void> deleteClassroom({required String classroomId}) {
    return client.from('classrooms').delete().eq('id', classroomId);
  }

  Future<List<TimeSlot>> fetchTimeSlots({required String termId}) async {
    final data = await client
        .from('time_slots')
        .select('id, term_id, day_of_week, start_time, end_time')
        .eq('term_id', termId)
        .order('day_of_week')
        .order('start_time');

    return _asRows(data).map(TimeSlot.fromMap).toList();
  }

  Future<TimeSlot> createTimeSlot({
    required String termId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    final data = await client.from('time_slots').insert({
      'term_id': termId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
    }).select().single();

    return TimeSlot.fromMap(data);
  }

  Future<TimeSlot> updateTimeSlot({
    required String slotId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    final data = await client
        .from('time_slots')
        .update({
          'day_of_week': dayOfWeek,
          'start_time': startTime,
          'end_time': endTime,
        })
        .eq('id', slotId)
        .select()
        .single();

    return TimeSlot.fromMap(data);
  }

  Future<void> deleteTimeSlot({required String slotId}) async {
    await client.from('time_slots').delete().eq('id', slotId);
  }

  /// Delete all time slots matching a specific time range across all days.
  Future<void> deleteTimeSlotsByTimeRange({
    required String termId,
    required String startTime,
    required String endTime,
  }) async {
    await client
        .from('time_slots')
        .delete()
        .eq('term_id', termId)
        .eq('start_time', startTime)
        .eq('end_time', endTime);
  }

  /// Delete all time slots for a specific day of the week.
  Future<void> deleteTimeSlotsByDay({
    required String termId,
    required int dayOfWeek,
  }) async {
    await client
        .from('time_slots')
        .delete()
        .eq('term_id', termId)
        .eq('day_of_week', dayOfWeek);
  }

  /// Update start/end times for all time slots matching old times across days.
  Future<void> updateTimeSlotTimeRange({
    required String termId,
    required String oldStartTime,
    required String oldEndTime,
    required String newStartTime,
    required String newEndTime,
  }) async {
    await client
        .from('time_slots')
        .update({
          'start_time': newStartTime,
          'end_time': newEndTime,
        })
        .eq('term_id', termId)
        .eq('start_time', oldStartTime)
        .eq('end_time', oldEndTime);
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
          .toList();
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
      return _asRows(data).map(ClassSession.fromMap).toList();
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
            .toList();
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

    return _asRows(data).map(Proposal.fromMap).toList();
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
          .toList();

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
            (body['hard_conflicts'] as List?)?.toList() ??
            const [],
        softWarnings:
            (body['soft_warnings'] as List?)?.toList() ??
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
          .toList();

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
          .toList();
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
      return _asRows(data).map(ClassSession.fromMap).toList();
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
            .toList();
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

  /// Hard-deletes a session row. FK children (session_teacher_assignments,
  /// teaching_plans) cascade; activity logs / media references set null.
  /// Use [cancelSession] instead when the record should be preserved.
  Future<void> deleteSession({required String sessionId}) {
    return client.from('class_sessions').delete().eq('id', sessionId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 공과 자습 시간표 (self-study plans / slots / exclusions)
  // ─────────────────────────────────────────────────────────────────────────

  static const String _selfStudyPlanCols =
      'id, term_id, name, days, window_start, window_end, period_start, '
      'period_end, min_gap_minutes, note, created_by_user_id, created_at, '
      'updated_at';
  static const String _selfStudySlotCols =
      'id, plan_id, class_group_id, day_of_week, start_time, end_time, room, '
      'supervisor_teacher_id, label, sort_order';

  Future<List<SelfStudyPlan>> fetchSelfStudyPlans({
    required String termId,
  }) async {
    final data = await client
        .from('self_study_plans')
        .select(_selfStudyPlanCols)
        .eq('term_id', termId)
        .order('created_at');
    return _asRows(data).map(SelfStudyPlan.fromMap).toList();
  }

  Future<SelfStudyPlan> createSelfStudyPlan({
    required String termId,
    required String name,
    required List<int> days,
    required String windowStart,
    required String windowEnd,
    String? periodStart,
    String? periodEnd,
    int minGapMinutes = 60,
    String note = '',
    String? createdByUserId,
  }) async {
    final row = await client
        .from('self_study_plans')
        .insert({
          'term_id': termId,
          'name': name.trim(),
          'days': days,
          'window_start': windowStart,
          'window_end': windowEnd,
          'period_start': periodStart,
          'period_end': periodEnd,
          'min_gap_minutes': minGapMinutes,
          'note': note.trim(),
          'created_by_user_id': ?createdByUserId,
        })
        .select(_selfStudyPlanCols)
        .single();
    return SelfStudyPlan.fromMap(_asMap(row));
  }

  Future<SelfStudyPlan> updateSelfStudyPlan({
    required String planId,
    required String name,
    required List<int> days,
    required String windowStart,
    required String windowEnd,
    String? periodStart,
    String? periodEnd,
    required int minGapMinutes,
    required String note,
  }) async {
    final row = await client
        .from('self_study_plans')
        .update({
          'name': name.trim(),
          'days': days,
          'window_start': windowStart,
          'window_end': windowEnd,
          'period_start': periodStart,
          'period_end': periodEnd,
          'min_gap_minutes': minGapMinutes,
          'note': note.trim(),
        })
        .eq('id', planId)
        .select(_selfStudyPlanCols)
        .single();
    return SelfStudyPlan.fromMap(_asMap(row));
  }

  Future<void> deleteSelfStudyPlan({required String planId}) {
    return client.from('self_study_plans').delete().eq('id', planId);
  }

  Future<List<SelfStudySlot>> fetchSelfStudySlots({
    required List<String> planIds,
  }) async {
    if (planIds.isEmpty) return const [];
    final data = await client
        .from('self_study_slots')
        .select(_selfStudySlotCols)
        .inFilter('plan_id', planIds)
        .order('sort_order');
    return _asRows(data).map(SelfStudySlot.fromMap).toList();
  }

  /// Replaces every slot of a plan in one shot: delete-all then bulk insert.
  /// Exclusions cascade-delete with the removed slots (regeneration is a fresh
  /// placement), so callers should only use this for (re)generation, not for
  /// routine room/supervisor edits ([updateSelfStudySlot]).
  Future<List<SelfStudySlot>> replaceSelfStudySlots({
    required String planId,
    required List<Map<String, dynamic>> slots,
  }) async {
    await client.from('self_study_slots').delete().eq('plan_id', planId);
    if (slots.isEmpty) return const [];
    final payload = slots
        .map((s) => {...s, 'plan_id': planId})
        .toList(growable: false);
    final data = await client
        .from('self_study_slots')
        .insert(payload)
        .select(_selfStudySlotCols);
    return _asRows(data).map(SelfStudySlot.fromMap).toList();
  }

  Future<SelfStudySlot> updateSelfStudySlot({
    required String slotId,
    required String room,
    required String? supervisorTeacherId,
    required String label,
  }) async {
    final row = await client
        .from('self_study_slots')
        .update({
          'room': room.trim(),
          'supervisor_teacher_id': supervisorTeacherId,
          'label': label.trim(),
        })
        .eq('id', slotId)
        .select(_selfStudySlotCols)
        .single();
    return SelfStudySlot.fromMap(_asMap(row));
  }

  Future<List<SelfStudySlotExclusion>> fetchSelfStudyExclusions({
    required List<String> slotIds,
  }) async {
    if (slotIds.isEmpty) return const [];
    final data = await client
        .from('self_study_slot_exclusions')
        .select('id, slot_id, child_id')
        .inFilter('slot_id', slotIds);
    return _asRows(data).map(SelfStudySlotExclusion.fromMap).toList();
  }

  Future<void> addSelfStudyExclusion({
    required String slotId,
    required String childId,
  }) {
    return client.from('self_study_slot_exclusions').upsert(
      {'slot_id': slotId, 'child_id': childId},
      onConflict: 'slot_id,child_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> removeSelfStudyExclusion({
    required String slotId,
    required String childId,
  }) {
    return client
        .from('self_study_slot_exclusions')
        .delete()
        .eq('slot_id', slotId)
        .eq('child_id', childId);
  }

  static const String _selfStudySupervisionCols =
      'id, plan_id, day_of_week, room, band_start, band_end, '
      'occurrence_date, supervisor_teacher_id';

  Future<List<SelfStudySupervision>> fetchSelfStudySupervisions({
    required List<String> planIds,
  }) async {
    if (planIds.isEmpty) return const [];
    final data = await client
        .from('self_study_supervisions')
        .select(_selfStudySupervisionCols)
        .inFilter('plan_id', planIds);
    return _asRows(data).map(SelfStudySupervision.fromMap).toList();
  }

  /// (요일·방·밴드·날짜) 한 칸의 감독을 지정한다. 같은 키의 기존 행을 지우고
  /// 새로 넣는다(occurrence_date null 여부에 따라 유일 인덱스가 다르므로 직접 처리).
  Future<void> upsertSelfStudySupervision({
    required String planId,
    required int dayOfWeek,
    required String room,
    required String bandStart,
    required String bandEnd,
    required String? occurrenceDate,
    required String? supervisorTeacherId,
  }) async {
    var del = client
        .from('self_study_supervisions')
        .delete()
        .eq('plan_id', planId)
        .eq('day_of_week', dayOfWeek)
        .eq('room', room)
        .eq('band_start', bandStart);
    del = occurrenceDate == null
        ? del.isFilter('occurrence_date', null)
        : del.eq('occurrence_date', occurrenceDate);
    await del;
    await client.from('self_study_supervisions').insert({
      'plan_id': planId,
      'day_of_week': dayOfWeek,
      'room': room,
      'band_start': bandStart,
      'band_end': bandEnd,
      'occurrence_date': occurrenceDate,
      'supervisor_teacher_id': supervisorTeacherId,
    });
  }

  /// (요일·방·밴드·날짜) 오버라이드를 제거한다(→ 상위 규칙으로 폴백).
  Future<void> deleteSelfStudySupervision({
    required String planId,
    required int dayOfWeek,
    required String room,
    required String bandStart,
    required String? occurrenceDate,
  }) async {
    var del = client
        .from('self_study_supervisions')
        .delete()
        .eq('plan_id', planId)
        .eq('day_of_week', dayOfWeek)
        .eq('room', room)
        .eq('band_start', bandStart);
    del = occurrenceDate == null
        ? del.isFilter('occurrence_date', null)
        : del.eq('occurrence_date', occurrenceDate);
    await del;
  }

  /// Atomic batch commit of a class group's timetable draft via the optional
  /// `apply_timetable_draft` RPC. The whole apply runs in a single DB
  /// transaction, so any failure (RLS denial, TEACHER_SLOT_CONFLICT, archived
  /// term, etc.) rolls back every change.
  ///
  /// The RPC ships only with the Supabase migration, which is NOT part of the
  /// web deploy. If it is missing/uncallable this throws
  /// [TimetableBatchUnsupported] so callers can fall back to the per-call loop.
  Future<void> applyTimetableDraft({
    required String classGroupId,
    required List<Map<String, dynamic>> sessions,
    required List<String> deletedIds,
  }) async {
    if (_applyTimetableDraftSupported == false) {
      throw const TimetableBatchUnsupported();
    }

    try {
      await client.rpc(
        'apply_timetable_draft',
        params: {
          'p_class_group_id': classGroupId,
          'p_sessions': sessions,
          'p_deleted_ids': deletedIds,
        },
      );
      _applyTimetableDraftSupported = true;
    } on PostgrestException catch (error) {
      if (_isMissingApplyTimetableDraft(error)) {
        _applyTimetableDraftSupported = false;
        throw const TimetableBatchUnsupported();
      }
      _applyTimetableDraftSupported = true;
      rethrow;
    }
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

  Future<StorageUploadResult> uploadToStorage({
    required String homeschoolId,
    required PendingMediaFile file,
  }) async {
    final now = DateTime.now();
    final month = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final ext = file.name.contains('.')
        ? file.name.substring(file.name.lastIndexOf('.'))
        : '';
    final uniqueName =
        '${now.millisecondsSinceEpoch}_${file.name.hashCode.abs()}$ext';
    final storagePath = '$homeschoolId/$month/$uniqueName';

    await client.storage.from('media').uploadBinary(
          storagePath,
          file.bytes,
          fileOptions: FileOptions(contentType: file.mimeType),
        );

    final publicUrl =
        client.storage.from('media').getPublicUrl(storagePath);

    return StorageUploadResult(
      storagePath: storagePath,
      publicUrl: publicUrl,
    );
  }

  Future<String> insertMediaAsset({
    required String homeschoolId,
    required String? uploadSessionId,
    required String uploaderUserId,
    required String? classGroupId,
    required StorageUploadResult uploadResult,
    required String title,
    required String description,
    required String mediaType,
  }) async {
    final row = await client
        .from('media_assets')
        .insert({
          'homeschool_id': homeschoolId,
          'upload_session_id': ?uploadSessionId,
          'storage_path': uploadResult.storagePath,
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
        .toList();

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
                'id, title, description, media_type, drive_web_view_link, storage_path, class_group_id, captured_at',
              )
              .eq('homeschool_id', homeschoolId)
              .eq('class_group_id', classGroupId)
              .order('captured_at', ascending: false)
              .limit(48)
        : await client
              .from('media_assets')
              .select(
                'id, title, description, media_type, drive_web_view_link, storage_path, class_group_id, captured_at',
              )
              .eq('homeschool_id', homeschoolId)
              .order('captured_at', ascending: false)
              .limit(48);
    return _asRows(data).map(GalleryItem.fromMap).toList();
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

    return _asRows(data).map(CommunityPost.fromMap).toList();
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

    return _asRows(data).map(CommunityReport.fromMap).toList();
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
          'post_id, media_assets(id, media_type, drive_web_view_link, storage_path, title, description)',
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
          'storage_path': mediaMap['storage_path'],
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

  /// Returns the public URL for a storage path in the 'media' bucket.
  String mediaPublicUrl(String storagePath) {
    return client.storage.from('media').getPublicUrl(storagePath);
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
        .toList();
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

/// True when the error indicates the optional `apply_timetable_draft` RPC is
/// missing/uncallable (function not deployed or not in the schema cache),
/// rather than a real runtime error raised inside the function.
bool _isMissingApplyTimetableDraft(PostgrestException error) {
  if (error.code == 'PGRST202') {
    return true;
  }
  final message = error.message.toLowerCase();
  return message.contains('apply_timetable_draft') &&
      (message.contains('not find') ||
          message.contains('schema cache') ||
          message.contains('does not exist') ||
          message.contains('function'));
}
