import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/nest_models.dart';
import '../services/local_planner.dart';
import '../services/nest_cache.dart';
import '../services/nest_repository.dart';

class NestController extends ChangeNotifier {
  NestController({
    required NestRepository repository,
  }) : _repository = repository;

  final NestRepository _repository;

  StreamSubscription<AuthState>? _authSubscription;

  bool _isBootstrapped = false;
  bool _isBusy = false;
  bool _isExplicitAuthInProgress = false;
  String _statusMessage = 'Ready';

  User? user;
  Session? session;

  List<Membership> memberships = [];
  List<Membership> homeschoolMemberships = [];
  List<HomeschoolInvite> homeschoolInvites = [];
  List<HomeschoolMemberDirectoryEntry> homeschoolMemberDirectory = [];
  List<HomeschoolInvite> pendingInvites = [];
  List<HomeschoolJoinRequest> joinRequests = [];
  List<ChildRegistrationRequest> childRegistrationRequests = [];
  List<Family> families = [];
  List<ChildProfile> children = [];
  List<ClassEnrollment> classEnrollments = [];
  Map<String, List<String>> familyGuardianUserIdsByFamily = const {};
  List<TeacherProfile> teacherProfiles = [];
  List<MemberUnavailabilityBlock> memberUnavailabilityBlocks = [];
  List<SessionTeacherAssignment> sessionTeacherAssignments = [];
  List<TeachingPlan> teachingPlans = [];
  List<StudentActivityLog> studentActivityLogs = [];
  List<Announcement> announcements = [];
  List<AcademicEvent> academicEvents = [];
  List<AuditLog> auditLogs = [];
  String? selectedHomeschoolId;
  String? currentRole;
  final Map<String, String> _viewRoleByHomeschool = <String, String>{};
  final Map<String, String> _parentViewTargetByHomeschool = <String, String>{};
  final Map<String, String> _teacherViewTargetByHomeschool = <String, String>{};

  List<Term> terms = [];
  String? selectedTermId;

  List<ClassGroup> classGroups = [];
  String? selectedClassGroupId;

  List<Course> courses = [];
  List<Classroom> classrooms = [];
  List<TimeSlot> timeSlots = [];
  List<ClassSession> sessions = [];
  List<ClassSession> allTermSessions = [];

  List<Proposal> proposals = [];
  Map<String, List<ProposalSession>> proposalSessionsById = const {};
  List<ScheduleOptionDraft> scheduleOptionDrafts = [];
  String? selectedScheduleOptionId;

  List<GalleryItem> galleryItems = [];
  Map<String, List<String>> mediaChildrenByAsset = const {};
  PendingMediaFile? pendingMediaFile;

  List<CommunityPost> communityPosts = [];
  Map<String, List<CommunityPostMedia>> communityMediaByPost = const {};
  Map<String, List<CommunityComment>> communityCommentsByPost = const {};
  Map<String, int> communityLikeCountsByPost = const {};
  Set<String> likedCommunityPostIds = <String>{};
  List<CommunityReport> communityReports = [];
  PendingMediaFile? pendingCommunityMediaFile;

  /// Suppress intermediate UI rebuilds while a [_runBusy] operation is active.
  /// Standalone calls (outside _runBusy) still notify immediately.
  void _notifyIfIdle() {
    if (!_isBusy) notifyListeners();
  }

  bool get isBusy => _isBusy;
  bool get isLoggedIn => user != null;
  bool get isBootstrapped => _isBootstrapped;
  String get statusMessage => _statusMessage;
  ScheduleOptionDraft? get selectedScheduleOption {
    final targetId = selectedScheduleOptionId;
    if (targetId == null) {
      return scheduleOptionDrafts.firstOrNull;
    }
    return scheduleOptionDrafts
        .where((draft) => draft.id == targetId)
        .firstOrNull;
  }

  List<String> get availableViewRoles {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      return const [];
    }

    final roles = memberships
        .where((membership) => membership.homeschoolId == homeschoolId)
        .map((membership) => membership.role)
        .toSet();

    const rolePriority = <String>[
      'HOMESCHOOL_ADMIN',
      'STAFF',
      'TEACHER',
      'GUEST_TEACHER',
      'PARENT',
    ];

    final ordered = rolePriority.where(roles.contains).toList();
    if (ordered.isNotEmpty) {
      return ordered;
    }

    return roles.toList();
  }

  bool get hasAdminLikeMembershipInSelectedHomeschool {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      return false;
    }

    return memberships.any(
      (membership) =>
          membership.homeschoolId == homeschoolId &&
          (membership.role == 'HOMESCHOOL_ADMIN' || membership.role == 'STAFF'),
    );
  }

  String? get selectedParentViewTargetUserId {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      return null;
    }
    return _parentViewTargetByHomeschool[homeschoolId];
  }

  String? get selectedTeacherViewTargetProfileId {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      return null;
    }
    return _teacherViewTargetByHomeschool[homeschoolId];
  }

  List<String> get parentViewCandidateUserIds {
    final ids = parentCandidateUserIds
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final sorted = ids.toList()
      ..sort((left, right) {
        final leftName = findMemberDisplayName(left).toLowerCase();
        final rightName = findMemberDisplayName(right).toLowerCase();
        final byName = leftName.compareTo(rightName);
        if (byName != 0) {
          return byName;
        }
        return left.compareTo(right);
      });
    return sorted;
  }

  List<TeacherProfile> get teacherViewCandidateProfiles {
    final rows = teacherProfiles.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
    return rows;
  }

  String? get activeParentViewTargetUserId {
    final currentUserId = user?.id;
    if (!isParentView || !hasAdminLikeMembershipInSelectedHomeschool) {
      return currentUserId;
    }

    final candidates = parentViewCandidateUserIds;
    if (candidates.isEmpty) {
      return null;
    }

    final selected = selectedParentViewTargetUserId;
    if (selected != null && candidates.contains(selected)) {
      return selected;
    }

    if (currentUserId != null && candidates.contains(currentUserId)) {
      return currentUserId;
    }
    return candidates.first;
  }

  String? get activeTeacherViewTargetProfileId {
    if (!isTeacherView || !hasAdminLikeMembershipInSelectedHomeschool) {
      return null;
    }

    final candidates = teacherViewCandidateProfiles;
    if (candidates.isEmpty) {
      return null;
    }

    final selected = selectedTeacherViewTargetProfileId;
    if (selected != null &&
        candidates.any((profile) => profile.id == selected)) {
      return selected;
    }

    final currentUserId = user?.id;
    final myProfile = candidates
        .where((profile) => profile.userId == currentUserId)
        .firstOrNull;
    if (myProfile != null) {
      return myProfile.id;
    }
    return candidates.first.id;
  }

  bool get isAdminLike =>
      currentRole == 'HOMESCHOOL_ADMIN' || currentRole == 'STAFF';

  bool get canManageMemberships => currentRole == 'HOMESCHOOL_ADMIN';
  bool get isParentView => currentRole == 'PARENT';
  bool get isTeacherView =>
      currentRole == 'TEACHER' || currentRole == 'GUEST_TEACHER';

  bool get canUploadMedia => const {
    'HOMESCHOOL_ADMIN',
    'STAFF',
    'TEACHER',
    'GUEST_TEACHER',
    'PARENT',
  }.contains(currentRole);

  bool get canWriteCommunity => const {
    'HOMESCHOOL_ADMIN',
    'STAFF',
    'TEACHER',
    'GUEST_TEACHER',
    'PARENT',
  }.contains(currentRole);

  bool get canModerateCommunity => isAdminLike;
  bool get canManageFamilies => isAdminLike;
  bool get canManageTeacherAssignments => isAdminLike;
  bool get canWriteTeachingPlan => isTeacherView || isAdminLike;
  bool get canWriteActivityLog => isTeacherView || isAdminLike;
  bool get canWriteAnnouncement => isTeacherView || isAdminLike;

  Future<void> initialize() async {
    if (_isBootstrapped) {
      return;
    }

    session = _repository.currentSession;
    user = _repository.currentUser;

    // Restore cached state instantly before any network calls.
    if (isLoggedIn) {
      _restoreFromCache();
    }

    _authSubscription = _repository.authChanges.listen((authState) {
      if (_isExplicitAuthInProgress) return;
      unawaited(_onAuthStateChanged(authState.session));
    });

    if (isLoggedIn) {
      // If cache was restored, show UI immediately, then refresh in background.
      if (memberships.isNotEmpty) {
        _isBootstrapped = true;
        notifyListeners();
        await _fetchFreshAndCache();
        return;
      }
      await loadHomeschoolContext();
    }

    _isBootstrapped = true;
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    _isExplicitAuthInProgress = true;
    try {
      await _runBusy('로그인 중...', () async {
        await _repository.signIn(email: email.trim(), password: password.trim());
        await _onAuthStateChanged(_repository.currentSession);
        _setStatus('로그인 성공');
      });
    } finally {
      _isExplicitAuthInProgress = false;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _isExplicitAuthInProgress = true;
    try {
      await _runBusy('회원가입 중...', () async {
        final response = await _repository.signUp(
          email: email.trim(),
          password: password.trim(),
          displayName: displayName?.trim(),
        );

        final currentSession = _repository.currentSession;

        if (currentSession != null) {
          await _onAuthStateChanged(currentSession);
          _setStatus('회원가입 및 로그인 완료');
          return;
        }

        _setStatus(
          response.user != null
              ? '회원가입 완료. 이메일 인증 설정이 켜져 있으면 인증 후 로그인하세요.'
              : '회원가입을 완료하지 못했습니다.',
        );
      });
    } finally {
      _isExplicitAuthInProgress = false;
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) {
      throw StateError('닉네임을 입력하세요.');
    }

    await _runBusy('닉네임 변경 중...', () async {
      await _repository.updateDisplayName(trimmed);
      _setStatus('닉네임이 변경되었습니다.');
    });
  }

  Future<void> updatePhoneNumber(String phone) async {
    final trimmed = phone.trim();
    await _runBusy('연락처 변경 중...', () async {
      await _repository.updatePhoneNumber(trimmed);
      _setStatus('연락처가 변경되었습니다.');
    });
  }

  Future<void> requestPasswordReset({required String email}) async {
    final normalized = email.trim();
    if (normalized.isEmpty) {
      throw StateError('비밀번호 재설정 이메일을 입력하세요.');
    }

    await _runBusy('비밀번호 재설정 메일 발송 중...', () async {
      await _repository.sendPasswordResetEmail(email: normalized);
      _setStatus('비밀번호 재설정 메일을 보냈습니다. 메일함을 확인하세요.');
    });
  }

  Future<void> signOut() async {
    _isExplicitAuthInProgress = true;
    try {
      await _runBusy('로그아웃 중...', () async {
        await NestCache.clearAll();
        await _repository.signOut();
        await _onAuthStateChanged(null);
        _setStatus('로그아웃 완료');
      });
    } finally {
      _isExplicitAuthInProgress = false;
    }
  }

  Future<void> refreshAll() async {
    await _runBusy('전체 컨텍스트 새로고침 중...', () async {
      await loadHomeschoolContext();
      _setStatus('전체 새로고침 완료');
    });
  }

  Future<void> changeHomeschool(String? homeschoolId) async {
    selectedHomeschoolId = _normalizeNullable(homeschoolId);
    currentRole = _resolveViewRole(selectedHomeschoolId);
    _ensureRoleViewTargetSelection();
    notifyListeners();

    await _runBusy('학기/반 정보를 불러오는 중...', () async {
      await _loadTermAndBelow();
      await Future.wait([
        loadHomeschoolMemberships(),
        loadHomeschoolInvites(),
        loadJoinRequests(),
        loadChildRegistrationRequests(),
        _loadOperationalData(),
        loadGalleryItems(),
        loadCommunityFeed(),
        loadAcademicEvents(),
      ]);
      _ensureRoleViewTargetSelection();
    });
  }

  Future<void> changeViewRole(String? role) async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final nextRole = _normalizeNullable(role);
    if (nextRole == null || !availableViewRoles.contains(nextRole)) {
      throw StateError('선택할 수 없는 뷰 역할입니다.');
    }

    currentRole = nextRole;
    _viewRoleByHomeschool[homeschoolId] = nextRole;
    _ensureRoleViewTargetSelection(roleOverride: nextRole);
    notifyListeners();

    await _runBusy('뷰 전환 중...', () async {
      await Future.wait([
        loadHomeschoolMemberships(),
        loadHomeschoolInvites(),
        loadJoinRequests(),
        _loadOperationalData(),
        loadCommunityFeed(),
      ]);
      _ensureRoleViewTargetSelection(roleOverride: nextRole);
      _setStatus('현재 뷰: $nextRole');
    });
  }

  Future<void> selectParentViewTargetUserId(String? userId) async {
    if (!hasAdminLikeMembershipInSelectedHomeschool) {
      throw StateError('관리자/스태프만 부모 뷰 대상을 전환할 수 있습니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final normalized = _normalizeNullable(userId);
    final candidates = parentViewCandidateUserIds;
    if (normalized != null && !candidates.contains(normalized)) {
      throw StateError('선택할 수 없는 부모 계정입니다.');
    }

    if (normalized == null) {
      _parentViewTargetByHomeschool.remove(homeschoolId);
    } else {
      _parentViewTargetByHomeschool[homeschoolId] = normalized;
    }
    _ensureRoleViewTargetSelection(roleOverride: 'PARENT');
    _setStatus(
      '부모 뷰 대상: ${findMemberDisplayName(activeParentViewTargetUserId)}',
    );
    notifyListeners();
    unawaited(_persistToCache());
  }

  Future<void> selectTeacherViewTargetProfileId(
    String? teacherProfileId,
  ) async {
    if (!hasAdminLikeMembershipInSelectedHomeschool) {
      throw StateError('관리자/스태프만 교사 뷰 대상을 전환할 수 있습니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final normalized = _normalizeNullable(teacherProfileId);
    final candidates = teacherViewCandidateProfiles
        .map((row) => row.id)
        .toSet();
    if (normalized != null && !candidates.contains(normalized)) {
      throw StateError('선택할 수 없는 교사 프로필입니다.');
    }

    if (normalized == null) {
      _teacherViewTargetByHomeschool.remove(homeschoolId);
    } else {
      _teacherViewTargetByHomeschool[homeschoolId] = normalized;
    }
    _ensureRoleViewTargetSelection(roleOverride: currentRole);
    _setStatus(
      '교사 뷰 대상: ${findTeacherName(activeTeacherViewTargetProfileId ?? '')}',
    );
    notifyListeners();
    unawaited(_persistToCache());
  }

  Future<void> changeTerm(String? termId) async {
    selectedTermId = _normalizeNullable(termId);
    scheduleOptionDrafts = [];
    selectedScheduleOptionId = null;
    notifyListeners();

    await _runBusy('반/시간표 데이터를 불러오는 중...', () async {
      await _loadClassGroups();
      await _loadTimetableAssets();
      await _loadSessions();
      await loadClassEnrollments();
      await loadSessionTeacherAssignments();
      await _loadProposals();
      await loadTeachingPlans();
      await loadAnnouncements();
      await loadGalleryItems();
      await loadCommunityFeed();
    });
  }

  Future<void> changeClassGroup(String? classGroupId) async {
    selectedClassGroupId = _normalizeNullable(classGroupId);
    scheduleOptionDrafts = [];
    selectedScheduleOptionId = null;
    notifyListeners();

    await _runBusy('수업 및 갤러리를 갱신하는 중...', () async {
      await _loadSessions();
      await loadClassEnrollments();
      await loadSessionTeacherAssignments();
      await loadTeachingPlans();
      await loadAnnouncements();
      await loadGalleryItems();
      await loadCommunityFeed();
    });
  }

  Future<void> bootstrapFrame({
    required String homeschoolName,
    required String termName,
    required String startDate,
    required String endDate,
    required String className,
    required String coursesCsv,
  }) async {
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final canBootstrap = isAdminLike || memberships.isEmpty;
    if (!canBootstrap) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final trimmedHomeschool = homeschoolName.trim();
    final trimmedTerm = termName.trim();
    final trimmedClass = className.trim();

    if (trimmedHomeschool.isEmpty ||
        trimmedTerm.isEmpty ||
        startDate.isEmpty ||
        endDate.isEmpty ||
        trimmedClass.isEmpty) {
      throw StateError('필수값을 모두 입력하세요.');
    }

    final courseNames = _parseCommaWords(coursesCsv);

    await _runBusy('기본 운영 틀 생성 중...', () async {
      final result = await _repository.createBootstrapFrame(
        ownerUserId: user!.id,
        currentHomeschoolId: selectedHomeschoolId,
        homeschoolName: trimmedHomeschool,
        termName: trimmedTerm,
        startDate: startDate,
        endDate: endDate,
        className: trimmedClass,
        courseNames: courseNames,
      );

      selectedHomeschoolId = result.homeschoolId;
      selectedTermId = result.termId;
      selectedClassGroupId = result.classGroupId;

      await loadHomeschoolContext();
      _setStatus('초기 세팅 완료');
    });
  }

  Future<void> generateProposal(String prompt) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    if (selectedTermId == null ||
        selectedClassGroupId == null ||
        user == null) {
      throw StateError('학기/반을 먼저 선택하세요.');
    }

    final trimmedPrompt = prompt.trim();
    if (trimmedPrompt.isEmpty) {
      throw StateError('프롬프트를 입력하세요.');
    }

    await _runBusy('생성안을 만들고 저장하는 중...', () async {
      final edgeDraft = await _repository.tryGenerateProposalWithEdgeFunction(
        termId: selectedTermId!,
        classGroupId: selectedClassGroupId!,
        prompt: trimmedPrompt,
      );

      final draft =
          edgeDraft ??
          buildLocalProposalDraft(
            prompt: trimmedPrompt,
            classGroupId: selectedClassGroupId!,
            courses: courses,
            timeSlots: timeSlots,
            existingSessions: sessions,
          );

      await _repository.persistProposal(
        termId: selectedTermId!,
        prompt: trimmedPrompt,
        generatedByUserId: user!.id,
        draft: draft,
      );

      await _loadProposals();
      _setStatus('생성안 저장 완료 (${draft.sessions.length}세션)');
    });
  }

  Future<void> applyProposal(String proposalId) async {
    if (!isAdminLike || user == null) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final proposalRows = proposalSessionsById[proposalId] ?? const [];
    if (proposalRows.isEmpty) {
      throw StateError('적용할 세션이 없습니다.');
    }

    await _runBusy('생성안을 시간표에 적용하는 중...', () async {
      var successCount = 0;
      var failedCount = 0;

      for (final row in proposalRows) {
        try {
          await _repository.createSession(
            classGroupId: row.classGroupId,
            courseId: row.courseId,
            timeSlotId: row.timeSlotId,
            title: '${findCourseName(row.courseId)} 수업',
            createdByUserId: user!.id,
          );
          successCount += 1;
        } catch (_) {
          failedCount += 1;
        }
      }

      if (successCount > 0) {
        await _repository.setProposalStatus(
          proposalId: proposalId,
          status: 'APPLIED',
        );
        await _logAudit(
          actionType: 'TIMETABLE_PROPOSAL_APPLY',
          resourceType: 'timetable_proposals',
          resourceId: proposalId,
          afterJson: {
            'applied_sessions': successCount,
            'failed_sessions': failedCount,
          },
        );
      }

      await _loadSessions();
      await loadSessionTeacherAssignments();
      await loadTeachingPlans();
      await _loadProposals();

      _setStatus('적용 결과: 성공 $successCount, 실패 $failedCount');
    });
  }

  Future<void> discardProposal(String proposalId) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy('생성안을 폐기하는 중...', () async {
      await _repository.setProposalStatus(
        proposalId: proposalId,
        status: 'DISCARDED',
      );
      await _loadProposals();
      _setStatus('생성안을 폐기했습니다.');
    });
  }

  Future<void> generateScheduleOptions({
    required String prompt,
    required Set<int> preferredDays,
    required int sessionsPerDay,
    Map<String, int> courseWeightsById = const {},
    Set<String> preferredTeacherIds = const {},
    String teacherStrategy = 'BALANCED',
    bool preferOnlySelectedTeachers = false,
    int optionCount = 3,
    bool keepExistingSessions = true,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }
    if (selectedClassGroupId == null) {
      throw StateError('반을 먼저 선택하세요.');
    }

    final trimmedPrompt = prompt.trim();
    final safePrompt = trimmedPrompt.isEmpty
        ? '현재 운영 조건을 반영해 안정적인 시간표를 생성해줘.'
        : trimmedPrompt;

    await _runBusy('질문 기반 시간표 초안을 생성하는 중...', () async {
      final classGroupId = selectedClassGroupId!;
      final blockedSlotIdsByTeacher = blockedSlotIdsByTeacherProfile();
      final blockedSlotsForParents = blockedSlotIdsForParentsInClass(
        classGroupId,
      );

      final drafts = buildWizardScheduleOptions(
        prompt: safePrompt,
        classGroupId: classGroupId,
        courses: courses,
        timeSlots: timeSlots,
        existingSessions: sessions,
        teacherProfiles: teacherProfiles,
        preferredDays: preferredDays,
        sessionsPerDay: sessionsPerDay,
        courseWeightsById: courseWeightsById,
        preferredTeacherIds: preferredTeacherIds,
        teacherStrategy: teacherStrategy,
        preferOnlySelectedTeachers: preferOnlySelectedTeachers,
        blockedSlotIds: blockedSlotsForParents,
        teacherBlockedSlotIdsByTeacher: blockedSlotIdsByTeacher,
        optionCount: optionCount,
        keepExistingSessions: keepExistingSessions,
      );

      scheduleOptionDrafts = drafts;
      selectedScheduleOptionId = drafts.firstOrNull?.id;
      _setStatus('질문 기반 초안 ${drafts.length}개를 생성했습니다.');
    });
  }

  void selectScheduleOptionDraft(String? optionId) {
    if (scheduleOptionDrafts.isEmpty) {
      selectedScheduleOptionId = null;
      notifyListeners();
      return;
    }

    final normalized = _normalizeNullable(optionId);
    if (normalized == null ||
        !scheduleOptionDrafts.any((draft) => draft.id == normalized)) {
      selectedScheduleOptionId = scheduleOptionDrafts.first.id;
      notifyListeners();
      return;
    }

    selectedScheduleOptionId = normalized;
    notifyListeners();
  }

  void updateScheduleOptionSession({
    required String optionId,
    required String sessionLocalId,
    String? courseId,
    String? timeSlotId,
    String? teacherMainId,
    bool clearTeacherMainId = false,
  }) {
    final draft = scheduleOptionDrafts
        .where((item) => item.id == optionId)
        .firstOrNull;
    if (draft == null) {
      return;
    }

    final updatedSessions = draft.sessions
        .map((session) {
          if (session.localId != sessionLocalId) {
            return session;
          }
          return session.copyWith(
            courseId: courseId,
            timeSlotId: timeSlotId,
            teacherMainId: teacherMainId,
            clearTeacherMainId: clearTeacherMainId,
          );
        })
        .toList();

    _replaceScheduleOptionDraft(
      draft.copyWith(
        sessions: updatedSessions,
        issues: _evaluateScheduleOptionIssues(updatedSessions),
      ),
    );
  }

  void addScheduleOptionSession(String optionId) {
    final draft = scheduleOptionDrafts
        .where((item) => item.id == optionId)
        .firstOrNull;
    final classGroupId = selectedClassGroupId;
    if (draft == null || classGroupId == null) {
      return;
    }

    final occupiedByDraft = draft.sessions
        .map((session) => session.timeSlotId)
        .toSet();
    final occupiedExisting = sessions.map((row) => row.timeSlotId).toSet();
    final blockedByParents = blockedSlotIdsForParentsInClass(classGroupId);
    final candidateSlot = timeSlots
        .where(
          (slot) =>
              !occupiedByDraft.contains(slot.id) &&
              !occupiedExisting.contains(slot.id) &&
              !blockedByParents.contains(slot.id),
        )
        .firstOrNull;
    final fallbackCourse = courses.firstOrNull;

    if (candidateSlot == null || fallbackCourse == null) {
      _setStatus('추가할 수 있는 슬롯/과목이 없습니다.');
      notifyListeners();
      return;
    }

    final nextIndex = draft.sessions.length + 1;
    final nextSession = ScheduleOptionSession(
      localId: '${draft.id}-add-$nextIndex',
      classGroupId: classGroupId,
      courseId: fallbackCourse.id,
      timeSlotId: candidateSlot.id,
      teacherMainId: teacherProfiles.firstOrNull?.id,
    );

    final updatedSessions = [...draft.sessions, nextSession];
    _replaceScheduleOptionDraft(
      draft.copyWith(
        sessions: updatedSessions,
        issues: _evaluateScheduleOptionIssues(updatedSessions),
      ),
    );
  }

  void removeScheduleOptionSession({
    required String optionId,
    required String sessionLocalId,
  }) {
    final draft = scheduleOptionDrafts
        .where((item) => item.id == optionId)
        .firstOrNull;
    if (draft == null) {
      return;
    }

    final updatedSessions = draft.sessions
        .where((session) => session.localId != sessionLocalId)
        .toList();

    _replaceScheduleOptionDraft(
      draft.copyWith(
        sessions: updatedSessions,
        issues: _evaluateScheduleOptionIssues(updatedSessions),
      ),
    );
  }

  List<ScheduleDraftIssue> _evaluateScheduleOptionIssues(
    List<ScheduleOptionSession> sessionsToEvaluate,
  ) {
    final classGroupId = selectedClassGroupId;
    final parentBlockedSlotIds = classGroupId == null
        ? const <String>{}
        : blockedSlotIdsForParentsInClass(classGroupId);

    return evaluateScheduleOptionIssues(
      sessions: sessionsToEvaluate,
      existingSessions: sessions,
      requireTeacher: true,
      blockedSlotIdsForParents: parentBlockedSlotIds,
      teacherBlockedSlotIdsByTeacher: blockedSlotIdsByTeacherProfile(),
    );
  }

  Future<void> applyScheduleOptionDraft(String optionId) async {
    if (!isAdminLike || user == null) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final classGroupId = selectedClassGroupId;
    if (classGroupId == null) {
      throw StateError('반을 먼저 선택하세요.');
    }

    final draft = scheduleOptionDrafts
        .where((item) => item.id == optionId)
        .firstOrNull;
    if (draft == null) {
      throw StateError('적용할 초안을 찾을 수 없습니다.');
    }

    final refreshedDraft = draft.copyWith(
      issues: _evaluateScheduleOptionIssues(draft.sessions),
    );
    if (refreshedDraft.hasHardConflicts) {
      _replaceScheduleOptionDraft(refreshedDraft);
      throw StateError('하드 충돌을 먼저 해결하세요.');
    }

    await _runBusy('초안을 시간표에 반영하는 중...', () async {
      var created = 0;
      var skippedBySlot = 0;
      var teacherConflicts = 0;

      final occupiedSlotIds = sessions.map((row) => row.timeSlotId).toSet();

      final sortedSessions = refreshedDraft.sessions.toList()
        ..sort((a, b) {
          final left = findTimeSlot(a.timeSlotId);
          final right = findTimeSlot(b.timeSlotId);
          if (left == null || right == null) {
            return a.timeSlotId.compareTo(b.timeSlotId);
          }
          final day = left.dayOfWeek.compareTo(right.dayOfWeek);
          if (day != 0) {
            return day;
          }
          return left.startTime.compareTo(right.startTime);
        });

      for (final row in sortedSessions) {
        if (row.classGroupId != classGroupId) {
          continue;
        }
        if (occupiedSlotIds.contains(row.timeSlotId)) {
          skippedBySlot += 1;
          continue;
        }

        final createdSession = await _repository.createSessionAndReturn(
          classGroupId: classGroupId,
          courseId: row.courseId,
          timeSlotId: row.timeSlotId,
          title: '${findCourseName(row.courseId)} 수업',
          createdByUserId: user!.id,
          sourceType: 'AI_PROMPT',
        );

        occupiedSlotIds.add(row.timeSlotId);
        created += 1;

        final teacherId = _normalizeNullable(row.teacherMainId);
        if (teacherId == null) {
          continue;
        }

        try {
          await _repository.setSessionMainTeacher(
            classSessionId: createdSession.id,
            teacherProfileId: teacherId,
          );
        } on PostgrestException catch (error) {
          if (error.message.contains('TEACHER_SLOT_CONFLICT')) {
            teacherConflicts += 1;
            continue;
          }
          rethrow;
        }
      }

      await _loadSessions();
      await loadSessionTeacherAssignments();
      await loadTeachingPlans();
      await _loadProposals();

      _setStatus(
        '초안 반영 완료: 생성 $created, 슬롯중복 건너뜀 $skippedBySlot, 교사충돌 $teacherConflicts',
      );
    });
  }

  Future<void> createSessionByCourse({
    required String courseId,
    required String slotId,
  }) async {
    if (!isAdminLike || user == null) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }
    if (selectedClassGroupId == null) {
      throw StateError('반을 먼저 선택하세요.');
    }

    final targetOccupied = sessions.any(
      (session) => session.timeSlotId == slotId,
    );
    if (targetOccupied) {
      throw StateError('해당 시간 슬롯에는 이미 수업이 있습니다.');
    }

    await _runBusy('수업을 생성하는 중...', () async {
      await _repository.createSession(
        classGroupId: selectedClassGroupId!,
        courseId: courseId,
        timeSlotId: slotId,
        title: '${findCourseName(courseId)} 수업',
        createdByUserId: user!.id,
      );
      await _loadSessions();
      await loadSessionTeacherAssignments();
      await loadTeachingPlans();
      _setStatus('수업 생성 완료');
    });
  }

  Future<void> moveSession({
    required String sessionId,
    required String targetSlotId,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final targetOccupied = sessions.any(
      (session) =>
          session.timeSlotId == targetSlotId && session.id != sessionId,
    );

    if (targetOccupied) {
      throw StateError('대상 슬롯이 이미 사용 중입니다.');
    }

    await _runBusy('수업을 이동하는 중...', () async {
      await _repository.moveSession(
        sessionId: sessionId,
        targetSlotId: targetSlotId,
      );
      await _loadSessions();
      await loadSessionTeacherAssignments();
      await loadTeachingPlans();
      _setStatus('수업 이동 완료');
    });
  }

  Future<void> cancelSession(String sessionId) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy('수업을 취소하는 중...', () async {
      await _repository.cancelSession(sessionId: sessionId);
      await _loadSessions();
      await loadSessionTeacherAssignments();
      await loadTeachingPlans();
      _setStatus('수업 취소 완료');
    });
  }

  Future<void> updateSessionLocation({
    required String sessionId,
    required String? location,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy('교실을 변경하는 중...', () async {
      await _repository.updateSessionLocation(
        sessionId: sessionId,
        location: location?.trim().isEmpty == true ? null : location?.trim(),
      );
      await _loadSessions();
      _setStatus('교실 변경 완료');
    });
  }

  Future<void> pickMediaFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError('파일 바이트를 읽지 못했습니다. 다시 시도하세요.');
    }

    pendingMediaFile = PendingMediaFile(
      name: file.name,
      mimeType: _guessMimeType(file.name),
      bytes: bytes,
    );

    _setStatus('선택 파일: ${file.name}');
    notifyListeners();
  }

  Future<void> clearPendingFile() async {
    pendingMediaFile = null;
    notifyListeners();
  }

  Future<void> uploadPendingMedia({
    required String title,
    required String description,
    required String childIdsCsv,
  }) async {
    if (!canUploadMedia || user == null) {
      throw StateError('업로드 권한이 없습니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    final file = pendingMediaFile;

    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    if (file == null) {
      throw StateError('업로드할 파일을 선택하세요.');
    }

    await _runBusy('업로드하는 중...', () async {
      final uploadResult = await _repository.uploadToStorage(
        homeschoolId: homeschoolId,
        file: file,
      );

      final mediaAssetId = await _repository.insertMediaAsset(
        homeschoolId: homeschoolId,
        uploadSessionId: null,
        uploaderUserId: user!.id,
        classGroupId: selectedClassGroupId,
        uploadResult: uploadResult,
        title: title.trim(),
        description: description.trim(),
        mediaType: file.isVideo ? 'VIDEO' : 'PHOTO',
      );

      final childIds = _parseCommaIds(childIdsCsv);
      await _repository.insertMediaChildren(
        mediaAssetId: mediaAssetId,
        childIds: childIds,
      );

      pendingMediaFile = null;
      await loadGalleryItems();
      _setStatus('업로드 완료');
    });
  }


  Future<void> loadHomeschoolContext() async {
    if (user == null) {
      _clearDomainState();
      notifyListeners();
      return;
    }

    await _fetchFreshAndCache();
  }

  /// Fetches all data from API and persists to cache afterwards.
  Future<void> _fetchFreshAndCache() async {
    if (user == null) return;

    try {
      await loadPendingInvites();
      memberships = await _repository.fetchMemberships(userId: user!.id);
    } catch (_) {
      // Network failure — if cached data exists, keep it and bail out.
      if (memberships.isNotEmpty) {
        _setStatus('네트워크에 연결할 수 없습니다. 캐시된 데이터를 사용합니다.');
        notifyListeners();
        return;
      }
      rethrow;
    }

    if (memberships.isEmpty) {
      selectedHomeschoolId = null;
      currentRole = null;
      _viewRoleByHomeschool.clear();
      _parentViewTargetByHomeschool.clear();
      _teacherViewTargetByHomeschool.clear();
      terms = [];
      classGroups = [];
      courses = [];
      classrooms = [];
      timeSlots = [];
      sessions = [];
      proposals = [];
      proposalSessionsById = const {};
      scheduleOptionDrafts = [];
      selectedScheduleOptionId = null;
      galleryItems = [];
      mediaChildrenByAsset = const {};
      communityPosts = [];
      communityMediaByPost = const {};
      communityCommentsByPost = const {};
      communityLikeCountsByPost = const {};
      likedCommunityPostIds = <String>{};
      communityReports = [];
      homeschoolMemberships = [];
      homeschoolInvites = [];
      homeschoolMemberDirectory = [];
      families = [];
      children = [];
      classEnrollments = [];
      familyGuardianUserIdsByFamily = const {};
      teacherProfiles = [];
      memberUnavailabilityBlocks = [];
      sessionTeacherAssignments = [];
      teachingPlans = [];
      studentActivityLogs = [];
      announcements = [];
      auditLogs = [];
      pendingCommunityMediaFile = null;

      if (pendingInvites.isNotEmpty) {
        _setStatus(
          '소속 홈스쿨이 없습니다. 대시보드에서 대기 초대 ${pendingInvites.length}건을 확인하세요.',
        );
      } else {
        _setStatus('소속 홈스쿨이 없습니다. 대시보드에서 초기 세팅을 진행하세요.');
      }
      notifyListeners();
      return;
    }

    final validSchoolIds = memberships
        .map((membership) => membership.homeschoolId)
        .toSet();
    if (selectedHomeschoolId == null ||
        !validSchoolIds.contains(selectedHomeschoolId)) {
      selectedHomeschoolId = memberships.first.homeschoolId;
    }

    currentRole = _resolveViewRole(selectedHomeschoolId);

    try {
      await _loadTermAndBelow();
      await Future.wait([
        loadHomeschoolMemberships(),
        loadHomeschoolInvites(),
        loadJoinRequests(),
        loadChildRegistrationRequests(),
        _loadOperationalData(),
        loadGalleryItems(),
        loadCommunityFeed(),
        loadAcademicEvents(),
      ]);
      _ensureRoleViewTargetSelection();

      _setStatus('운영 컨텍스트 로드 완료');
    } catch (_) {
      _setStatus('일부 데이터를 불러오지 못했습니다. 캐시된 데이터를 사용합니다.');
    }

    notifyListeners();
    unawaited(_persistToCache());
  }

  String? mediaPublicUrl(String? storagePath) {
    if (storagePath == null || storagePath.isEmpty) return null;
    return _repository.mediaPublicUrl(storagePath);
  }

  Future<void> loadGalleryItems() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      galleryItems = [];
      mediaChildrenByAsset = const {};
      _notifyIfIdle();
      return;
    }

    galleryItems = await _repository.fetchGalleryItems(
      homeschoolId: homeschoolId,
      classGroupId: selectedClassGroupId,
    );

    mediaChildrenByAsset = await _repository.fetchMediaChildrenByAsset(
      mediaAssetIds: galleryItems
          .map((item) => item.id)
          .toList(),
    );

    _notifyIfIdle();
  }

  Future<void> loadHomeschoolMemberships() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      homeschoolMemberships = [];
      _notifyIfIdle();
      return;
    }

    homeschoolMemberships = await _repository.fetchHomeschoolMemberships(
      homeschoolId: homeschoolId,
    );
    _notifyIfIdle();
  }

  Future<void> loadHomeschoolInvites() async {
    if (!canManageMemberships) {
      homeschoolInvites = [];
      _notifyIfIdle();
      return;
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      homeschoolInvites = [];
      _notifyIfIdle();
      return;
    }

    homeschoolInvites = await _repository.fetchHomeschoolInvites(
      homeschoolId: homeschoolId,
    );
    _notifyIfIdle();
  }

  Future<void> loadJoinRequests() async {
    if (!canManageMemberships) {
      joinRequests = [];
      _notifyIfIdle();
      return;
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      joinRequests = [];
      _notifyIfIdle();
      return;
    }

    joinRequests = await _repository.fetchJoinRequests(
      homeschoolId: homeschoolId,
    );
    _notifyIfIdle();
  }

  Future<void> approveJoinRequest({
    required String requestId,
    required String requesterUserId,
    String role = 'PARENT',
  }) async {
    if (!canManageMemberships) {
      throw StateError('홈스쿨 관리자 권한이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final currentUserId = user?.id;
    if (currentUserId == null) {
      throw StateError('로그인이 필요합니다.');
    }

    await _runBusy('가입 요청을 승인하는 중...', () async {
      await _repository.updateJoinRequestStatus(
        requestId: requestId,
        status: 'APPROVED',
        reviewedByUserId: currentUserId,
      );
      await _repository.grantMembershipRole(
        homeschoolId: homeschoolId,
        userId: requesterUserId,
        role: role,
      );
      await Future.wait([
        loadJoinRequests(),
        loadHomeschoolMemberships(),
        loadHomeschoolMemberDirectory(),
      ]);
      _setStatus('가입 요청을 승인했습니다.');
    });
  }

  Future<void> rejectJoinRequest({
    required String requestId,
  }) async {
    if (!canManageMemberships) {
      throw StateError('홈스쿨 관리자 권한이 필요합니다.');
    }

    final currentUserId = user?.id;
    if (currentUserId == null) {
      throw StateError('로그인이 필요합니다.');
    }

    await _runBusy('가입 요청을 거절하는 중...', () async {
      await _repository.updateJoinRequestStatus(
        requestId: requestId,
        status: 'REJECTED',
        reviewedByUserId: currentUserId,
      );
      await loadJoinRequests();
      _setStatus('가입 요청을 거절했습니다.');
    });
  }

  Future<void> loadHomeschoolMemberDirectory({
    String query = '',
    int limit = 120,
  }) async {
    if (!canManageTeacherAssignments) {
      homeschoolMemberDirectory = [];
      _notifyIfIdle();
      return;
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      homeschoolMemberDirectory = [];
      _notifyIfIdle();
      return;
    }

    homeschoolMemberDirectory = await _repository.searchHomeschoolMembers(
      homeschoolId: homeschoolId,
      query: query,
      limit: limit,
    );
    _notifyIfIdle();
  }

  Future<void> loadPendingInvites() async {
    final currentUser = user;
    if (currentUser == null) {
      pendingInvites = [];
      notifyListeners();
      return;
    }

    final email = _normalizeNullable(currentUser.email);
    if (email == null) {
      pendingInvites = [];
      notifyListeners();
      return;
    }

    pendingInvites = await _repository.fetchPendingInvitesForEmail(
      email: email,
    );
    notifyListeners();
  }

  Future<void> loadFamilies() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      families = [];
      familyGuardianUserIdsByFamily = const {};
      _notifyIfIdle();
      return;
    }

    families = await _repository.fetchFamilies(homeschoolId: homeschoolId);
    _notifyIfIdle();
  }

  Future<void> loadFamilyGuardians() async {
    if (families.isEmpty) {
      familyGuardianUserIdsByFamily = const {};
      _notifyIfIdle();
      return;
    }

    final familyIds = families
        .map((family) => family.id)
        .where((id) => id.isNotEmpty)
        .toList();

    familyGuardianUserIdsByFamily = await _repository
        .fetchFamilyGuardianUserIds(familyIds: familyIds);
    _notifyIfIdle();
  }

  Future<void> loadChildren() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      children = [];
      _notifyIfIdle();
      return;
    }

    children = await _repository.fetchChildren(homeschoolId: homeschoolId);
    _notifyIfIdle();
  }

  Future<void> loadClassEnrollments() async {
    final classGroupIds = classGroups
        .map((group) => group.id)
        .where((id) => id.isNotEmpty)
        .toList();

    classEnrollments = await _repository.fetchClassEnrollments(
      classGroupIds: classGroupIds,
    );
    _notifyIfIdle();
  }

  Future<void> loadTeacherProfiles() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      teacherProfiles = [];
      _notifyIfIdle();
      return;
    }

    teacherProfiles = await _repository.fetchTeacherProfiles(
      homeschoolId: homeschoolId,
    );
    _notifyIfIdle();
  }

  Future<void> loadMemberUnavailabilityBlocks() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      memberUnavailabilityBlocks = [];
      _notifyIfIdle();
      return;
    }

    memberUnavailabilityBlocks = await _repository
        .fetchMemberUnavailabilityBlocks(homeschoolId: homeschoolId);
    _notifyIfIdle();
  }

  Future<void> loadSessionTeacherAssignments() async {
    final sessionIds = sessions
        .map((session) => session.id)
        .where((id) => id.isNotEmpty)
        .toList();

    sessionTeacherAssignments = await _repository
        .fetchSessionTeacherAssignments(classSessionIds: sessionIds);
    _notifyIfIdle();
  }

  Future<void> loadTeachingPlans() async {
    final sessionIds = sessions
        .map((session) => session.id)
        .where((id) => id.isNotEmpty)
        .toList();

    teachingPlans = await _repository.fetchTeachingPlans(
      classSessionIds: sessionIds,
    );
    _notifyIfIdle();
  }

  Future<void> loadStudentActivityLogs() async {
    final childIds = children
        .map((child) => child.id)
        .where((id) => id.isNotEmpty)
        .toList();

    studentActivityLogs = await _repository.fetchStudentActivityLogs(
      childIds: childIds,
    );
    _notifyIfIdle();
  }

  Future<void> loadAnnouncements() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      announcements = [];
      _notifyIfIdle();
      return;
    }

    final rows = await _repository.fetchAnnouncements(
      homeschoolId: homeschoolId,
    );
    final selectedClassId = selectedClassGroupId;

    announcements = selectedClassId == null
        ? rows
        : rows
              .where(
                (row) =>
                    row.classGroupId == null ||
                    row.classGroupId == selectedClassId,
              )
              .toList();

    _notifyIfIdle();
  }

  // ── Academic Events (학사 일정) ──

  Future<void> loadAcademicEvents() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      academicEvents = [];
      _notifyIfIdle();
      return;
    }
    academicEvents = await _repository.fetchAcademicEvents(
      homeschoolId: homeschoolId,
      termId: selectedTermId,
    );
    _notifyIfIdle();
  }

  Future<void> createAcademicEvent({
    required String title,
    required String description,
    required String eventDate,
    String? endDate,
  }) async {
    final homeschoolId = selectedHomeschoolId;
    final userId = user?.id;
    if (homeschoolId == null || userId == null) {
      throw StateError('홈스쿨/사용자 정보가 없습니다.');
    }
    await _repository.createAcademicEvent(
      homeschoolId: homeschoolId,
      termId: selectedTermId,
      title: title,
      description: description,
      eventDate: eventDate,
      endDate: endDate,
      createdByUserId: userId,
    );
    _setStatus('학사 일정이 추가되었습니다.');
    await loadAcademicEvents();
  }

  Future<void> deleteAcademicEvent({required String eventId}) async {
    await _repository.deleteAcademicEvent(eventId: eventId);
    _setStatus('학사 일정이 삭제되었습니다.');
    await loadAcademicEvents();
  }

  Future<void> loadAuditLogs() async {
    if (!isAdminLike) {
      auditLogs = [];
      _notifyIfIdle();
      return;
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      auditLogs = [];
      _notifyIfIdle();
      return;
    }

    auditLogs = await _repository.fetchAuditLogs(homeschoolId: homeschoolId);
    _notifyIfIdle();
  }

  Future<void> _loadOperationalData() async {
    // Phase 1 – independent loads (families & children needed by phase 2).
    await Future.wait([
      loadHomeschoolMemberDirectory(),
      loadFamilies(),
      loadChildren(),
      loadClassEnrollments(),
      loadTeacherProfiles(),
      loadMemberUnavailabilityBlocks(),
      loadSessionTeacherAssignments(),
      loadTeachingPlans(),
      loadAnnouncements(),
      loadAuditLogs(),
    ]);
    // Phase 2 – depend on families / children loaded above.
    await Future.wait([
      loadFamilyGuardians(),
      loadStudentActivityLogs(),
    ]);
  }

  Future<void> loadCommunityFeed() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      communityPosts = [];
      communityMediaByPost = const {};
      communityCommentsByPost = const {};
      communityLikeCountsByPost = const {};
      likedCommunityPostIds = <String>{};
      communityReports = [];
      pendingCommunityMediaFile = null;
      _notifyIfIdle();
      return;
    }

    final postRows = await _repository.fetchCommunityPosts(
      homeschoolId: homeschoolId,
    );

    final selectedClassId = selectedClassGroupId;
    final filteredPosts = selectedClassId == null
        ? postRows
        : postRows
              .where(
                (post) =>
                    post.classGroupId == null ||
                    post.classGroupId == selectedClassId,
              )
              .toList();

    final postIds = filteredPosts
        .map((post) => post.id)
        .toList();

    communityPosts = filteredPosts;

    // Fire all independent queries in parallel.
    final mediaFuture = _repository.fetchCommunityMediaByPost(postIds: postIds);
    final commentsFuture = _repository.fetchCommunityCommentsByPost(
      postIds: postIds,
    );
    final reactionsFuture = user != null
        ? _repository.fetchCommunityReactions(
            postIds: postIds,
            currentUserId: user!.id,
          )
        : null;
    final reportsFuture = canModerateCommunity
        ? _repository.fetchCommunityReports(homeschoolId: homeschoolId)
        : null;

    communityMediaByPost = await mediaFuture;
    communityCommentsByPost = await commentsFuture;

    if (reactionsFuture != null) {
      final reactionSnapshot = await reactionsFuture;
      communityLikeCountsByPost = reactionSnapshot.likeCountsByPostId;
      likedCommunityPostIds = reactionSnapshot.likedPostIds;
    } else {
      communityLikeCountsByPost = const {};
      likedCommunityPostIds = <String>{};
    }

    communityReports = reportsFuture != null
        ? await reportsFuture
        : const [];

    _notifyIfIdle();
  }

  Future<void> pickCommunityMediaFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw StateError('파일 바이트를 읽지 못했습니다. 다시 시도하세요.');
    }

    pendingCommunityMediaFile = PendingMediaFile(
      name: file.name,
      mimeType: _guessMimeType(file.name),
      bytes: bytes,
    );

    _setStatus('커뮤니티 첨부 파일 선택: ${file.name}');
    notifyListeners();
  }

  Future<void> clearPendingCommunityFile() async {
    pendingCommunityMediaFile = null;
    notifyListeners();
  }

  Future<void> publishCommunityPost({
    required String content,
    String? classGroupId,
  }) async {
    if (!canWriteCommunity || user == null) {
      throw StateError('커뮤니티 작성 권한이 없습니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final trimmedContent = content.trim();
    final pendingFile = pendingCommunityMediaFile;
    if (trimmedContent.isEmpty && pendingFile == null) {
      throw StateError('게시글 내용 또는 첨부 파일을 입력하세요.');
    }

    final authorName = _authorDisplayName(user!);
    final targetClassGroupId =
        _normalizeNullable(classGroupId) ?? selectedClassGroupId;

    await _runBusy('커뮤니티 게시글 업로드 중...', () async {
      final postId = await _repository.insertCommunityPost(
        homeschoolId: homeschoolId,
        classGroupId: targetClassGroupId,
        authorUserId: user!.id,
        authorDisplayName: authorName,
        content: trimmedContent.isEmpty ? '(사진/영상 공유)' : trimmedContent,
      );

      if (pendingFile != null) {
        final uploadResult = await _repository.uploadToStorage(
          homeschoolId: homeschoolId,
          file: pendingFile,
        );

        final mediaAssetId = await _repository.insertMediaAsset(
          homeschoolId: homeschoolId,
          uploadSessionId: null,
          uploaderUserId: user!.id,
          classGroupId: targetClassGroupId,
          uploadResult: uploadResult,
          title: pendingFile.name,
          description: trimmedContent,
          mediaType: pendingFile.isVideo ? 'VIDEO' : 'PHOTO',
        );

        await _repository.linkCommunityPostMedia(
          postId: postId,
          mediaAssetId: mediaAssetId,
        );
      }

      pendingCommunityMediaFile = null;
      await loadGalleryItems();
      await loadCommunityFeed();
      _setStatus('커뮤니티 게시글이 등록되었습니다.');
    });
  }

  Future<void> toggleCommunityLike(String postId) async {
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final currentlyLiked = likedCommunityPostIds.contains(postId);

    await _runBusy('좋아요 반영 중...', () async {
      if (currentlyLiked) {
        await _repository.removeCommunityLike(postId: postId, userId: user!.id);
      } else {
        await _repository.upsertCommunityLike(postId: postId, userId: user!.id);
      }

      final nextLiked = Set<String>.from(likedCommunityPostIds);
      final nextCounts = Map<String, int>.from(communityLikeCountsByPost);

      if (currentlyLiked) {
        nextLiked.remove(postId);
        final currentCount = nextCounts[postId] ?? 0;
        nextCounts[postId] = currentCount > 0 ? currentCount - 1 : 0;
      } else {
        nextLiked.add(postId);
        nextCounts[postId] = (nextCounts[postId] ?? 0) + 1;
      }

      likedCommunityPostIds = nextLiked;
      communityLikeCountsByPost = nextCounts;
      _setStatus(currentlyLiked ? '좋아요를 취소했습니다.' : '좋아요를 눌렀습니다.');
    });
  }

  Future<void> addCommunityComment({
    required String postId,
    required String content,
  }) async {
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      throw StateError('댓글 내용을 입력하세요.');
    }

    await _runBusy('댓글 등록 중...', () async {
      await _repository.addCommunityComment(
        postId: postId,
        authorUserId: user!.id,
        authorDisplayName: _authorDisplayName(user!),
        content: trimmed,
      );

      final comments = List<CommunityComment>.from(
        communityCommentsByPost[postId] ?? const [],
      );
      comments.add(
        CommunityComment(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          postId: postId,
          authorUserId: user!.id,
          authorDisplayName: _authorDisplayName(user!),
          content: trimmed,
          createdAt: DateTime.now().toUtc(),
        ),
      );

      communityCommentsByPost = Map<String, List<CommunityComment>>.from(
        communityCommentsByPost,
      )..[postId] = comments;

      _setStatus('댓글을 등록했습니다.');
    });
  }

  Future<void> reportCommunityPost({
    required String postId,
    required String reasonCategory,
    required String reasonDetail,
  }) async {
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    await _runBusy('신고를 등록하는 중...', () async {
      await _repository.createCommunityReport(
        postId: postId,
        homeschoolId: homeschoolId,
        reporterUserId: user!.id,
        reporterDisplayName: _authorDisplayName(user!),
        reasonCategory: reasonCategory,
        reasonDetail: reasonDetail,
      );

      await loadCommunityFeed();
      _setStatus('신고를 접수했습니다.');
    });
  }

  Future<void> setCommunityReportStatus({
    required String reportId,
    required String status,
  }) async {
    if (!canModerateCommunity || user == null) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy('신고 상태를 반영하는 중...', () async {
      await _repository.setCommunityReportStatus(
        reportId: reportId,
        status: status,
        handledByUserId: user!.id,
      );
      await loadCommunityFeed();
      await _logAudit(
        actionType: 'COMMUNITY_REPORT_STATUS',
        resourceType: 'community_reports',
        resourceId: reportId,
        afterJson: {'status': status},
      );
      _setStatus('신고 상태를 업데이트했습니다.');
    });
  }

  Future<void> setCommunityPostHidden({
    required String postId,
    required bool hidden,
  }) async {
    if (!canModerateCommunity || user == null) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy(hidden ? '게시글을 숨기는 중...' : '게시글 숨김을 해제하는 중...', () async {
      await _repository.setCommunityPostHidden(
        postId: postId,
        hidden: hidden,
        handledByUserId: user!.id,
      );
      await loadCommunityFeed();
      _setStatus(hidden ? '게시글을 숨김 처리했습니다.' : '게시글 숨김을 해제했습니다.');
    });
  }

  Future<void> setCommunityPostPinned({
    required String postId,
    required bool pinned,
  }) async {
    if (!canModerateCommunity) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy(
      pinned ? '게시글을 상단 고정하는 중...' : '게시글 고정을 해제하는 중...',
      () async {
        await _repository.setCommunityPostPinned(
          postId: postId,
          pinned: pinned,
        );
        await loadCommunityFeed();
        _setStatus(pinned ? '게시글을 고정했습니다.' : '게시글 고정을 해제했습니다.');
      },
    );
  }

  Future<void> deleteCommunityPost(String postId) async {
    if (!canModerateCommunity) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy('게시글을 삭제하는 중...', () async {
      await _repository.deleteCommunityPost(postId: postId);
      await loadCommunityFeed();
      _setStatus('게시글을 삭제했습니다.');
    });
  }

  Future<void> createClassGroup({
    required String name,
    required int capacity,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      throw StateError('학기를 먼저 선택하세요.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('반 이름을 입력하세요.');
    }
    if (capacity < 1 || capacity > 200) {
      throw StateError('정원은 1~200 사이로 입력하세요.');
    }

    await _runBusy('반을 생성하는 중...', () async {
      final created = await _repository.createClassGroup(
        termId: termId,
        name: trimmedName,
        capacity: capacity,
      );
      selectedClassGroupId = created.id;
      await _loadClassGroups();
      await _loadSessions();
      await _loadProposals();
      await loadClassEnrollments();
      await loadSessionTeacherAssignments();
      await loadTeachingPlans();
      await loadAnnouncements();
      await loadGalleryItems();
      await loadCommunityFeed();
      await _logAudit(
        actionType: 'CLASS_GROUP_CREATE',
        resourceType: 'class_groups',
        resourceId: created.id,
        afterJson: {'name': created.name, 'capacity': created.capacity},
      );
      _setStatus('반을 생성했습니다.');
    });
  }

  Future<void> updateClassGroup({
    required String classGroupId,
    required String name,
    required int capacity,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(classGroupId);
    if (normalizedId == null) {
      throw StateError('수정할 반을 선택하세요.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('반 이름을 입력하세요.');
    }
    if (capacity < 1 || capacity > 200) {
      throw StateError('정원은 1~200 사이로 입력하세요.');
    }

    await _runBusy('반 정보를 수정하는 중...', () async {
      final updated = await _repository.updateClassGroup(
        classGroupId: normalizedId,
        name: trimmedName,
        capacity: capacity,
      );
      await _loadClassGroups();
      await _loadSessions();
      await loadClassEnrollments();
      await loadAnnouncements();
      await loadGalleryItems();
      await loadCommunityFeed();
      await _logAudit(
        actionType: 'CLASS_GROUP_UPDATE',
        resourceType: 'class_groups',
        resourceId: normalizedId,
        afterJson: {'name': updated.name, 'capacity': updated.capacity},
      );
      _setStatus('반 정보를 수정했습니다.');
    });
  }

  Future<void> deleteClassGroup({required String classGroupId}) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(classGroupId);
    if (normalizedId == null) {
      throw StateError('삭제할 반을 선택하세요.');
    }

    await _runBusy('반을 삭제하는 중...', () async {
      await _repository.deleteClassGroup(classGroupId: normalizedId);
      await _loadClassGroups();
      await _loadSessions();
      await _loadProposals();
      await loadClassEnrollments();
      await loadSessionTeacherAssignments();
      await loadTeachingPlans();
      await loadAnnouncements();
      await loadGalleryItems();
      await loadCommunityFeed();
      await _logAudit(
        actionType: 'CLASS_GROUP_DELETE',
        resourceType: 'class_groups',
        resourceId: normalizedId,
      );
      _setStatus('반을 삭제했습니다.');
    });
  }

  Future<void> createCourse({
    required String name,
    required int defaultDurationMin,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('과목 이름을 입력하세요.');
    }
    if (courses.any(
      (c) => c.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    )) {
      throw StateError('이미 동일한 이름의 과목이 있습니다: $trimmedName');
    }
    if (defaultDurationMin < 20 || defaultDurationMin > 300) {
      throw StateError('기본 수업 시간은 20~300분 사이여야 합니다.');
    }

    await _runBusy('과목을 생성하는 중...', () async {
      final created = await _repository.createCourse(
        homeschoolId: homeschoolId,
        name: trimmedName,
        defaultDurationMin: defaultDurationMin,
      );
      await _loadTimetableAssets();
      await _logAudit(
        actionType: 'COURSE_CREATE',
        resourceType: 'courses',
        resourceId: created.id,
        afterJson: {
          'name': created.name,
          'default_duration_min': created.defaultDurationMin,
        },
      );
      _setStatus('과목을 생성했습니다.');
    });
  }

  Future<void> updateCourse({
    required String courseId,
    required String name,
    required int defaultDurationMin,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(courseId);
    if (normalizedId == null) {
      throw StateError('수정할 과목을 선택하세요.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('과목 이름을 입력하세요.');
    }
    if (courses.any(
      (c) =>
          c.id != normalizedId &&
          c.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    )) {
      throw StateError('이미 동일한 이름의 과목이 있습니다: $trimmedName');
    }
    if (defaultDurationMin < 20 || defaultDurationMin > 300) {
      throw StateError('기본 수업 시간은 20~300분 사이여야 합니다.');
    }

    await _runBusy('과목 정보를 수정하는 중...', () async {
      final updated = await _repository.updateCourse(
        courseId: normalizedId,
        name: trimmedName,
        defaultDurationMin: defaultDurationMin,
      );
      await _loadTimetableAssets();
      await _logAudit(
        actionType: 'COURSE_UPDATE',
        resourceType: 'courses',
        resourceId: normalizedId,
        afterJson: {
          'name': updated.name,
          'default_duration_min': updated.defaultDurationMin,
        },
      );
      _setStatus('과목 정보를 수정했습니다.');
    });
  }

  Future<void> deleteCourse({required String courseId}) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(courseId);
    if (normalizedId == null) {
      throw StateError('삭제할 과목을 선택하세요.');
    }
    if (sessions.any((session) => session.courseId == normalizedId)) {
      throw StateError('현재 반 시간표에서 사용 중인 과목은 삭제할 수 없습니다.');
    }

    await _runBusy('과목을 삭제하는 중...', () async {
      await _repository.deleteCourse(courseId: normalizedId);
      await _loadTimetableAssets();
      await _logAudit(
        actionType: 'COURSE_DELETE',
        resourceType: 'courses',
        resourceId: normalizedId,
      );
      _setStatus('과목을 삭제했습니다.');
    });
  }

  Future<void> createClassroom({
    required String name,
    required int capacity,
    required String note,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      throw StateError('학기를 먼저 선택하세요.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('교실 이름을 입력하세요.');
    }
    if (classrooms.any(
      (c) => c.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    )) {
      throw StateError('이미 동일한 이름의 교실이 있습니다: $trimmedName');
    }
    if (capacity < 1 || capacity > 300) {
      throw StateError('교실 수용 인원은 1~300 사이여야 합니다.');
    }

    await _runBusy('교실을 생성하는 중...', () async {
      final created = await _repository.createClassroom(
        termId: termId,
        name: trimmedName,
        capacity: capacity,
        note: note,
      );
      await _loadTimetableAssets();
      await _logAudit(
        actionType: 'CLASSROOM_CREATE',
        resourceType: 'classrooms',
        resourceId: created.id,
        afterJson: {
          'name': created.name,
          'capacity': created.capacity,
          'note': created.note,
        },
      );
      _setStatus('교실을 생성했습니다.');
    });
  }

  Future<void> updateClassroom({
    required String classroomId,
    required String name,
    required int capacity,
    required String note,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(classroomId);
    if (normalizedId == null) {
      throw StateError('수정할 교실을 선택하세요.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('교실 이름을 입력하세요.');
    }
    if (classrooms.any(
      (c) =>
          c.id != normalizedId &&
          c.name.trim().toLowerCase() == trimmedName.toLowerCase(),
    )) {
      throw StateError('이미 동일한 이름의 교실이 있습니다: $trimmedName');
    }
    if (capacity < 1 || capacity > 300) {
      throw StateError('교실 수용 인원은 1~300 사이여야 합니다.');
    }

    await _runBusy('교실 정보를 수정하는 중...', () async {
      final updated = await _repository.updateClassroom(
        classroomId: normalizedId,
        name: trimmedName,
        capacity: capacity,
        note: note,
      );
      await _loadTimetableAssets();
      await _logAudit(
        actionType: 'CLASSROOM_UPDATE',
        resourceType: 'classrooms',
        resourceId: normalizedId,
        afterJson: {
          'name': updated.name,
          'capacity': updated.capacity,
          'note': updated.note,
        },
      );
      _setStatus('교실 정보를 수정했습니다.');
    });
  }

  Future<void> deleteClassroom({required String classroomId}) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(classroomId);
    if (normalizedId == null) {
      throw StateError('삭제할 교실을 선택하세요.');
    }

    final target = classrooms
        .where((room) => room.id == normalizedId)
        .toList()
        .firstOrNull;
    if (target != null) {
      final roomName = target.name.trim();
      if (roomName.isNotEmpty &&
          allTermSessions.any(
            (session) => (session.location ?? '').trim() == roomName,
          )) {
        throw StateError('현재 시간표에서 사용 중인 교실은 삭제할 수 없습니다.');
      }
    }

    await _runBusy('교실을 삭제하는 중...', () async {
      await _repository.deleteClassroom(classroomId: normalizedId);
      await _loadTimetableAssets();
      await _logAudit(
        actionType: 'CLASSROOM_DELETE',
        resourceType: 'classrooms',
        resourceId: normalizedId,
      );
      _setStatus('교실을 삭제했습니다.');
    });
  }

  // ── Time Slot CRUD ──

  Future<void> createTimeSlot({
    required int dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      throw StateError('학기를 먼저 선택하세요.');
    }

    await _runBusy('교시를 추가하는 중...', () async {
      await _repository.createTimeSlot(
        termId: termId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
      );
      await _loadTimetableAssets();
      _setStatus('교시를 추가했습니다.');
    });
  }

  Future<void> updateTimeSlot({
    required String slotId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy('교시를 수정하는 중...', () async {
      await _repository.updateTimeSlot(
        slotId: slotId,
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
      );
      await _loadTimetableAssets();
      _setStatus('교시를 수정했습니다.');
    });
  }

  Future<void> deleteTimeSlot({required String slotId}) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final hasSession = allTermSessions.any(
      (session) => session.timeSlotId == slotId,
    );
    if (hasSession) {
      throw StateError('이 교시에 배정된 수업이 있어 삭제할 수 없습니다.');
    }

    await _runBusy('교시를 삭제하는 중...', () async {
      await _repository.deleteTimeSlot(slotId: slotId);
      await _loadTimetableAssets();
      _setStatus('교시를 삭제했습니다.');
    });
  }

  /// Delete a period (all time slots with the same start/end time) across all days.
  Future<void> deletePeriod({
    required String startTime,
    required String endTime,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      throw StateError('학기를 먼저 선택하세요.');
    }

    final affectedSlotIds = timeSlots
        .where((s) => s.startTime == startTime && s.endTime == endTime)
        .map((s) => s.id)
        .toSet();

    final hasSession = allTermSessions.any(
      (session) => affectedSlotIds.contains(session.timeSlotId),
    );
    if (hasSession) {
      throw StateError('이 교시에 배정된 수업이 있어 삭제할 수 없습니다.');
    }

    await _runBusy('교시를 삭제하는 중...', () async {
      await _repository.deleteTimeSlotsByTimeRange(
        termId: termId,
        startTime: startTime,
        endTime: endTime,
      );
      await _loadTimetableAssets();
      _setStatus('교시를 삭제했습니다.');
    });
  }

  /// Remove all time slots for a specific day of week.
  Future<void> removeDay({required int dayOfWeek}) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      throw StateError('학기를 먼저 선택하세요.');
    }

    final affectedSlotIds = timeSlots
        .where((s) => s.dayOfWeek == dayOfWeek)
        .map((s) => s.id)
        .toSet();

    final hasSession = allTermSessions.any(
      (session) => affectedSlotIds.contains(session.timeSlotId),
    );
    if (hasSession) {
      throw StateError('이 요일에 배정된 수업이 있어 삭제할 수 없습니다.');
    }

    await _runBusy('요일을 삭제하는 중...', () async {
      await _repository.deleteTimeSlotsByDay(
        termId: termId,
        dayOfWeek: dayOfWeek,
      );
      await _loadTimetableAssets();
      _setStatus('요일을 삭제했습니다.');
    });
  }

  /// Update a period's time range across all days.
  Future<void> updatePeriodTimes({
    required String oldStartTime,
    required String oldEndTime,
    required String newStartTime,
    required String newEndTime,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      throw StateError('학기를 먼저 선택하세요.');
    }

    await _runBusy('교시 시간을 수정하는 중...', () async {
      await _repository.updateTimeSlotTimeRange(
        termId: termId,
        oldStartTime: oldStartTime,
        oldEndTime: oldEndTime,
        newStartTime: newStartTime,
        newEndTime: newEndTime,
      );
      await _loadTimetableAssets();
      _setStatus('교시 시간을 수정했습니다.');
    });
  }

  /// Add all defined periods to a new day.
  Future<void> addDayWithPeriods({
    required int dayOfWeek,
    required List<(String startTime, String endTime)> periods,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      throw StateError('학기를 먼저 선택하세요.');
    }

    await _runBusy('요일을 추가하는 중...', () async {
      for (final period in periods) {
        await _repository.createTimeSlot(
          termId: termId,
          dayOfWeek: dayOfWeek,
          startTime: period.$1,
          endTime: period.$2,
        );
      }
      await _loadTimetableAssets();
      _setStatus('${_dayOfWeekLabel(dayOfWeek)}요일을 추가했습니다.');
    });
  }

  /// Add a new period to all active days.
  Future<void> addPeriodToAllDays({
    required String startTime,
    required String endTime,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      throw StateError('학기를 먼저 선택하세요.');
    }

    final activeDays = timeSlots.map((s) => s.dayOfWeek).toSet();
    if (activeDays.isEmpty) {
      // No days yet, create for weekdays by default
      activeDays.addAll([1, 2, 3, 4, 5]);
    }

    await _runBusy('교시를 추가하는 중...', () async {
      for (final day in activeDays) {
        await _repository.createTimeSlot(
          termId: termId,
          dayOfWeek: day,
          startTime: startTime,
          endTime: endTime,
        );
      }
      await _loadTimetableAssets();
      _setStatus('교시를 추가했습니다.');
    });
  }

  static String _dayOfWeekLabel(int day) {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    return (day >= 0 && day < labels.length) ? labels[day] : '?';
  }

  /// Regenerate all time slots from simple parameters.
  /// Deletes existing slots and creates new ones based on start/end times,
  /// slot duration, break duration, and active days.
  Future<void> regenerateTimeSlots({
    required String dayStartTime,
    required String dayEndTime,
    required int slotDurationMinutes,
    required int breakDurationMinutes,
    required Set<int> activeDays,
  }) async {
    if (!isAdminLike) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      throw StateError('학기를 먼저 선택하세요.');
    }

    if (slotDurationMinutes <= 0) {
      throw StateError('교시 길이는 1분 이상이어야 합니다.');
    }

    // Parse start/end times
    final startParts = dayStartTime.split(':');
    final endParts = dayEndTime.split(':');
    if (startParts.length < 2 || endParts.length < 2) {
      throw StateError('시간 형식이 올바르지 않습니다 (HH:MM).');
    }

    var startMinutes =
        int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

    if (startMinutes >= endMinutes) {
      throw StateError('종료 시간이 시작 시간보다 커야 합니다.');
    }

    // Generate period time ranges
    final periods = <(String, String)>[];
    while (startMinutes + slotDurationMinutes <= endMinutes) {
      final slotEnd = startMinutes + slotDurationMinutes;
      final startStr =
          '${(startMinutes ~/ 60).toString().padLeft(2, '0')}:${(startMinutes % 60).toString().padLeft(2, '0')}';
      final endStr =
          '${(slotEnd ~/ 60).toString().padLeft(2, '0')}:${(slotEnd % 60).toString().padLeft(2, '0')}';
      periods.add((startStr, endStr));
      startMinutes = slotEnd + breakDurationMinutes;
    }

    if (periods.isEmpty) {
      throw StateError('설정한 시간 범위에 교시를 생성할 수 없습니다.');
    }

    // Check for sessions on slots that will be deleted
    final existingSlotIds = timeSlots.map((s) => s.id).toSet();
    if (existingSlotIds.isNotEmpty) {
      final hasSession = allTermSessions.any(
        (session) => existingSlotIds.contains(session.timeSlotId),
      );
      if (hasSession) {
        throw StateError(
          '기존 교시에 배정된 수업이 있어 재설정할 수 없습니다. '
          '수업을 먼저 삭제해주세요.',
        );
      }
    }

    await _runBusy('교시를 재설정하는 중...', () async {
      // Delete all existing slots for this term
      for (final slot in timeSlots) {
        await _repository.deleteTimeSlot(slotId: slot.id);
      }

      // Create new slots for each active day × period
      for (final day in activeDays) {
        for (final period in periods) {
          await _repository.createTimeSlot(
            termId: termId,
            dayOfWeek: day,
            startTime: period.$1,
            endTime: period.$2,
          );
        }
      }

      await _loadTimetableAssets();
      _setStatus('교시를 재설정했습니다 (${periods.length}교시 × ${activeDays.length}요일).');
    });
  }

  Future<Family> createFamily({
    required String familyName,
    required String note,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final trimmedName = familyName.trim();
    if (trimmedName.isEmpty) {
      throw StateError('가정 이름을 입력하세요.');
    }
    if (families.any(
      (f) => f.familyName.trim().toLowerCase() == trimmedName.toLowerCase(),
    )) {
      throw StateError('이미 동일한 이름의 가정이 있습니다: $trimmedName');
    }

    late final Family created;
    await _runBusy('가정을 생성하는 중...', () async {
      created = await _repository.createFamily(
        homeschoolId: homeschoolId,
        familyName: trimmedName,
        note: note,
      );

      await loadFamilies();
      await loadFamilyGuardians();
      await _logAudit(
        actionType: 'FAMILY_CREATE',
        resourceType: 'families',
        resourceId: created.id,
        afterJson: {'family_name': created.familyName},
      );
      _setStatus('가정을 생성했습니다.');
    });
    return created;
  }

  Future<Family> updateFamily({
    required String familyId,
    required String familyName,
    required String note,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(familyId);
    if (normalizedId == null) {
      throw StateError('수정할 가정을 선택하세요.');
    }

    final trimmedName = familyName.trim();
    if (trimmedName.isEmpty) {
      throw StateError('가정 이름을 입력하세요.');
    }
    if (families.any(
      (f) =>
          f.id != normalizedId &&
          f.familyName.trim().toLowerCase() == trimmedName.toLowerCase(),
    )) {
      throw StateError('이미 동일한 이름의 가정이 있습니다: $trimmedName');
    }

    late final Family updated;
    await _runBusy('가정 정보를 수정하는 중...', () async {
      updated = await _repository.updateFamily(
        familyId: normalizedId,
        familyName: trimmedName,
        note: note,
      );
      await loadFamilies();
      await loadChildren();
      await _logAudit(
        actionType: 'FAMILY_UPDATE',
        resourceType: 'families',
        resourceId: updated.id,
        afterJson: {'family_name': updated.familyName, 'note': updated.note},
      );
      _setStatus('가정 정보를 수정했습니다.');
    });
    return updated;
  }

  Future<void> deleteFamily({required String familyId}) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(familyId);
    if (normalizedId == null) {
      throw StateError('삭제할 가정을 선택하세요.');
    }

    await _runBusy('가정을 삭제하는 중...', () async {
      await _repository.deleteFamily(familyId: normalizedId);
      await loadFamilies();
      await loadFamilyGuardians();
      await loadChildren();
      await loadClassEnrollments();
      await loadStudentActivityLogs();
      await _logAudit(
        actionType: 'FAMILY_DELETE',
        resourceType: 'families',
        resourceId: normalizedId,
      );
      _setStatus('가정을 삭제했습니다.');
    });
  }

  Future<void> upsertFamilyGuardian({
    required String familyId,
    required String userId,
    required String guardianType,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedFamilyId = _normalizeNullable(familyId);
    final normalizedUserId = _normalizeNullable(userId);
    if (normalizedFamilyId == null) {
      throw StateError('대상 가정을 선택하세요.');
    }
    if (normalizedUserId == null) {
      throw StateError('연결할 사용자 계정을 선택하세요.');
    }

    final normalizedType = guardianType.trim().toUpperCase();
    if (!const {'FATHER', 'MOTHER', 'GUARDIAN'}.contains(normalizedType)) {
      throw StateError('보호자 유형이 올바르지 않습니다.');
    }

    final hasParentRole = homeschoolMemberships.any(
      (row) =>
          row.userId == normalizedUserId &&
          row.role == 'PARENT' &&
          row.status == 'ACTIVE',
    );
    if (!hasParentRole) {
      throw StateError('해당 계정은 아직 PARENT 권한이 없습니다. 먼저 권한을 부여하세요.');
    }

    await _runBusy('가정에 학부모 계정을 연결하는 중...', () async {
      await _repository.upsertFamilyGuardian(
        familyId: normalizedFamilyId,
        userId: normalizedUserId,
        guardianType: normalizedType,
      );
      await loadFamilyGuardians();
      await _logAudit(
        actionType: 'FAMILY_GUARDIAN_UPSERT',
        resourceType: 'family_guardians',
        resourceId: '$normalizedFamilyId:$normalizedUserId',
        afterJson: {'guardian_type': normalizedType},
      );
      _setStatus('가정과 학부모 계정을 연결했습니다.');
    });
  }

  Future<void> deleteFamilyGuardian({
    required String familyId,
    required String userId,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedFamilyId = _normalizeNullable(familyId);
    final normalizedUserId = _normalizeNullable(userId);
    if (normalizedFamilyId == null || normalizedUserId == null) {
      throw StateError('해제할 가정/사용자 정보가 올바르지 않습니다.');
    }

    await _runBusy('가정 연결을 해제하는 중...', () async {
      await _repository.deleteFamilyGuardian(
        familyId: normalizedFamilyId,
        userId: normalizedUserId,
      );
      await loadFamilyGuardians();
      await _logAudit(
        actionType: 'FAMILY_GUARDIAN_DELETE',
        resourceType: 'family_guardians',
        resourceId: '$normalizedFamilyId:$normalizedUserId',
      );
      _setStatus('가정과 학부모 계정 연결을 해제했습니다.');
    });
  }

  Future<ChildProfile> createChild({
    required String familyId,
    required String name,
    required String birthDate,
    required String profileNote,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedFamilyId = _normalizeNullable(familyId);
    if (normalizedFamilyId == null) {
      throw StateError('소속 가정을 선택하세요.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('아이 이름을 입력하세요.');
    }
    if (DateTime.tryParse(birthDate.trim()) == null) {
      throw StateError('생년월일은 YYYY-MM-DD 형식으로 입력하세요.');
    }

    late final ChildProfile created;
    await _runBusy('아이 정보를 등록하는 중...', () async {
      created = await _repository.createChild(
        familyId: normalizedFamilyId,
        name: trimmedName,
        birthDate: birthDate.trim(),
        profileNote: profileNote,
      );
      await loadChildren();
      await loadStudentActivityLogs();
      await _logAudit(
        actionType: 'CHILD_CREATE',
        resourceType: 'children',
        resourceId: created.id,
        afterJson: {'name': created.name, 'family_id': created.familyId},
      );
      _setStatus('아이 정보를 등록했습니다.');
    });
    return created;
  }

  Future<void> requestChildRegistration({
    required String familyName,
    required String childName,
    String? birthDate,
    String guardianType = 'GUARDIAN',
  }) async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final currentUserId = user?.id;
    if (currentUserId == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final trimmedChild = childName.trim();
    if (trimmedChild.isEmpty) {
      throw StateError('아이 이름을 입력하세요.');
    }

    final trimmedFamily = familyName.trim();
    if (trimmedFamily.isEmpty) {
      throw StateError('가정 이름을 입력하세요.');
    }

    await _runBusy('아이 등록 요청을 보내는 중...', () async {
      await _repository.createChildRegistrationRequest(
        homeschoolId: homeschoolId,
        requesterUserId: currentUserId,
        familyName: trimmedFamily,
        childName: trimmedChild,
        birthDate: birthDate,
        guardianType: guardianType,
      );
      await loadChildRegistrationRequests();
      _setStatus('아이 등록 요청을 보냈습니다. 관리자 승인 후 등록됩니다.');
    });
  }

  Future<void> loadChildRegistrationRequests() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      childRegistrationRequests = [];
      _notifyIfIdle();
      return;
    }

    final rows = await _repository.fetchChildRegistrationRequests(
      homeschoolId: homeschoolId,
    );
    childRegistrationRequests = rows
        .map(ChildRegistrationRequest.fromMap)
        .toList();
    _notifyIfIdle();
  }

  Future<void> approveChildRegistration({
    required String requestId,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy('아이 등록 요청을 승인하는 중...', () async {
      await _repository.approveChildRegistration(requestId: requestId);
      await loadChildRegistrationRequests();
      await loadFamilies();
      await loadChildren();
      await loadFamilyGuardians();
      _setStatus('아이 등록 요청을 승인했습니다.');
    });
  }

  Future<void> rejectChildRegistration({
    required String requestId,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final currentUserId = user?.id;
    if (currentUserId == null) {
      throw StateError('로그인이 필요합니다.');
    }

    await _runBusy('아이 등록 요청을 거절하는 중...', () async {
      await _repository.rejectChildRegistration(
        requestId: requestId,
        reviewedByUserId: currentUserId,
      );
      await loadChildRegistrationRequests();
      _setStatus('아이 등록 요청을 거절했습니다.');
    });
  }

  Future<ChildProfile> updateChild({
    required String childId,
    required String familyId,
    required String name,
    required String birthDate,
    required String profileNote,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedChildId = _normalizeNullable(childId);
    if (normalizedChildId == null) {
      throw StateError('수정할 아이를 선택하세요.');
    }
    final normalizedFamilyId = _normalizeNullable(familyId);
    if (normalizedFamilyId == null) {
      throw StateError('소속 가정을 선택하세요.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('아이 이름을 입력하세요.');
    }
    if (DateTime.tryParse(birthDate.trim()) == null) {
      throw StateError('생년월일은 YYYY-MM-DD 형식으로 입력하세요.');
    }

    late final ChildProfile updated;
    await _runBusy('아이 정보를 수정하는 중...', () async {
      updated = await _repository.updateChild(
        childId: normalizedChildId,
        familyId: normalizedFamilyId,
        name: trimmedName,
        birthDate: birthDate.trim(),
        profileNote: profileNote,
      );
      await loadChildren();
      await _logAudit(
        actionType: 'CHILD_UPDATE',
        resourceType: 'children',
        resourceId: updated.id,
        afterJson: {
          'name': updated.name,
          'family_id': updated.familyId,
          'birth_date': birthDate.trim(),
        },
      );
      _setStatus('아이 정보를 수정했습니다.');
    });
    return updated;
  }

  Future<void> deleteChild({required String childId}) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(childId);
    if (normalizedId == null) {
      throw StateError('삭제할 아이를 선택하세요.');
    }

    await _runBusy('아이 정보를 삭제하는 중...', () async {
      await _repository.deleteChild(childId: normalizedId);
      await loadChildren();
      await loadClassEnrollments();
      await loadStudentActivityLogs();
      await _logAudit(
        actionType: 'CHILD_DELETE',
        resourceType: 'children',
        resourceId: normalizedId,
      );
      _setStatus('아이 정보를 삭제했습니다.');
    });
  }

  Future<void> assignChildToClass({
    required String classGroupId,
    required String childId,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy('반 배정을 추가하는 중...', () async {
      await _repository.upsertClassEnrollment(
        classGroupId: classGroupId,
        childId: childId,
      );
      await loadClassEnrollments();
      await _logAudit(
        actionType: 'CLASS_ENROLLMENT_ADD',
        resourceType: 'class_enrollments',
        resourceId: '$classGroupId:$childId',
      );
      _setStatus('반 배정을 추가했습니다.');
    });
  }

  Future<void> syncClassEnrollments({
    required String classGroupId,
    required Set<String> childIds,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedClassId = _normalizeNullable(classGroupId);
    if (normalizedClassId == null) {
      throw StateError('반을 선택하세요.');
    }

    final validChildIds = children
        .map((child) => child.id)
        .where((id) => id.isNotEmpty)
        .toSet();
    final desired = childIds
        .map((id) => _normalizeNullable(id))
        .whereType<String>()
        .where(validChildIds.contains)
        .toSet();
    final current = enrolledChildIdsForClassGroup(normalizedClassId).toSet();

    final toAdd = desired.difference(current);
    final toRemove = current.difference(desired);

    if (toAdd.isEmpty && toRemove.isEmpty) {
      _setStatus('반 배정 변경사항이 없습니다.');
      notifyListeners();
      return;
    }

    await _runBusy('반 배정을 저장하는 중...', () async {
      for (final childId in toAdd) {
        await _repository.upsertClassEnrollment(
          classGroupId: normalizedClassId,
          childId: childId,
        );
      }
      for (final childId in toRemove) {
        await _repository.deleteClassEnrollment(
          classGroupId: normalizedClassId,
          childId: childId,
        );
      }
      await loadClassEnrollments();
      await _logAudit(
        actionType: 'CLASS_ENROLLMENT_SYNC',
        resourceType: 'class_enrollments',
        resourceId: normalizedClassId,
        afterJson: {
          'added': toAdd.length,
          'removed': toRemove.length,
          'total': desired.length,
        },
      );
      _setStatus('반 배정을 저장했습니다.');
    });
  }

  Future<void> unassignChildFromClass({
    required String classGroupId,
    required String childId,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy('반 배정을 해제하는 중...', () async {
      await _repository.deleteClassEnrollment(
        classGroupId: classGroupId,
        childId: childId,
      );
      await loadClassEnrollments();
      await _logAudit(
        actionType: 'CLASS_ENROLLMENT_REMOVE',
        resourceType: 'class_enrollments',
        resourceId: '$classGroupId:$childId',
      );
      _setStatus('반 배정을 해제했습니다.');
    });
  }

  Future<TeacherProfile> createTeacherProfile({
    required String displayName,
    required String teacherType,
    String? userId,
  }) async {
    if (!canManageTeacherAssignments) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw StateError('교사 표시 이름을 입력하세요.');
    }

    late final TeacherProfile created;
    await _runBusy('교사 프로필을 생성하는 중...', () async {
      created = await _repository.createTeacherProfile(
        homeschoolId: homeschoolId,
        displayName: trimmedName,
        teacherType: teacherType,
        userId: _normalizeNullable(userId),
      );
      await loadTeacherProfiles();
      await _logAudit(
        actionType: 'TEACHER_PROFILE_CREATE',
        resourceType: 'teacher_profiles',
        resourceId: created.id,
        afterJson: {'display_name': created.displayName, 'type': teacherType},
      );
      _setStatus('교사 프로필을 생성했습니다.');
    });
    return created;
  }

  Future<TeacherProfile> updateTeacherProfile({
    required String teacherProfileId,
    required String displayName,
    required String teacherType,
    String? userId,
  }) async {
    if (!canManageTeacherAssignments) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(teacherProfileId);
    if (normalizedId == null) {
      throw StateError('수정할 교사 프로필을 선택하세요.');
    }

    final trimmedName = displayName.trim();
    if (trimmedName.isEmpty) {
      throw StateError('교사 표시 이름을 입력하세요.');
    }

    late final TeacherProfile updated;
    await _runBusy('교사 프로필을 수정하는 중...', () async {
      updated = await _repository.updateTeacherProfile(
        teacherProfileId: normalizedId,
        displayName: trimmedName,
        teacherType: teacherType,
        userId: _normalizeNullable(userId),
      );
      await loadTeacherProfiles();
      await _logAudit(
        actionType: 'TEACHER_PROFILE_UPDATE',
        resourceType: 'teacher_profiles',
        resourceId: updated.id,
        afterJson: {
          'display_name': updated.displayName,
          'type': updated.teacherType,
          'user_id': updated.userId,
        },
      );
      _setStatus('교사 프로필을 수정했습니다.');
    });
    return updated;
  }

  Future<void> deleteTeacherProfile({required String teacherProfileId}) async {
    if (!canManageTeacherAssignments) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(teacherProfileId);
    if (normalizedId == null) {
      throw StateError('삭제할 교사 프로필을 선택하세요.');
    }

    if (sessionTeacherAssignments.any(
      (row) => row.teacherProfileId == normalizedId,
    )) {
      throw StateError('현재 반 시간표에서 사용 중인 교사는 삭제할 수 없습니다.');
    }

    await _runBusy('교사 프로필을 삭제하는 중...', () async {
      await _repository.deleteTeacherProfile(teacherProfileId: normalizedId);
      await loadTeacherProfiles();
      await loadSessionTeacherAssignments();
      await loadTeachingPlans();
      await loadStudentActivityLogs();
      await _logAudit(
        actionType: 'TEACHER_PROFILE_DELETE',
        resourceType: 'teacher_profiles',
        resourceId: normalizedId,
      );
      _setStatus('교사 프로필을 삭제했습니다.');
    });
  }

  Future<void> createMemberUnavailabilityBlock({
    required String ownerKind,
    required String ownerId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required String note,
  }) async {
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final normalizedOwnerId = _normalizeNullable(ownerId);
    if (normalizedOwnerId == null) {
      throw StateError('대상 사용자를 선택하세요.');
    }
    if (dayOfWeek < 0 || dayOfWeek > 6) {
      throw StateError('요일 값이 유효하지 않습니다.');
    }

    final normalizedStart = _normalizeClockText(startTime);
    final normalizedEnd = _normalizeClockText(endTime);
    if (normalizedStart == null || normalizedEnd == null) {
      throw StateError('시간은 HH:MM 형식으로 입력하세요.');
    }
    if (!_isClockRangeValid(normalizedStart, normalizedEnd)) {
      throw StateError('종료 시간은 시작 시간보다 늦어야 합니다.');
    }

    final normalizedKind = ownerKind.trim();
    if (normalizedKind != 'TEACHER_PROFILE' &&
        normalizedKind != 'MEMBER_USER') {
      throw StateError('대상 유형이 유효하지 않습니다.');
    }
    if (!_canManageUnavailabilityTarget(
      ownerKind: normalizedKind,
      ownerId: normalizedOwnerId,
    )) {
      throw StateError('해당 대상의 불가 시간을 수정할 권한이 없습니다.');
    }

    await _runBusy('불가 시간을 저장하는 중...', () async {
      await _repository.createMemberUnavailabilityBlock(
        homeschoolId: homeschoolId,
        ownerKind: normalizedKind,
        ownerId: normalizedOwnerId,
        dayOfWeek: dayOfWeek,
        startTime: normalizedStart,
        endTime: normalizedEnd,
        note: note,
        createdByUserId: user!.id,
      );
      await loadMemberUnavailabilityBlocks();
      _setStatus('불가 시간을 저장했습니다.');
    });
  }

  Future<void> deleteMemberUnavailabilityBlock({
    required String blockId,
  }) async {
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(blockId);
    if (normalizedId == null) {
      throw StateError('삭제할 항목을 선택하세요.');
    }
    final target = memberUnavailabilityBlocks
        .where((row) => row.id == normalizedId)
        .firstOrNull;
    if (target == null) {
      throw StateError('삭제할 항목을 찾을 수 없습니다.');
    }
    if (!_canManageUnavailabilityTarget(
      ownerKind: target.ownerKind,
      ownerId: target.ownerId,
    )) {
      throw StateError('해당 대상의 불가 시간을 삭제할 권한이 없습니다.');
    }

    await _runBusy('불가 시간을 삭제하는 중...', () async {
      await _repository.deleteMemberUnavailabilityBlock(blockId: normalizedId);
      await loadMemberUnavailabilityBlocks();
      _setStatus('불가 시간을 삭제했습니다.');
    });
  }

  Future<void> assignTeacherToSession({
    required String classSessionId,
    required String teacherProfileId,
    required String assignmentRole,
  }) async {
    if (!canManageTeacherAssignments) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy('교사를 시간표에 배정하는 중...', () async {
      try {
        if (assignmentRole == 'MAIN') {
          await _repository.setSessionMainTeacher(
            classSessionId: classSessionId,
            teacherProfileId: teacherProfileId,
          );
        } else {
          await _repository.upsertSessionTeacherAssignment(
            classSessionId: classSessionId,
            teacherProfileId: teacherProfileId,
            assignmentRole: 'ASSISTANT',
          );
        }
      } on PostgrestException catch (error) {
        if (error.message.contains('TEACHER_SLOT_CONFLICT')) {
          throw StateError('선택한 교사는 같은 시간대 다른 수업에 이미 배정되어 있습니다.');
        }
        rethrow;
      }

      await loadSessionTeacherAssignments();
      await _logAudit(
        actionType: 'SESSION_TEACHER_ASSIGN',
        resourceType: 'session_teacher_assignments',
        resourceId: '$classSessionId:$teacherProfileId:$assignmentRole',
      );
      _setStatus('교사 배정을 반영했습니다.');
    });
  }

  Future<void> removeTeacherFromSession({
    required String classSessionId,
    required String teacherProfileId,
  }) async {
    if (!canManageTeacherAssignments) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    await _runBusy('교사 배정을 해제하는 중...', () async {
      await _repository.deleteSessionTeacherAssignment(
        classSessionId: classSessionId,
        teacherProfileId: teacherProfileId,
      );
      await loadSessionTeacherAssignments();
      await _logAudit(
        actionType: 'SESSION_TEACHER_REMOVE',
        resourceType: 'session_teacher_assignments',
        resourceId: '$classSessionId:$teacherProfileId',
      );
      _setStatus('교사 배정을 해제했습니다.');
    });
  }

  Future<void> createTeachingPlan({
    required String classSessionId,
    required String teacherProfileId,
    required String objectives,
    required String materials,
    required String activities,
  }) async {
    if (!canWriteTeachingPlan) {
      throw StateError('교사/관리자 권한이 필요합니다.');
    }

    final trimmedObjectives = objectives.trim();
    if (trimmedObjectives.isEmpty) {
      throw StateError('수업 목표를 입력하세요.');
    }

    await _runBusy('수업 계획을 등록하는 중...', () async {
      await _repository.createTeachingPlan(
        classSessionId: classSessionId,
        teacherProfileId: teacherProfileId,
        objectives: trimmedObjectives,
        materials: materials,
        activities: activities,
      );
      await loadTeachingPlans();
      _setStatus('수업 계획을 등록했습니다.');
    });
  }

  Future<void> createStudentActivityLog({
    required String childId,
    required String? classSessionId,
    required String teacherProfileId,
    required String activityType,
    required String content,
  }) async {
    if (!canWriteActivityLog) {
      throw StateError('교사/관리자 권한이 필요합니다.');
    }

    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty) {
      throw StateError('활동 내용을 입력하세요.');
    }

    await _runBusy('아동 활동 기록을 등록하는 중...', () async {
      await _repository.createStudentActivityLog(
        childId: childId,
        classSessionId: classSessionId,
        recordedByTeacherId: teacherProfileId,
        activityType: activityType,
        content: trimmedContent,
      );
      await loadStudentActivityLogs();
      _setStatus('아동 활동 기록을 등록했습니다.');
    });
  }

  Future<void> createAnnouncement({
    required String title,
    required String body,
    required String? classGroupId,
    required bool pinned,
  }) async {
    if (!canWriteAnnouncement || user == null) {
      throw StateError('교사/관리자 권한이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty || trimmedBody.isEmpty) {
      throw StateError('공지 제목과 본문을 모두 입력하세요.');
    }

    await _runBusy('공지사항을 등록하는 중...', () async {
      await _repository.createAnnouncement(
        homeschoolId: homeschoolId,
        classGroupId: _normalizeNullable(classGroupId),
        authorUserId: user!.id,
        title: trimmedTitle,
        body: trimmedBody,
        pinned: pinned,
      );
      await loadAnnouncements();
      await _logAudit(
        actionType: 'ANNOUNCEMENT_CREATE',
        resourceType: 'announcements',
        resourceId: trimmedTitle,
      );
      _setStatus('공지사항을 등록했습니다.');
    });
  }

  Future<void> createHomeschoolInvite({
    required String inviteEmail,
    required String role,
    int expirationDays = 14,
  }) async {
    if (!canManageMemberships || user == null) {
      throw StateError('홈스쿨 관리자 권한이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final normalizedEmail = _normalizeNullable(inviteEmail)?.toLowerCase();
    if (normalizedEmail == null || !_looksLikeEmail(normalizedEmail)) {
      throw StateError('유효한 이메일 주소를 입력하세요.');
    }

    final safeDays = expirationDays <= 0 ? 14 : expirationDays;

    await _runBusy('이메일 초대를 생성하는 중...', () async {
      await _repository.createHomeschoolInvite(
        homeschoolId: homeschoolId,
        inviteEmail: normalizedEmail,
        role: role,
        invitedByUserId: user!.id,
        expiresAt: DateTime.now().toUtc().add(Duration(days: safeDays)),
      );

      await loadHomeschoolInvites();
      await loadPendingInvites();
      await _logAudit(
        actionType: 'MEMBER_INVITE_CREATE',
        resourceType: 'homeschool_invites',
        resourceId: normalizedEmail,
        afterJson: {'role': role},
      );
      _setStatus('$normalizedEmail 에게 $role 초대를 보냈습니다.');
    });
  }

  Future<void> cancelHomeschoolInvite(String inviteId) async {
    if (!canManageMemberships) {
      throw StateError('홈스쿨 관리자 권한이 필요합니다.');
    }

    final normalizedId = _normalizeNullable(inviteId);
    if (normalizedId == null) {
      throw StateError('초대 ID가 필요합니다.');
    }

    await _runBusy('초대를 취소하는 중...', () async {
      await _repository.cancelHomeschoolInvite(inviteId: normalizedId);
      await loadHomeschoolInvites();
      await _logAudit(
        actionType: 'MEMBER_INVITE_CANCEL',
        resourceType: 'homeschool_invites',
        resourceId: normalizedId,
      );
      _setStatus('초대를 취소했습니다.');
    });
  }

  Future<void> acceptPendingInvite(String inviteToken) async {
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final normalizedToken = _normalizeNullable(inviteToken);
    if (normalizedToken == null) {
      throw StateError('초대 토큰이 없습니다.');
    }

    await _runBusy('홈스쿨 초대를 수락하는 중...', () async {
      await _repository.acceptHomeschoolInvite(inviteToken: normalizedToken);
      await loadHomeschoolContext();
      _setStatus('초대를 수락하고 홈스쿨에 참여했습니다.');
    });
  }

  Future<List<HomeschoolDirectoryEntry>> searchHomeschoolDirectory({
    required String query,
    int limit = 24,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) {
      return const [];
    }

    return _repository.searchHomeschoolDirectory(
      query: normalizedQuery,
      limit: limit,
    );
  }

  Future<void> requestJoinHomeschool({
    required String homeschoolId,
    String requestNote = '',
  }) async {
    if (user == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final normalizedHomeschoolId = _normalizeNullable(homeschoolId);
    if (normalizedHomeschoolId == null) {
      throw StateError('가입 요청할 홈스쿨을 선택하세요.');
    }

    final alreadyMember = memberships.any(
      (membership) => membership.homeschoolId == normalizedHomeschoolId,
    );
    if (alreadyMember) {
      throw StateError('이미 가입된 홈스쿨입니다.');
    }

    final normalizedEmail = _normalizeNullable(user?.email);
    if (normalizedEmail == null || !_looksLikeEmail(normalizedEmail)) {
      throw StateError('계정 이메일 정보를 확인할 수 없습니다.');
    }

    final metadataName = user?.userMetadata?['full_name'];
    final derivedName = metadataName is String
        ? metadataName.trim()
        : normalizedEmail.split('@').first;

    await _runBusy('홈스쿨 가입 요청을 보내는 중...', () async {
      await _repository.createHomeschoolJoinRequest(
        homeschoolId: normalizedHomeschoolId,
        requesterUserId: user!.id,
        requesterEmail: normalizedEmail,
        requesterName: derivedName,
        requestNote: requestNote,
      );
      _setStatus('가입 요청을 보냈습니다. 홈스쿨 관리자 승인 후 참여할 수 있습니다.');
    });
  }

  Future<void> grantMembershipRole({
    required String targetUserId,
    required String role,
  }) async {
    if (!canManageMemberships) {
      throw StateError('홈스쿨 관리자 권한이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final normalizedUserId = _normalizeNullable(targetUserId);
    if (normalizedUserId == null) {
      throw StateError('사용자 ID를 입력하세요.');
    }

    await _runBusy('권한을 부여하는 중...', () async {
      await _repository.grantMembershipRole(
        homeschoolId: homeschoolId,
        userId: normalizedUserId,
        role: role,
      );

      if (user != null) {
        memberships = await _repository.fetchMemberships(userId: user!.id);
        currentRole = _resolveViewRole(selectedHomeschoolId);
      }
      await Future.wait([
        loadHomeschoolMemberships(),
        loadHomeschoolMemberDirectory(),
      ]);
      await _logAudit(
        actionType: 'MEMBERSHIP_GRANT',
        resourceType: 'homeschool_memberships',
        resourceId: '$normalizedUserId:$role',
      );
      final displayName = findMemberDisplayName(normalizedUserId);
      _setStatus('$displayName 에게 $role 권한을 부여했습니다.');
    });
  }

  Future<void> revokeMembershipRole({
    required String targetUserId,
    required String role,
  }) async {
    if (!canManageMemberships) {
      throw StateError('홈스쿨 관리자 권한이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final normalizedUserId = _normalizeNullable(targetUserId);
    if (normalizedUserId == null) {
      throw StateError('사용자 ID를 입력하세요.');
    }

    final isAdminRole = role == 'HOMESCHOOL_ADMIN';
    if (isAdminRole) {
      final adminCount = homeschoolMemberships
          .where(
            (row) =>
                row.role == 'HOMESCHOOL_ADMIN' &&
                row.status == 'ACTIVE' &&
                row.homeschoolId == homeschoolId,
          )
          .length;

      if (adminCount <= 1) {
        throw StateError('최소 1명의 홈스쿨 관리자는 유지되어야 합니다.');
      }
    }

    await _runBusy('권한을 회수하는 중...', () async {
      await _repository.revokeMembershipRole(
        homeschoolId: homeschoolId,
        userId: normalizedUserId,
        role: role,
      );

      final displayName = findMemberDisplayName(normalizedUserId);
      if (user != null) {
        memberships = await _repository.fetchMemberships(userId: user!.id);
        currentRole = _resolveViewRole(selectedHomeschoolId);
      }
      await Future.wait([
        loadHomeschoolMemberships(),
        loadHomeschoolMemberDirectory(),
      ]);
      await _logAudit(
        actionType: 'MEMBERSHIP_REVOKE',
        resourceType: 'homeschool_memberships',
        resourceId: '$normalizedUserId:$role',
      );
      _setStatus('$displayName 의 $role 권한을 회수했습니다.');
    });
  }

  Future<void> leaveHomeschool() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 먼저 선택하세요.');
    }

    final userId = user?.id;
    if (userId == null) {
      throw StateError('로그인이 필요합니다.');
    }

    final myRoles = memberships
        .where((m) => m.homeschoolId == homeschoolId && m.userId == userId)
        .toList();

    if (myRoles.isEmpty) {
      throw StateError('이미 이 홈스쿨에 소속되어 있지 않습니다.');
    }

    final isOnlyAdmin = myRoles.any((m) => m.role == 'HOMESCHOOL_ADMIN') &&
        homeschoolMemberships
                .where((m) =>
                    m.role == 'HOMESCHOOL_ADMIN' &&
                    m.status == 'ACTIVE' &&
                    m.homeschoolId == homeschoolId)
                .length <=
            1;

    if (isOnlyAdmin) {
      throw StateError(
        '유일한 관리자는 탈퇴할 수 없습니다. 다른 구성원에게 관리자 역할을 부여한 뒤 탈퇴하세요.',
      );
    }

    await _runBusy('홈스쿨 탈퇴 처리 중...', () async {
      for (final m in myRoles) {
        await _repository.revokeMembershipRole(
          homeschoolId: homeschoolId,
          userId: userId,
          role: m.role,
        );
      }

      memberships = await _repository.fetchMemberships(userId: userId);

      if (memberships.isNotEmpty) {
        selectedHomeschoolId = memberships.first.homeschoolId;
        currentRole = _resolveViewRole(selectedHomeschoolId);
        await loadHomeschoolMemberships();
        await _loadOperationalData();
      } else {
        selectedHomeschoolId = null;
        currentRole = null;
        homeschoolMemberships = [];
      }

      await _logAudit(
        actionType: 'MEMBERSHIP_LEAVE',
        resourceType: 'homeschool_memberships',
        resourceId: '$userId:$homeschoolId',
      );
      _setStatus('홈스쿨에서 탈퇴했습니다.');
    });
  }

  String findCourseName(String courseId) {
    return courses
            .where((course) => course.id == courseId)
            .map((course) => course.name)
            .firstOrNull ??
        courseId;
  }

  TimeSlot? findTimeSlot(String slotId) {
    return timeSlots.where((slot) => slot.id == slotId).firstOrNull;
  }

  List<String> findTaggedChildren(String mediaAssetId) {
    return mediaChildrenByAsset[mediaAssetId] ?? const [];
  }

  List<ClassSession> sessionsForSlot(String slotId) {
    return sessions
        .where((session) => session.timeSlotId == slotId)
        .toList();
  }

  List<CommunityPostMedia> mediaForCommunityPost(String postId) {
    return communityMediaByPost[postId] ?? const [];
  }

  List<CommunityComment> commentsForCommunityPost(String postId) {
    return communityCommentsByPost[postId] ?? const [];
  }

  int likesForCommunityPost(String postId) {
    return communityLikeCountsByPost[postId] ?? 0;
  }

  bool isCommunityPostLiked(String postId) {
    return likedCommunityPostIds.contains(postId);
  }

  List<CommunityReport> reportsForCommunityPost(String postId) {
    return communityReports
        .where((report) => report.postId == postId)
        .toList();
  }

  int openReportsForCommunityPost(String postId) {
    return communityReports
        .where((report) => report.postId == postId && report.isOpen)
        .length;
  }

  int get openCommunityReportCount {
    return communityReports.where((report) => report.isOpen).length;
  }

  int get pendingInviteCount {
    return pendingInvites.where((invite) => invite.canAccept).length;
  }

  List<TeacherProfile> get currentUserTeacherProfiles {
    if (isTeacherView && hasAdminLikeMembershipInSelectedHomeschool) {
      final targetProfileId = activeTeacherViewTargetProfileId;
      if (targetProfileId == null || targetProfileId.isEmpty) {
        return const [];
      }
      return teacherProfiles
          .where((profile) => profile.id == targetProfileId)
          .toList();
    }

    final currentUserId = user?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      return const [];
    }

    return teacherProfiles
        .where((profile) => profile.userId == currentUserId)
        .toList();
  }

  String? get defaultTeacherProfileId {
    final myProfiles = currentUserTeacherProfiles;
    if (myProfiles.isNotEmpty) {
      return myProfiles.first.id;
    }
    return teacherProfiles.map((profile) => profile.id).firstOrNull;
  }

  bool _canManageUnavailabilityTarget({
    required String ownerKind,
    required String ownerId,
  }) {
    if (isAdminLike) {
      return true;
    }
    final currentUserId = user?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      return false;
    }

    if (ownerKind == 'MEMBER_USER') {
      return isParentView && ownerId == currentUserId;
    }

    if (ownerKind == 'TEACHER_PROFILE') {
      if (!isTeacherView) {
        return false;
      }
      return currentUserTeacherProfiles
          .map((profile) => profile.id)
          .contains(ownerId);
    }

    return false;
  }

  List<HomeschoolMemberDirectoryEntry> searchHomeschoolMemberDirectory(
    String query, {
    int maxResults = 20,
  }) {
    final lowered = query.trim().toLowerCase();
    final rows = lowered.isEmpty
        ? homeschoolMemberDirectory
        : homeschoolMemberDirectory.where((entry) {
            return entry.fullName.toLowerCase().contains(lowered) ||
                entry.email.toLowerCase().contains(lowered) ||
                entry.userId.toLowerCase().contains(lowered);
          });

    final list = rows.toList()
      ..sort((a, b) => a.displayLabel.compareTo(b.displayLabel));
    if (list.length <= maxResults) {
      return list;
    }
    return list.sublist(0, maxResults);
  }

  HomeschoolMemberDirectoryEntry? findHomeschoolMemberByUserId(String userId) {
    final normalized = userId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return homeschoolMemberDirectory
        .where((entry) => entry.userId == normalized)
        .firstOrNull;
  }

  String findMemberDisplayName(String? userId) {
    final normalized = _normalizeNullable(userId);
    if (normalized == null) {
      return '-';
    }
    return findHomeschoolMemberByUserId(normalized)?.displayLabel ?? normalized;
  }

  List<String> get membershipUserIds {
    return homeschoolMemberships
        .map((row) => row.userId)
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList();
  }

  List<Membership> membershipsByUser(String userId) {
    return homeschoolMemberships
        .where((row) => row.userId == userId)
        .toList();
  }

  List<String> get parentCandidateUserIds {
    final fromMemberships = homeschoolMemberships
        .where((row) => row.role == 'PARENT')
        .map((row) => row.userId);
    final fromGuardians = familyGuardianUserIdsByFamily.values
        .expand((rows) => rows)
        .where((id) => id.isNotEmpty);

    return {...fromMemberships, ...fromGuardians}.toList();
  }

  List<ChildProfile> childrenForFamily(String familyId) {
    return children
        .where((child) => child.familyId == familyId)
        .toList();
  }

  List<ChildProfile> get myChildren {
    final targetUserId = activeParentViewTargetUserId;
    if (targetUserId == null || targetUserId.isEmpty) {
      return const [];
    }

    final mine = children
        .where((child) {
          final guardians = familyGuardianUserIdsByFamily[child.familyId];
          if (guardians == null || guardians.isEmpty) {
            return false;
          }
          return guardians.contains(targetUserId);
        })
        .toList();

    if (mine.isNotEmpty) {
      return mine;
    }
    return const [];
  }

  List<String> enrolledChildIdsForClassGroup(String classGroupId) {
    return classEnrollments
        .where((row) => row.classGroupId == classGroupId)
        .map((row) => row.childId)
        .toSet()
        .toList();
  }

  List<ClassGroup> classGroupsForChild(String childId) {
    final classGroupIds = classEnrollments
        .where((row) => row.childId == childId)
        .map((row) => row.classGroupId)
        .toSet();

    final rows = classGroups
        .where((row) => classGroupIds.contains(row.id))
        .toList();
    rows.sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  List<ChildProfile> childrenForClassGroup(String classGroupId) {
    final childIds = enrolledChildIdsForClassGroup(classGroupId).toSet();
    if (childIds.isEmpty) {
      return const [];
    }
    final rows = children
        .where((child) => childIds.contains(child.id))
        .toList();
    rows.sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  bool isChildEnrolledInClass({
    required String classGroupId,
    required String childId,
  }) {
    return classEnrollments.any(
      (row) => row.classGroupId == classGroupId && row.childId == childId,
    );
  }

  Set<String> parentUserIdsForClassGroup(String classGroupId) {
    final childIds = enrolledChildIdsForClassGroup(classGroupId).toSet();
    if (childIds.isEmpty) {
      return const <String>{};
    }

    final familyIds = children
        .where((child) => childIds.contains(child.id))
        .map((child) => child.familyId)
        .where((id) => id.isNotEmpty)
        .toSet();

    final users = <String>{};
    for (final familyId in familyIds) {
      users.addAll(familyGuardianUserIdsByFamily[familyId] ?? const []);
    }
    return users;
  }

  String findAvailabilityOwnerLabel(MemberUnavailabilityBlock block) {
    if (block.isTeacherOwner) {
      return '교사 · ${findTeacherName(block.ownerId)}';
    }
    return '부모 · ${findMemberDisplayName(block.ownerId)}';
  }

  String findTeacherName(String teacherProfileId) {
    return teacherProfiles
            .where((profile) => profile.id == teacherProfileId)
            .map((profile) => profile.displayName)
            .firstOrNull ??
        teacherProfileId;
  }

  List<SessionTeacherAssignment> teacherAssignmentsForSession(
    String sessionId,
  ) {
    final rows = sessionTeacherAssignments
        .where((row) => row.classSessionId == sessionId)
        .toList();

    rows.sort((a, b) {
      final left = a.assignmentRole == 'MAIN' ? 0 : 1;
      final right = b.assignmentRole == 'MAIN' ? 0 : 1;
      if (left != right) {
        return left.compareTo(right);
      }
      return findTeacherName(
        a.teacherProfileId,
      ).compareTo(findTeacherName(b.teacherProfileId));
    });

    return rows;
  }

  List<String> teacherConflictMessagesForSession(String sessionId) {
    final targetSession = sessions
        .where((item) => item.id == sessionId)
        .firstOrNull;
    if (targetSession == null) {
      return const [];
    }

    final slotId = targetSession.timeSlotId;
    final messages = <String>{};

    for (final assignment in teacherAssignmentsForSession(sessionId)) {
      final duplicated = sessionTeacherAssignments.any(
        (row) =>
            row.teacherProfileId == assignment.teacherProfileId &&
            row.classSessionId != sessionId &&
            sessions.any(
              (otherSession) =>
                  otherSession.id == row.classSessionId &&
                  otherSession.timeSlotId == slotId,
            ),
      );
      if (duplicated) {
        messages.add('${findTeacherName(assignment.teacherProfileId)} 시간충돌');
      }
    }

    return messages.toList();
  }

  Map<String, Set<String>> blockedSlotIdsByTeacherProfile() {
    final blocks = memberUnavailabilityBlocks
        .where((row) => row.ownerKind == 'TEACHER_PROFILE')
        .toList();
    if (blocks.isEmpty || timeSlots.isEmpty) {
      return const {};
    }

    final map = <String, Set<String>>{};
    for (final block in blocks) {
      final blockedSlots = timeSlots
          .where((slot) => _doesSlotOverlapBlock(slot: slot, block: block))
          .map((slot) => slot.id)
          .toSet();
      if (blockedSlots.isEmpty) {
        continue;
      }
      map.putIfAbsent(block.ownerId, () => <String>{});
      map[block.ownerId]!.addAll(blockedSlots);
    }
    return map;
  }

  Set<String> blockedSlotIdsForParentsInClass(String classGroupId) {
    final parentIds = parentUserIdsForClassGroup(classGroupId);
    if (parentIds.isEmpty || timeSlots.isEmpty) {
      return const {};
    }

    final blocks = memberUnavailabilityBlocks
        .where(
          (row) =>
              row.ownerKind == 'MEMBER_USER' && parentIds.contains(row.ownerId),
        )
        .toList();
    if (blocks.isEmpty) {
      return const {};
    }

    final blocked = <String>{};
    for (final block in blocks) {
      blocked.addAll(
        timeSlots
            .where((slot) => _doesSlotOverlapBlock(slot: slot, block: block))
            .map((slot) => slot.id),
      );
    }
    return blocked;
  }

  List<String> timetableBoardIssueMessages() {
    final issues = <String>{};
    final classGroupId = selectedClassGroupId;
    final parentBlockedSlots = classGroupId == null
        ? const <String>{}
        : blockedSlotIdsForParentsInClass(classGroupId);
    final teacherBlockedSlotsByTeacher = blockedSlotIdsByTeacherProfile();

    for (final session in sessions) {
      for (final conflict in teacherConflictMessagesForSession(session.id)) {
        issues.add(conflict);
      }

      final hasMainTeacher = teacherAssignmentsForSession(
        session.id,
      ).any((assignment) => assignment.assignmentRole == 'MAIN');
      if (!hasMainTeacher) {
        final slot = findTimeSlot(session.timeSlotId);
        final slotLabel = slot == null
            ? session.timeSlotId
            : '${slot.dayOfWeek} ${slot.startTime.substring(0, 5)}';
        issues.add(
          '${findCourseName(session.courseId)} · 주강사 미지정 ($slotLabel)',
        );
      }

      if (parentBlockedSlots.contains(session.timeSlotId)) {
        final slot = findTimeSlot(session.timeSlotId);
        final slotLabel = slot == null
            ? session.timeSlotId
            : '${slot.dayOfWeek} ${slot.startTime.substring(0, 5)}';
        issues.add(
          '${findCourseName(session.courseId)} · 부모 불가 시간대 ($slotLabel)',
        );
      }

      final mainRows = teacherAssignmentsForSession(
        session.id,
      ).where((row) => row.assignmentRole == 'MAIN');
      for (final row in mainRows) {
        final blocked = teacherBlockedSlotsByTeacher[row.teacherProfileId];
        if (blocked == null || !blocked.contains(session.timeSlotId)) {
          continue;
        }
        final slot = findTimeSlot(session.timeSlotId);
        final slotLabel = slot == null
            ? session.timeSlotId
            : '${slot.dayOfWeek} ${slot.startTime.substring(0, 5)}';
        issues.add(
          '${findTeacherName(row.teacherProfileId)} 불가 시간대 배정 ($slotLabel)',
        );
      }
    }

    // Classroom conflicts: same time slot + same classroom across all class groups
    final locationBySlot = <String, List<ClassSession>>{};
    for (final session in allTermSessions) {
      final loc = session.location;
      if (loc == null || loc.trim().isEmpty) continue;
      final key = '${session.timeSlotId}|${loc.trim()}';
      locationBySlot.putIfAbsent(key, () => <ClassSession>[]);
      locationBySlot[key]!.add(session);
    }
    for (final entry in locationBySlot.entries) {
      if (entry.value.length < 2) continue;
      final slot = findTimeSlot(entry.value.first.timeSlotId);
      final slotLabel = slot == null
          ? ''
          : '${slot.dayOfWeek} ${slot.startTime.substring(0, 5)}';
      final loc = entry.value.first.location!;
      final names = entry.value
          .map((s) => findCourseName(s.courseId))
          .join(', ');
      issues.add('교실 충돌: $loc ($slotLabel) - $names');
    }

    return issues.toList();
  }

  bool _doesSlotOverlapBlock({
    required TimeSlot slot,
    required MemberUnavailabilityBlock block,
  }) {
    if (slot.dayOfWeek != block.dayOfWeek) {
      return false;
    }

    final slotStart = _clockToMinutes(slot.startTime);
    final slotEnd = _clockToMinutes(slot.endTime);
    final blockStart = _clockToMinutes(block.startTime);
    final blockEnd = _clockToMinutes(block.endTime);

    if (slotStart == null ||
        slotEnd == null ||
        blockStart == null ||
        blockEnd == null) {
      return false;
    }

    return slotStart < blockEnd && blockStart < slotEnd;
  }

  List<TeachingPlan> teachingPlansForSession(String sessionId) {
    return teachingPlans
        .where((plan) => plan.classSessionId == sessionId)
        .toList();
  }

  List<StudentActivityLog> activityLogsForChild(String childId) {
    return studentActivityLogs
        .where((log) => log.childId == childId)
        .toList();
  }

  String findClassGroupName(String? classGroupId) {
    if (classGroupId == null || classGroupId.isEmpty) {
      return '전체 공개';
    }

    return classGroups
            .where((group) => group.id == classGroupId)
            .map((group) => group.name)
            .firstOrNull ??
        '지정 반';
  }

  Future<List<ClassSession>> fetchSessionsForClassGroup({
    required String classGroupId,
  }) {
    return _repository.fetchSessions(classGroupId: classGroupId);
  }

  Future<List<SessionTeacherAssignment>>
  fetchSessionTeacherAssignmentsForSessions({
    required List<String> classSessionIds,
  }) {
    return _repository.fetchSessionTeacherAssignments(
      classSessionIds: classSessionIds,
    );
  }

  Future<List<TeachingPlan>> fetchTeachingPlansForSessions({
    required List<String> classSessionIds,
  }) {
    return _repository.fetchTeachingPlans(classSessionIds: classSessionIds);
  }

  Future<List<Announcement>> fetchAnnouncementsForHomeschool() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      return const [];
    }
    return _repository.fetchAnnouncements(homeschoolId: homeschoolId);
  }

  Future<void> _loadTermAndBelow() async {
    await _loadTerms();
    // classGroups sets selectedClassGroupId needed by _loadSessions.
    // timetableAssets only needs termId, so it can run in parallel with classGroups.
    await Future.wait([_loadClassGroups(), _loadTimetableAssets()]);
    await Future.wait([_loadSessions(), _loadProposals()]);
  }

  Future<void> _loadTerms() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      terms = [];
      selectedTermId = null;
      return;
    }

    terms = await _repository.fetchTerms(homeschoolId: homeschoolId);

    final validTermIds = terms.map((term) => term.id).toSet();
    if (selectedTermId == null || !validTermIds.contains(selectedTermId)) {
      selectedTermId = terms.isNotEmpty ? terms.first.id : null;
    }
  }

  Future<void> _loadClassGroups() async {
    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      classGroups = [];
      selectedClassGroupId = null;
      return;
    }

    classGroups = await _repository.fetchClassGroups(termId: termId);

    final validClassIds = classGroups.map((row) => row.id).toSet();
    if (selectedClassGroupId == null ||
        !validClassIds.contains(selectedClassGroupId)) {
      selectedClassGroupId = classGroups.isNotEmpty
          ? classGroups.first.id
          : null;
    }
  }

  Future<void> _loadTimetableAssets() async {
    final homeschoolId = selectedHomeschoolId;
    final termId = selectedTermId;

    if (homeschoolId == null || termId == null) {
      courses = [];
      classrooms = [];
      timeSlots = [];
      return;
    }

    final results = await Future.wait([
      _repository.fetchCourses(homeschoolId: homeschoolId),
      _repository.fetchClassrooms(termId: termId),
      _repository.fetchTimeSlots(termId: termId),
    ]);
    courses = results[0] as List<Course>;
    classrooms = results[1] as List<Classroom>;
    timeSlots = results[2] as List<TimeSlot>;
  }

  Future<void> _loadSessions() async {
    final classGroupId = selectedClassGroupId;
    if (classGroupId == null || classGroupId.isEmpty) {
      sessions = [];
      allTermSessions = [];
      return;
    }

    sessions = await _repository.fetchSessions(classGroupId: classGroupId);

    // Load all sessions across all class groups for location conflict detection
    final allGroupIds = classGroups.map((cg) => cg.id).toList();
    if (allGroupIds.isNotEmpty) {
      allTermSessions = await _repository.fetchSessionsForClassGroups(
        classGroupIds: allGroupIds,
      );
    } else {
      allTermSessions = sessions;
    }
  }

  Future<void> _loadProposals() async {
    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      proposals = [];
      proposalSessionsById = const {};
      scheduleOptionDrafts = [];
      selectedScheduleOptionId = null;
      return;
    }

    proposals = await _repository.fetchProposals(termId: termId);

    final proposalIds = proposals
        .map((proposal) => proposal.id)
        .toList();
    proposalSessionsById = await _repository.fetchProposalSessionsByProposal(
      proposalIds: proposalIds,
    );
  }

  void _replaceScheduleOptionDraft(ScheduleOptionDraft updated) {
    scheduleOptionDrafts = scheduleOptionDrafts
        .map((draft) => draft.id == updated.id ? updated : draft)
        .toList();
    selectedScheduleOptionId = updated.id;
    notifyListeners();
  }

  Future<void> _onAuthStateChanged(Session? nextSession) async {
    session = nextSession;
    user = nextSession?.user;

    if (user == null) {
      _clearDomainState();
      _setStatus('세션 없음');
      notifyListeners();
      return;
    }

    await loadHomeschoolContext();
  }

  Future<void> _runBusy(
    String progressMessage,
    Future<void> Function() task,
  ) async {
    _isBusy = true;
    _setStatus(progressMessage);
    notifyListeners();

    try {
      await task();
    } on AuthException catch (error) {
      _setStatus('인증 오류: ${error.message}');
      rethrow;
    } on PostgrestException catch (error) {
      _setStatus('DB 오류: ${error.message}');
      rethrow;
    } on StorageException catch (error) {
      _setStatus('스토리지 오류: ${error.message}');
      rethrow;
    } on FunctionException catch (error) {
      _setStatus('함수 오류: ${error.details ?? error.reasonPhrase ?? 'unknown'}');
      rethrow;
    } catch (error) {
      _setStatus(error.toString().replaceFirst('Exception: ', ''));
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _ensureRoleViewTargetSelection({String? roleOverride}) {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      return;
    }
    if (!hasAdminLikeMembershipInSelectedHomeschool) {
      _parentViewTargetByHomeschool.remove(homeschoolId);
      _teacherViewTargetByHomeschool.remove(homeschoolId);
      return;
    }

    final role = roleOverride ?? currentRole;

    if (role == 'PARENT') {
      final parentCandidates = parentViewCandidateUserIds;
      if (parentCandidates.isEmpty) {
        _parentViewTargetByHomeschool.remove(homeschoolId);
      } else {
        final selected = _parentViewTargetByHomeschool[homeschoolId];
        if (selected == null || !parentCandidates.contains(selected)) {
          final currentUserId = user?.id;
          _parentViewTargetByHomeschool[homeschoolId] =
              currentUserId != null && parentCandidates.contains(currentUserId)
              ? currentUserId
              : parentCandidates.first;
        }
      }
    }

    if (role == 'TEACHER' || role == 'GUEST_TEACHER') {
      final teacherCandidates = teacherViewCandidateProfiles;
      if (teacherCandidates.isEmpty) {
        _teacherViewTargetByHomeschool.remove(homeschoolId);
      } else {
        final selected = _teacherViewTargetByHomeschool[homeschoolId];
        final isValidSelection =
            selected != null &&
            teacherCandidates.any((profile) => profile.id == selected);
        if (!isValidSelection) {
          final currentUserId = user?.id;
          final myProfile = teacherCandidates
              .where((profile) => profile.userId == currentUserId)
              .firstOrNull;
          _teacherViewTargetByHomeschool[homeschoolId] =
              myProfile?.id ?? teacherCandidates.first.id;
        }
      }
    }
  }

  String? _resolveViewRole(String? homeschoolId) {
    if (homeschoolId == null) {
      return null;
    }

    final roles = memberships
        .where((membership) => membership.homeschoolId == homeschoolId)
        .map((membership) => membership.role)
        .toSet();

    final preferred = _viewRoleByHomeschool[homeschoolId];
    if (preferred != null && roles.contains(preferred)) {
      return preferred;
    }

    const rolePriority = <String>[
      'HOMESCHOOL_ADMIN',
      'STAFF',
      'TEACHER',
      'GUEST_TEACHER',
      'PARENT',
    ];

    for (final role in rolePriority) {
      if (roles.contains(role)) {
        _viewRoleByHomeschool[homeschoolId] = role;
        return role;
      }
    }

    final fallback = roles.firstOrNull;
    if (fallback != null) {
      _viewRoleByHomeschool[homeschoolId] = fallback;
    }
    return fallback;
  }

  /// Restore cached data into controller fields for instant UI rendering.
  void _restoreFromCache() {
    final userId = user?.id;
    if (userId == null) return;

    // Restore last selected homeschool.
    final lastHomeschoolId = NestCache.loadLastHomeschoolId(userId: userId);
    if (lastHomeschoolId == null) return;

    final cachedMeta = NestCache.loadMeta(
      userId: userId,
      homeschoolId: lastHomeschoolId,
    );
    if (cachedMeta == null) return;

    selectedHomeschoolId = lastHomeschoolId;
    selectedTermId = cachedMeta['selectedTermId'] as String?;
    selectedClassGroupId = cachedMeta['selectedClassGroupId'] as String?;
    currentRole = cachedMeta['currentRole'] as String?;
    final cachedParentTarget = cachedMeta['parentViewTargetUserId'] as String?;
    if (cachedParentTarget != null && cachedParentTarget.trim().isNotEmpty) {
      _parentViewTargetByHomeschool[lastHomeschoolId] = cachedParentTarget;
    }
    final cachedTeacherTarget =
        cachedMeta['teacherViewTargetProfileId'] as String?;
    if (cachedTeacherTarget != null && cachedTeacherTarget.trim().isNotEmpty) {
      _teacherViewTargetByHomeschool[lastHomeschoolId] = cachedTeacherTarget;
    }

    memberships =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'memberships',
          fromMap: Membership.fromMap,
        ) ??
        const [];
    terms =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'terms',
          fromMap: Term.fromMap,
        ) ??
        const [];
    classGroups =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'classGroups',
          fromMap: ClassGroup.fromMap,
        ) ??
        const [];
    courses =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'courses',
          fromMap: Course.fromMap,
        ) ??
        const [];
    classrooms =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'classrooms',
          fromMap: Classroom.fromMap,
        ) ??
        const [];
    timeSlots =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'timeSlots',
          fromMap: TimeSlot.fromMap,
        ) ??
        const [];
    sessions =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'sessions',
          fromMap: ClassSession.fromMap,
        ) ??
        const [];
    proposals =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'proposals',
          fromMap: Proposal.fromMap,
        ) ??
        const [];
    proposalSessionsById = _restoreProposalSessionsMap(
      userId,
      lastHomeschoolId,
    );
    families =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'families',
          fromMap: Family.fromMap,
        ) ??
        const [];
    children =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'children',
          fromMap: ChildProfile.fromMap,
        ) ??
        const [];
    classEnrollments =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'classEnrollments',
          fromMap: ClassEnrollment.fromMap,
        ) ??
        const [];
    familyGuardianUserIdsByFamily =
        NestCache.loadStringListMap(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'familyGuardians',
        ) ??
        const {};
    teacherProfiles =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'teacherProfiles',
          fromMap: TeacherProfile.fromMap,
        ) ??
        const [];
    memberUnavailabilityBlocks =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'unavailabilityBlocks',
          fromMap: MemberUnavailabilityBlock.fromMap,
        ) ??
        const [];
    sessionTeacherAssignments =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'teacherAssignments',
          fromMap: SessionTeacherAssignment.fromMap,
        ) ??
        const [];
    teachingPlans =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'teachingPlans',
          fromMap: TeachingPlan.fromMap,
        ) ??
        const [];
    studentActivityLogs =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'activityLogs',
          fromMap: StudentActivityLog.fromMap,
        ) ??
        const [];
    homeschoolMemberships =
        NestCache.loadCollection(
          userId: userId,
          homeschoolId: lastHomeschoolId,
          collection: 'homeschoolMemberships',
          fromMap: Membership.fromMap,
        ) ??
        const [];
  }

  Map<String, List<ProposalSession>> _restoreProposalSessionsMap(
    String userId,
    String homeschoolId,
  ) {
    final flat = NestCache.loadCollection(
      userId: userId,
      homeschoolId: homeschoolId,
      collection: 'proposalSessions',
      fromMap: ProposalSession.fromMap,
    );
    if (flat == null) return const {};
    final result = <String, List<ProposalSession>>{};
    for (final ps in flat) {
      (result[ps.proposalId] ??= []).add(ps);
    }
    return result;
  }

  /// Persist current controller state to local cache (fire-and-forget).
  Future<void> _persistToCache() async {
    final userId = user?.id;
    final homeschoolId = selectedHomeschoolId;
    if (userId == null || homeschoolId == null) return;

    await NestCache.saveLastHomeschoolId(
      userId: userId,
      homeschoolId: homeschoolId,
    );
    await NestCache.saveMeta(
      userId: userId,
      homeschoolId: homeschoolId,
      selectedTermId: selectedTermId,
      selectedClassGroupId: selectedClassGroupId,
      currentRole: currentRole,
      parentViewTargetUserId: _parentViewTargetByHomeschool[homeschoolId],
      teacherViewTargetProfileId: _teacherViewTargetByHomeschool[homeschoolId],
    );

    await Future.wait([
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'memberships',
        items: memberships,
        toMap: (m) => m.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'terms',
        items: terms,
        toMap: (t) => t.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'classGroups',
        items: classGroups,
        toMap: (c) => c.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'courses',
        items: courses,
        toMap: (c) => c.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'classrooms',
        items: classrooms,
        toMap: (c) => c.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'timeSlots',
        items: timeSlots,
        toMap: (t) => t.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'sessions',
        items: sessions,
        toMap: (s) => s.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'proposals',
        items: proposals,
        toMap: (p) => p.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'proposalSessions',
        items: proposalSessionsById.values.expand((v) => v).toList(),
        toMap: (ps) => ps.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'families',
        items: families,
        toMap: (f) => f.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'children',
        items: children,
        toMap: (c) => c.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'classEnrollments',
        items: classEnrollments,
        toMap: (e) => e.toMap(),
      ),
      NestCache.saveStringListMap(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'familyGuardians',
        data: familyGuardianUserIdsByFamily,
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'teacherProfiles',
        items: teacherProfiles,
        toMap: (t) => t.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'unavailabilityBlocks',
        items: memberUnavailabilityBlocks,
        toMap: (b) => b.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'teacherAssignments',
        items: sessionTeacherAssignments,
        toMap: (a) => a.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'teachingPlans',
        items: teachingPlans,
        toMap: (p) => p.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'activityLogs',
        items: studentActivityLogs,
        toMap: (l) => l.toMap(),
      ),
      NestCache.saveCollection(
        userId: userId,
        homeschoolId: homeschoolId,
        collection: 'homeschoolMemberships',
        items: homeschoolMemberships,
        toMap: (m) => m.toMap(),
      ),
    ]);
  }

  void _clearDomainState() {
    memberships = [];
    homeschoolMemberships = [];
    homeschoolInvites = [];
    homeschoolMemberDirectory = [];
    pendingInvites = [];
    joinRequests = [];
    childRegistrationRequests = [];
    families = [];
    children = [];
    classEnrollments = [];
    familyGuardianUserIdsByFamily = const {};
    teacherProfiles = [];
    memberUnavailabilityBlocks = [];
    sessionTeacherAssignments = [];
    teachingPlans = [];
    studentActivityLogs = [];
    announcements = [];
    auditLogs = [];
    _viewRoleByHomeschool.clear();
    _parentViewTargetByHomeschool.clear();
    _teacherViewTargetByHomeschool.clear();
    selectedHomeschoolId = null;
    currentRole = null;
    terms = [];
    selectedTermId = null;
    classGroups = [];
    selectedClassGroupId = null;
    courses = [];
    classrooms = [];
    timeSlots = [];
    sessions = [];
    proposals = [];
    proposalSessionsById = const {};
    scheduleOptionDrafts = [];
    selectedScheduleOptionId = null;
    galleryItems = [];
    mediaChildrenByAsset = const {};
    pendingMediaFile = null;
    communityPosts = [];
    communityMediaByPost = const {};
    communityCommentsByPost = const {};
    communityLikeCountsByPost = const {};
    likedCommunityPostIds = <String>{};
    communityReports = [];
    pendingCommunityMediaFile = null;
  }

  void _setStatus(String text) {
    _statusMessage = text;
  }

  Future<void> _logAudit({
    required String actionType,
    required String resourceType,
    required String resourceId,
    Map<String, dynamic>? beforeJson,
    Map<String, dynamic>? afterJson,
  }) async {
    if (!isAdminLike || user == null) {
      return;
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      return;
    }

    try {
      await _repository.insertAuditLog(
        homeschoolId: homeschoolId,
        actorUserId: user!.id,
        actionType: actionType,
        resourceType: resourceType,
        resourceId: resourceId,
        beforeJson: beforeJson,
        afterJson: afterJson,
      );
      await loadAuditLogs();
    } catch (_) {
      // Ignore audit persistence errors to keep primary action non-blocking.
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

String _authorDisplayName(User user) {
  final metadata = user.userMetadata ?? const <String, dynamic>{};
  final fromName = _metadataString(metadata, 'name');
  if (fromName != null) {
    return fromName;
  }

  final fromFullName = _metadataString(metadata, 'full_name');
  if (fromFullName != null) {
    return fromFullName;
  }

  final email = _normalizeNullable(user.email);
  if (email != null) {
    return email.split('@').first;
  }

  return 'Member';
}

String? _metadataString(Map<String, dynamic> metadata, String key) {
  final value = metadata[key];
  if (value is String) {
    return _normalizeNullable(value);
  }

  return null;
}

String? _normalizeNullable(String? input) {
  if (input == null) {
    return null;
  }

  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return trimmed;
}

List<String> _parseCommaWords(String csv) {
  return csv
      .split(',')
      .map((chunk) => chunk.trim())
      .where((chunk) => chunk.isNotEmpty)
      .toSet()
      .toList();
}

List<String> _parseCommaIds(String csv) {
  return csv
      .split(',')
      .map((chunk) => chunk.trim())
      .where((chunk) => chunk.isNotEmpty)
      .toSet()
      .toList();
}

String _guessMimeType(String fileName) {
  final lower = fileName.toLowerCase();

  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }
  if (lower.endsWith('.heic')) {
    return 'image/heic';
  }
  if (lower.endsWith('.mp4')) {
    return 'video/mp4';
  }
  if (lower.endsWith('.mov')) {
    return 'video/quicktime';
  }

  return 'application/octet-stream';
}

bool _looksLikeEmail(String value) {
  final at = value.indexOf('@');
  if (at <= 0 || at >= value.length - 1) {
    return false;
  }

  final domain = value.substring(at + 1);
  return domain.contains('.');
}

String? _normalizeClockText(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  final parts = trimmed.split(':');
  if (parts.length < 2 || parts.length > 3) {
    return null;
  }

  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  final second = parts.length >= 3 ? int.tryParse(parts[2]) : 0;
  if (hour == null ||
      minute == null ||
      second == null ||
      hour < 0 ||
      hour > 23 ||
      minute < 0 ||
      minute > 59 ||
      second < 0 ||
      second > 59) {
    return null;
  }

  final h = hour.toString().padLeft(2, '0');
  final m = minute.toString().padLeft(2, '0');
  final s = second.toString().padLeft(2, '0');
  return '$h:$m:$s';
}

bool _isClockRangeValid(String startTime, String endTime) {
  final start = _clockToMinutes(startTime);
  final end = _clockToMinutes(endTime);
  if (start == null || end == null) {
    return false;
  }
  return end > start;
}

int? _clockToMinutes(String value) {
  final normalized = _normalizeClockText(value);
  if (normalized == null) {
    return null;
  }

  final parts = normalized.split(':');
  final hour = int.parse(parts[0]);
  final minute = int.parse(parts[1]);
  return hour * 60 + minute;
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
