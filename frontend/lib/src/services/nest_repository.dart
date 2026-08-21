import 'dart:convert';
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

/// Marker for "the server side of this feature is not deployed yet".
///
/// Read paths degrade silently to empty results; write paths throw one of the
/// subtypes so the controller can show a Korean guidance message. [feature] is
/// a stable machine code — translation stays in the controller layer.
abstract class NestFeatureUnsupported implements Exception {
  const NestFeatureUnsupported();

  /// Stable feature code: `student_account` | `class_session_change` |
  /// `absence_report` | `nest_notify`.
  String get feature;

  @override
  String toString() => 'NestFeatureUnsupported($feature)';
}

/// `children.user_id` column / `link_child_account` RPC not deployed.
class StudentAccountUnsupported extends NestFeatureUnsupported {
  const StudentAccountUnsupported();

  @override
  String get feature => 'student_account';
}

/// `class_session_changes` table not deployed.
class ClassSessionChangeUnsupported extends NestFeatureUnsupported {
  const ClassSessionChangeUnsupported();

  @override
  String get feature => 'class_session_change';
}

/// `absence_reports` table / `report_absence` RPC not deployed.
class AbsenceReportUnsupported extends NestFeatureUnsupported {
  const AbsenceReportUnsupported();

  @override
  String get feature => 'absence_report';
}

/// `nest-notify` edge function not deployed (or its tables are missing).
class NestNotifyUnsupported extends NestFeatureUnsupported {
  const NestNotifyUnsupported();

  @override
  String get feature => 'nest_notify';
}

/// Thrown by [NestRepository.updatePhoneNumber] when the given value is not a
/// Korean mobile number. The controller turns this into a Korean message.
class InvalidPhoneNumber implements Exception {
  const InvalidPhoneNumber(this.input);

  final String input;

  @override
  String toString() => 'InvalidPhoneNumber($input)';
}

/// Result of a `nest-notify` edge function call. Mirrors the function's 200
/// response so callers can report honestly ("3명 발송 / 번호 없음 2명").
class NotifyResult {
  const NotifyResult({
    required this.accepted,
    required this.sent,
    required this.skippedNoPhone,
    required this.skippedNoAccount,
    required this.alreadyNotified,
    this.messageId,
  });

  factory NotifyResult.fromMap(Map<String, dynamic> map) {
    return NotifyResult(
      accepted: parseBool(map['accepted']),
      sent: _asInt(map['sent']),
      skippedNoPhone: _asInt(map['skipped_no_phone']),
      skippedNoAccount: _asInt(map['skipped_no_account']),
      alreadyNotified: parseBool(map['already_notified']),
      messageId: _normalizeNullable(map['message_id'] as String?),
    );
  }

  /// 서버가 실제로 발송을 접수했는지.
  final bool accepted;

  /// 문자를 실제로 보낸 수신자 수.
  final int sent;

  /// 계정은 있으나 유효한 휴대폰 번호가 없어 건너뛴 수신자 수.
  final int skippedNoPhone;

  /// 연결된 계정 자체가 없어 건너뛴 대상 수.
  final int skippedNoAccount;

  /// 이미 발송된 건이라 중복 발송이 차단됐는지(`force: true` 로 재발송 가능).
  final bool alreadyNotified;

  /// Solapi groupId. 미발송이면 null.
  final String? messageId;

  int get skippedTotal => skippedNoPhone + skippedNoAccount;

  bool get hasSent => sent > 0;
}

class NestRepository {
  NestRepository(this.client);

  final SupabaseClient client;
  bool? _classSessionLocationSupported;
  bool? _applyTimetableDraftSupported;

  /// 학생 계정 기능(20260814091000 마이그레이션) 배포 여부 캐시.
  bool? _childUserIdSupported;

  /// 수업 변경 공지(20260814092000) 배포 여부 캐시.
  bool? _classSessionChangesSupported;

  /// 결석 신고(20260814093000) 배포 여부 캐시.
  bool? _absenceReportsSupported;

  /// nest-notify Edge Function 배포 여부 캐시.
  bool? _nestNotifySupported;

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
    String? realName,
  }) async {
    // full_name = 앱 표시용 닉네임, real_name = 실명(교사/감독 매칭·관리자 확인용).
    final data = <String, dynamic>{};
    if (displayName != null && displayName.trim().isNotEmpty) {
      data['full_name'] = displayName.trim();
    }
    if (realName != null && realName.trim().isNotEmpty) {
      data['real_name'] = realName.trim();
    }
    final response = await client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: AppConfig.authEmailRedirectUrl,
      data: data.isEmpty ? null : data,
    );

    if (response.user == null) {
      throw const AuthException('회원가입 계정을 생성하지 못했습니다.');
    }

    return response;
  }

  /// 실명(real_name)을 auth 메타데이터와 profiles 테이블에 함께 반영한다.
  /// (기존 사용자 백필 및 프로필 설정 편집에 사용)
  Future<void> updateRealName(String realName) async {
    final trimmed = realName.trim();
    await client.auth.updateUser(UserAttributes(data: {'real_name': trimmed}));
    final uid = client.auth.currentUser?.id;
    if (uid != null) {
      await client
          .from('profiles')
          .update({'real_name': trimmed.isEmpty ? null : trimmed})
          .eq('id', uid);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    await client.auth.updateUser(
      UserAttributes(data: {'full_name': displayName.trim()}),
    );
  }

  /// 휴대폰 번호를 auth 메타데이터와 profiles 테이블에 함께 반영한다.
  /// (알림 발송은 profiles.phone 을 읽으므로 dual-write 가 필수다)
  ///
  /// 저장 전에 서버의 `normalize_kr_phone()` 과 같은 규칙으로 정규화한다:
  /// 숫자만 남기고 `+82`/`82` 는 `0` 으로 바꾼 뒤 `^01[016789]\d{7,8}$` 만 통과.
  /// 형식이 맞지 않으면 [InvalidPhoneNumber] 를 던진다(빈 값은 삭제로 취급).
  Future<void> updatePhoneNumber(String phone) async {
    final raw = phone.trim();
    final normalized = raw.isEmpty ? null : _normalizeKoreanPhone(raw);
    if (raw.isNotEmpty && normalized == null) {
      throw InvalidPhoneNumber(raw);
    }

    await client.auth.updateUser(
      UserAttributes(data: {'phone_number': normalized ?? ''}),
    );

    final uid = client.auth.currentUser?.id;
    if (uid != null) {
      await client
          .from('profiles')
          .update({'phone': normalized})
          .eq('id', uid);
    }
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

  /// 합류 요청 한 번에 승인: 멤버십 + (학부모면) 가정 연결 + (학생이면) 아이 계정 연결.
  ///
  /// [childId] 는 4-인자 approve_join_request(20260814091000) 가 배포된 서버에서만
  /// 의미가 있다. null 이면 파라미터 자체를 보내지 않아, 3-인자 구버전 함수만 있는
  /// 서버에서도 기존 승인 흐름이 그대로 동작한다.
  Future<void> approveJoinRequestWithFamily({
    required String requestId,
    required String role,
    String? familyId,
    String? childId,
  }) async {
    final params = <String, dynamic>{
      'p_request_id': requestId,
      'p_role': role,
      'p_family_id': familyId,
    };
    if (childId != null && childId.isNotEmpty) {
      params['p_child_id'] = childId;
    }
    await client.rpc('approve_join_request', params: params);
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

  /// `children.user_id`(학생 계정 연결) 포함 select. 마이그레이션 미배포 서버에서는
  /// 이 컬럼이 없으므로 [_childrenSelectLegacy] 로 자동 폴백한다.
  static const String _childrenSelect =
      'id, family_id, name, birth_date, profile_note, status, created_at, '
      'user_id, families!inner(homeschool_id, family_name)';

  static const String _childrenSelectLegacy =
      'id, family_id, name, birth_date, profile_note, status, created_at, '
      'families!inner(homeschool_id, family_name)';

  Future<List<ChildProfile>> fetchChildren({
    required String homeschoolId,
  }) async {
    if (_childUserIdSupported == false) {
      final legacyData = await client
          .from('children')
          .select(_childrenSelectLegacy)
          .eq('families.homeschool_id', homeschoolId)
          .order('created_at', ascending: false)
          .limit(600);

      return _asRows(legacyData).map(ChildProfile.fromMap).toList();
    }

    try {
      final data = await client
          .from('children')
          .select(_childrenSelect)
          .eq('families.homeschool_id', homeschoolId)
          .order('created_at', ascending: false)
          .limit(600);
      _childUserIdSupported = true;
      return _asRows(data).map(ChildProfile.fromMap).toList();
    } on PostgrestException catch (error) {
      if (_isMissingChildUserIdColumn(error)) {
        _childUserIdSupported = false;
        final legacyData = await client
            .from('children')
            .select(_childrenSelectLegacy)
            .eq('families.homeschool_id', homeschoolId)
            .order('created_at', ascending: false)
            .limit(600);

        return _asRows(legacyData).map(ChildProfile.fromMap).toList();
      }
      rethrow;
    }
  }

  /// 자녀에 학생 계정을 연결한다(관리자/스태프). `link_child_account` RPC 는
  /// STUDENT 멤버십도 함께 보장한다. 미배포면 [StudentAccountUnsupported].
  Future<ChildProfile> linkChildAccount({
    required String childId,
    required String userId,
  }) async {
    if (_childUserIdSupported == false) {
      throw const StudentAccountUnsupported();
    }

    try {
      final data = await client.rpc(
        'link_child_account',
        params: {'p_child_id': childId, 'p_user_id': userId},
      );
      _childUserIdSupported = true;
      return ChildProfile.fromMap(_asMap(data));
    } on PostgrestException catch (error) {
      if (_isMissingSchemaObject(error, 'link_child_account')) {
        _childUserIdSupported = false;
        throw const StudentAccountUnsupported();
      }
      rethrow;
    }
  }

  /// 자녀의 학생 계정 연결을 해제한다(관리자/스태프).
  Future<ChildProfile> unlinkChildAccount({required String childId}) async {
    if (_childUserIdSupported == false) {
      throw const StudentAccountUnsupported();
    }

    try {
      final data = await client.rpc(
        'unlink_child_account',
        params: {'p_child_id': childId},
      );
      _childUserIdSupported = true;
      return ChildProfile.fromMap(_asMap(data));
    } on PostgrestException catch (error) {
      if (_isMissingSchemaObject(error, 'unlink_child_account')) {
        _childUserIdSupported = false;
        throw const StudentAccountUnsupported();
      }
      rethrow;
    }
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
    final values = {
      'family_id': familyId,
      'name': name.trim(),
      'birth_date': birthDate,
      'profile_note': profileNote.trim(),
    };

    if (_childUserIdSupported == false) {
      final legacyRow = await client
          .from('children')
          .update(values)
          .eq('id', childId)
          .select(_childrenSelectLegacy)
          .single();

      return ChildProfile.fromMap(_asMap(legacyRow));
    }

    try {
      final row = await client
          .from('children')
          .update(values)
          .eq('id', childId)
          .select(_childrenSelect)
          .single();
      _childUserIdSupported = true;
      return ChildProfile.fromMap(_asMap(row));
    } on PostgrestException catch (error) {
      if (_isMissingChildUserIdColumn(error)) {
        _childUserIdSupported = false;
        final legacyRow = await client
            .from('children')
            .update(values)
            .eq('id', childId)
            .select(_childrenSelectLegacy)
            .single();

        return ChildProfile.fromMap(_asMap(legacyRow));
      }
      rethrow;
    }
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

  Future<void> updateAnnouncement({
    required String announcementId,
    required String? classGroupId,
    required String title,
    required String body,
    required bool pinned,
  }) {
    return client
        .from('announcements')
        .update({
          'class_group_id': _normalizeNullable(classGroupId),
          'title': title.trim(),
          'body': body.trim(),
          'pinned': pinned,
        })
        .eq('id', announcementId);
  }

  /// 공지 삭제. RLS delete 정책이 배포되지 않은 서버에서는 정책 미매칭으로
  /// 0건이 지워지고도 예외가 나지 않으므로, 실제로 지워진 행을 돌려받아
  /// 호출부가 "조용한 실패"를 구분할 수 있게 한다.
  Future<int> deleteAnnouncement({required String announcementId}) async {
    final data = await client
        .from('announcements')
        .delete()
        .eq('id', announcementId)
        .select('id');
    return _asRows(data).length;
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

  Future<void> updateAcademicEvent({
    required String eventId,
    required String title,
    required String description,
    required String eventDate,
    String? endDate,
  }) {
    return client
        .from('academic_events')
        .update({
          'title': title.trim(),
          'description': description.trim(),
          'event_date': eventDate,
          'end_date': _normalizeNullable(endDate),
        })
        .eq('id', eventId);
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

  static const String _termColumns =
      'id, homeschool_id, name, status, start_date, end_date';

  Future<List<Term>> fetchTerms({required String homeschoolId}) async {
    final data = await client
        .from('terms')
        .select(_termColumns)
        .eq('homeschool_id', homeschoolId)
        .order('start_date', ascending: false);

    return _asRows(data).map(Term.fromMap).toList();
  }

  static String _termDate(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 새 학기를 만든다. 상태는 항상 DRAFT로 시작한다(운영 전 초안).
  /// RLS는 HOMESCHOOL_ADMIN/STAFF만 INSERT를 허용한다.
  Future<Term> createTerm({
    required String homeschoolId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final created = await client
        .from('terms')
        .insert({
          'homeschool_id': homeschoolId,
          'name': name,
          'start_date': _termDate(startDate),
          'end_date': _termDate(endDate),
          'status': 'DRAFT',
        })
        .select(_termColumns)
        .single();

    return Term.fromMap(_asMap(created));
  }

  /// 학기 메타데이터(이름/기간/상태)를 수정한다. null 필드는 변경하지 않는다.
  Future<Term> updateTerm({
    required String termId,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (startDate != null) payload['start_date'] = _termDate(startDate);
    if (endDate != null) payload['end_date'] = _termDate(endDate);
    if (status != null) payload['status'] = status;

    final updated = await client
        .from('terms')
        .update(payload)
        .eq('id', termId)
        .select(_termColumns)
        .single();

    return Term.fromMap(_asMap(updated));
  }

  /// 학기를 삭제한다. 참조 테이블(반/세션/시간표/교실/자습)은 ON DELETE CASCADE로
  /// 함께 삭제되고, 학사 일정은 term_id가 NULL로 해제된다. ARCHIVED 학기는
  /// DB 트리거가 삭제를 막는다.
  Future<void> deleteTerm({required String termId}) async {
    await client.from('terms').delete().eq('id', termId);
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

  /// Delete every time slot for a term in a single server-side statement.
  /// Used when regenerating the whole grid so no stale/leftover row can
  /// collide with the unique (term, day, start, end) constraint.
  Future<void> deleteAllTimeSlots({required String termId}) async {
    await client.from('time_slots').delete().eq('term_id', termId);
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

  // ── 수업 변경 공지 (class_session_changes) ──
  //
  // class_sessions 는 날짜가 없는 주간 반복 템플릿이라, "이번 주만 휴강",
  // "다음 주부터 학기 끝까지 교실 이동" 같은 공지는 이 유효기간 테이블로 표현한다.
  // effective_to 가 null 이면 학기 끝까지, from == to 이면 그 하루만이다.

  static const String _classSessionChangeSelect =
      'id, class_session_id, change_type, effective_from, effective_to, '
      'new_time_slot_id, new_location, substitute_teacher_id, reason, '
      'created_by_user_id, notified_at, created_at';

  /// 여러 수업의 변경 공지를 한 번에 읽는다. 서버 미배포면 빈 리스트로 degrade 한다.
  Future<List<ClassSessionChange>> fetchClassSessionChanges({
    required List<String> classSessionIds,
  }) async {
    if (classSessionIds.isEmpty || _classSessionChangesSupported == false) {
      return const [];
    }

    try {
      final data = await client
          .from('class_session_changes')
          .select(_classSessionChangeSelect)
          .inFilter('class_session_id', classSessionIds)
          .order('effective_from', ascending: true);
      _classSessionChangesSupported = true;
      return _asRows(data).map(ClassSessionChange.fromMap).toList();
    } on PostgrestException catch (error) {
      if (_isMissingSchemaObject(error, 'class_session_changes')) {
        _classSessionChangesSupported = false;
        return const [];
      }
      rethrow;
    }
  }

  /// 수업 변경 공지를 등록한다(담당 교사/담임/ADMIN·STAFF).
  /// 서버 미배포면 [ClassSessionChangeUnsupported].
  Future<ClassSessionChange> createClassSessionChange({
    required String classSessionId,
    required String changeType,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    String? newTimeSlotId,
    String newLocation = '',
    String? substituteTeacherId,
    String reason = '',
  }) async {
    if (_classSessionChangesSupported == false) {
      throw const ClassSessionChangeUnsupported();
    }

    final values = <String, dynamic>{
      'class_session_id': classSessionId,
      'change_type': changeType,
      'effective_from': formatDateOnly(effectiveFrom),
      'effective_to': formatDateOnly(effectiveTo),
      'new_time_slot_id': _normalizeNullable(newTimeSlotId),
      'new_location': _normalizeNullable(newLocation),
      'substitute_teacher_id': _normalizeNullable(substituteTeacherId),
      'reason': reason.trim(),
      'created_by_user_id': client.auth.currentUser?.id,
    };

    try {
      final row = await client
          .from('class_session_changes')
          .insert(values)
          .select(_classSessionChangeSelect)
          .single();
      _classSessionChangesSupported = true;
      return ClassSessionChange.fromMap(_asMap(row));
    } on PostgrestException catch (error) {
      if (_isMissingSchemaObject(error, 'class_session_changes')) {
        _classSessionChangesSupported = false;
        throw const ClassSessionChangeUnsupported();
      }
      rethrow;
    }
  }

  /// 등록된 변경 공지를 수정한다. 내용이 바뀌었으므로 notified_at 을 비워
  /// 다시 발송할 수 있게 한다(교사는 자기가 만든 행만 수정 가능 — RLS).
  Future<ClassSessionChange> updateClassSessionChange({
    required String id,
    required String changeType,
    required DateTime effectiveFrom,
    DateTime? effectiveTo,
    String? newTimeSlotId,
    String newLocation = '',
    String? substituteTeacherId,
    String reason = '',
  }) async {
    if (_classSessionChangesSupported == false) {
      throw const ClassSessionChangeUnsupported();
    }

    final values = <String, dynamic>{
      'change_type': changeType,
      'effective_from': formatDateOnly(effectiveFrom),
      'effective_to': formatDateOnly(effectiveTo),
      'new_time_slot_id': _normalizeNullable(newTimeSlotId),
      'new_location': _normalizeNullable(newLocation),
      'substitute_teacher_id': _normalizeNullable(substituteTeacherId),
      'reason': reason.trim(),
      'notified_at': null,
    };

    try {
      final row = await client
          .from('class_session_changes')
          .update(values)
          .eq('id', id)
          .select(_classSessionChangeSelect)
          .single();
      _classSessionChangesSupported = true;
      return ClassSessionChange.fromMap(_asMap(row));
    } on PostgrestException catch (error) {
      if (_isMissingSchemaObject(error, 'class_session_changes')) {
        _classSessionChangesSupported = false;
        throw const ClassSessionChangeUnsupported();
      }
      rethrow;
    }
  }

  Future<void> deleteClassSessionChange({required String id}) async {
    if (_classSessionChangesSupported == false) {
      throw const ClassSessionChangeUnsupported();
    }

    try {
      await client.from('class_session_changes').delete().eq('id', id);
      _classSessionChangesSupported = true;
    } on PostgrestException catch (error) {
      if (_isMissingSchemaObject(error, 'class_session_changes')) {
        _classSessionChangesSupported = false;
        throw const ClassSessionChangeUnsupported();
      }
      rethrow;
    }
  }

  // ── 결석 신고 (absence_reports) ──
  //
  // 쓰기는 report_absence() RPC 로만 한다(INSERT 정책 없음). RPC 가 수강 여부·
  // 요일 일치·학기 범위·과거 날짜를 검증한다.

  static const String _absenceReportSelect =
      'id, class_session_id, child_id, occurrence_date, reason, '
      'reported_by_user_id, status, acknowledged_by_user_id, acknowledged_at, '
      'notified_at, created_at';

  /// 다가오는 수업 회차의 결석을 신고한다(학생 본인 또는 보호자).
  /// 이미 철회된 같은 회차 신고가 있으면 서버가 되살린다.
  Future<AbsenceReport> reportAbsence({
    required String classSessionId,
    required String childId,
    required DateTime occurrenceDate,
    String reason = '',
  }) async {
    if (_absenceReportsSupported == false) {
      throw const AbsenceReportUnsupported();
    }

    try {
      final data = await client.rpc(
        'report_absence',
        params: {
          'p_class_session_id': classSessionId,
          'p_child_id': childId,
          'p_occurrence_date': formatDateOnly(occurrenceDate),
          'p_reason': reason.trim(),
        },
      );
      _absenceReportsSupported = true;
      return AbsenceReport.fromMap(_asMap(data));
    } on PostgrestException catch (error) {
      if (_isMissingSchemaObject(error, 'report_absence')) {
        _absenceReportsSupported = false;
        throw const AbsenceReportUnsupported();
      }
      rethrow;
    }
  }

  /// 여러 수업의 결석 신고를 읽는다(RLS 가 보이는 범위로 좁힌다).
  /// [from] 을 주면 그 날짜(포함) 이후 회차만 가져온다.
  /// 서버 미배포면 빈 리스트로 degrade 한다.
  Future<List<AbsenceReport>> fetchAbsenceReports({
    required List<String> classSessionIds,
    DateTime? from,
  }) async {
    if (classSessionIds.isEmpty || _absenceReportsSupported == false) {
      return const [];
    }

    try {
      var query = client
          .from('absence_reports')
          .select(_absenceReportSelect)
          .inFilter('class_session_id', classSessionIds);

      final fromDate = formatDateOnly(from);
      if (fromDate != null) {
        query = query.gte('occurrence_date', fromDate);
      }

      final data = await query.order('occurrence_date', ascending: true);
      _absenceReportsSupported = true;
      return _asRows(data).map(AbsenceReport.fromMap).toList();
    } on PostgrestException catch (error) {
      if (_isMissingSchemaObject(error, 'absence_reports')) {
        _absenceReportsSupported = false;
        return const [];
      }
      rethrow;
    }
  }

  /// 결석 신고를 철회한다(신고자 본인 또는 담당 교사/ADMIN·STAFF).
  Future<AbsenceReport> cancelAbsenceReport({required String id}) async {
    if (_absenceReportsSupported == false) {
      throw const AbsenceReportUnsupported();
    }

    try {
      final data = await client.rpc(
        'cancel_absence_report',
        params: {'p_report_id': id},
      );
      _absenceReportsSupported = true;
      return AbsenceReport.fromMap(_asMap(data));
    } on PostgrestException catch (error) {
      if (_isMissingSchemaObject(error, 'cancel_absence_report')) {
        _absenceReportsSupported = false;
        throw const AbsenceReportUnsupported();
      }
      rethrow;
    }
  }

  /// 결석 신고를 확인 처리한다(담당 교사/ADMIN·STAFF).
  Future<AbsenceReport> acknowledgeAbsenceReport({required String id}) async {
    if (_absenceReportsSupported == false) {
      throw const AbsenceReportUnsupported();
    }

    try {
      final data = await client.rpc(
        'acknowledge_absence_report',
        params: {'p_report_id': id},
      );
      _absenceReportsSupported = true;
      return AbsenceReport.fromMap(_asMap(data));
    } on PostgrestException catch (error) {
      if (_isMissingSchemaObject(error, 'acknowledge_absence_report')) {
        _absenceReportsSupported = false;
        throw const AbsenceReportUnsupported();
      }
      rethrow;
    }
  }

  // ── 알림 발송 (nest-notify Edge Function) ──
  //
  // 클라이언트는 수신자를 절대 지정하지 않는다. 도메인 이벤트 {event, id} 만
  // 보내면 서버가 수신자를 해석·인가하고 Solapi 로 발송한다.

  /// 수업 변경 공지를 해당 반 학생·보호자에게 발송한다.
  /// [force] 가 true 면 이미 발송된 건도 재발송한다.
  Future<NotifyResult> notifyClassChange({
    required String changeId,
    String channel = 'sms',
    bool force = false,
  }) {
    return _invokeNestNotify(
      event: 'CLASS_CHANGE',
      id: changeId,
      channel: channel,
      force: force,
    );
  }

  /// 결석 신고를 담당 교사에게 발송한다.
  Future<NotifyResult> notifyAbsence({
    required String reportId,
    String channel = 'sms',
    bool force = false,
  }) {
    return _invokeNestNotify(
      event: 'ABSENCE',
      id: reportId,
      channel: channel,
      force: force,
    );
  }

  Future<NotifyResult> _invokeNestNotify({
    required String event,
    required String id,
    required String channel,
    required bool force,
  }) async {
    if (_nestNotifySupported == false) {
      throw const NestNotifyUnsupported();
    }

    try {
      final response = await client.functions.invoke(
        'nest-notify',
        body: {
          'event': event,
          'id': id,
          'channel': channel,
          'force': force,
        },
      );
      _nestNotifySupported = true;
      return NotifyResult.fromMap(_asMap(response.data));
    } on FunctionException catch (error) {
      if (_isMissingNestNotify(error)) {
        _nestNotifySupported = false;
        throw const NestNotifyUnsupported();
      }
      rethrow;
    }
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

  // ── Google Drive integration (admin connect + additive media mirror) ──

  /// Starts the admin OAuth flow. Returns the Google consent [auth_url] to open
  /// in a popup, or null if the edge function did not return one.
  Future<String?> driveConnectStart({required String homeschoolId}) async {
    final response = await client.functions.invoke(
      'google-drive-connect-start',
      body: {'homeschool_id': homeschoolId},
    );

    final authUrl = _asMap(response.data)['auth_url'];
    return authUrl is String && authUrl.isNotEmpty ? authUrl : null;
  }

  /// Reads the non-secret Drive integration row for a homeschool. Never selects
  /// google_access_token/google_refresh_token — those stay server-side only.
  Future<DriveIntegration?> fetchDriveIntegration(String homeschoolId) async {
    final row = await client
        .from('drive_integrations')
        .select('id, homeschool_id, status, root_folder_id, updated_at')
        .eq('homeschool_id', homeschoolId)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return DriveIntegration.fromMap(_asMap(row));
  }

  /// Uploads already-fetched bytes to Google Drive via the edge function. The
  /// function does not persist media_assets — callers must attach the returned
  /// ids with [attachDriveInfoToMediaAsset].
  Future<({String driveFileId, String? driveWebViewLink})?> uploadMediaToDrive({
    required String homeschoolId,
    required String uploadSessionId,
    required String fileName,
    required String mimeType,
    required List<int> bytes,
  }) async {
    final response = await client.functions.invoke(
      'google-drive-upload',
      body: {
        'homeschool_id': homeschoolId,
        'upload_session_id': uploadSessionId,
        'file_name': fileName,
        'mime_type': mimeType,
        'file_base64': base64Encode(bytes),
      },
    );

    final body = _asMap(response.data);
    final driveFileId = body['drive_file_id'];
    if (driveFileId is! String || driveFileId.isEmpty) {
      return null;
    }

    final link = body['drive_web_view_link'];
    return (
      driveFileId: driveFileId,
      driveWebViewLink: link is String && link.isNotEmpty ? link : null,
    );
  }

  /// Attaches the returned Drive ids to an already-inserted media asset.
  Future<void> attachDriveInfoToMediaAsset({
    required String mediaAssetId,
    required String driveFileId,
    String? driveWebViewLink,
  }) async {
    await client
        .from('media_assets')
        .update({
          'drive_file_id': driveFileId,
          'drive_web_view_link': driveWebViewLink,
        })
        .eq('id', mediaAssetId);
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

final RegExp _koreanMobilePattern = RegExp(r'^01[016789][0-9]{7,8}$');
final RegExp _nonDigitPattern = RegExp(r'[^0-9]');

/// 국내 휴대폰 번호를 하이픈 없는 `01x…` 형식으로 정규화한다.
/// 서버의 `public.normalize_kr_phone(text)` 과 같은 규칙이며, 형식이 다르면 null.
String? _normalizeKoreanPhone(String raw) {
  var digits = raw.replaceAll(_nonDigitPattern, '');
  if (digits.isEmpty) {
    return null;
  }
  // 국가번호 82 → 0 (국내 휴대폰은 항상 01 로 시작하므로 오탐 없음).
  if (digits.startsWith('82')) {
    digits = '0${digits.substring(2)}';
  }
  return _koreanMobilePattern.hasMatch(digits) ? digits : null;
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim()) ?? 0;
  }
  return 0;
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

/// True when the error indicates `children.user_id` (student account link)
/// does not exist yet — the 20260814091000 migration is not deployed.
bool _isMissingChildUserIdColumn(PostgrestException error) {
  if (error.code == '42703') {
    return true;
  }
  final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
  return message.contains('user_id') &&
      (message.contains('does not exist') ||
          message.contains('not found') ||
          message.contains('schema cache'));
}

/// True when the error means the named table/RPC is missing from the server
/// (migration not deployed, or PostgREST schema cache does not know it) rather
/// than a real runtime error raised inside it.
///
/// PGRST202 = RPC not found, PGRST205 = table not found,
/// 42P01 = undefined_table, 42883 = undefined_function.
bool _isMissingSchemaObject(PostgrestException error, String name) {
  final code = error.code;
  if (code == 'PGRST202' ||
      code == 'PGRST205' ||
      code == '42P01' ||
      code == '42883') {
    return true;
  }

  final message = '${error.message} ${error.details ?? ''}'.toLowerCase();
  return message.contains(name.toLowerCase()) &&
      (message.contains('not find') ||
          message.contains('schema cache') ||
          message.contains('does not exist') ||
          message.contains('not found'));
}

/// True when the `nest-notify` edge function itself is unavailable: a 404 with
/// no JSON `error` body (the function always answers with `{"error": ...}`), or
/// the function's own 503 "기능이 아직 준비되지 않았습니다" when its tables are missing.
bool _isMissingNestNotify(FunctionException error) {
  if (error.status == 503) {
    return true;
  }
  if (error.status != 404) {
    return false;
  }
  final details = error.details;
  if (details is Map) {
    final body = details.map((key, value) => MapEntry('$key', value));
    // 함수가 살아 있고 대상 행만 없는 경우 → 미배포가 아니다.
    if (body['error'] is String) {
      return false;
    }
  }
  return true;
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
