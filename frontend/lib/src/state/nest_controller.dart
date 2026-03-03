import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';
import '../models/nest_models.dart';
import '../services/local_planner.dart';
import '../services/nest_repository.dart';
import '../services/web_oauth_bridge.dart';

class NestController extends ChangeNotifier {
  NestController({
    required NestRepository repository,
    required WebOauthBridge webOauthBridge,
  }) : _repository = repository,
       _webOauthBridge = webOauthBridge;

  final NestRepository _repository;
  final WebOauthBridge _webOauthBridge;

  StreamSubscription<AuthState>? _authSubscription;

  bool _isBootstrapped = false;
  bool _isBusy = false;
  String _statusMessage = 'Ready';

  User? user;
  Session? session;

  List<Membership> memberships = const [];
  List<Membership> homeschoolMemberships = const [];
  List<HomeschoolInvite> homeschoolInvites = const [];
  List<HomeschoolMemberDirectoryEntry> homeschoolMemberDirectory = const [];
  List<HomeschoolInvite> pendingInvites = const [];
  List<Family> families = const [];
  List<ChildProfile> children = const [];
  List<ClassEnrollment> classEnrollments = const [];
  Map<String, List<String>> familyGuardianUserIdsByFamily = const {};
  List<TeacherProfile> teacherProfiles = const [];
  List<MemberUnavailabilityBlock> memberUnavailabilityBlocks = const [];
  List<SessionTeacherAssignment> sessionTeacherAssignments = const [];
  List<TeachingPlan> teachingPlans = const [];
  List<StudentActivityLog> studentActivityLogs = const [];
  List<Announcement> announcements = const [];
  List<AuditLog> auditLogs = const [];
  String? selectedHomeschoolId;
  String? currentRole;
  final Map<String, String> _viewRoleByHomeschool = <String, String>{};

  List<Term> terms = const [];
  String? selectedTermId;

  List<ClassGroup> classGroups = const [];
  String? selectedClassGroupId;

  List<Course> courses = const [];
  List<TimeSlot> timeSlots = const [];
  List<ClassSession> sessions = const [];

  List<Proposal> proposals = const [];
  Map<String, List<ProposalSession>> proposalSessionsById = const {};
  List<ScheduleOptionDraft> scheduleOptionDrafts = const [];
  String? selectedScheduleOptionId;

  DriveIntegration? driveIntegration;

  List<GalleryItem> galleryItems = const [];
  Map<String, List<String>> mediaChildrenByAsset = const {};
  PendingMediaFile? pendingMediaFile;

  List<CommunityPost> communityPosts = const [];
  Map<String, List<CommunityPostMedia>> communityMediaByPost = const {};
  Map<String, List<CommunityComment>> communityCommentsByPost = const {};
  Map<String, int> communityLikeCountsByPost = const {};
  Set<String> likedCommunityPostIds = const <String>{};
  List<CommunityReport> communityReports = const [];
  PendingMediaFile? pendingCommunityMediaFile;

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

    final ordered = rolePriority.where(roles.contains).toList(growable: false);
    if (ordered.isNotEmpty) {
      return ordered;
    }

    return roles.toList(growable: false);
  }

  bool get isAdminLike =>
      currentRole == 'HOMESCHOOL_ADMIN' || currentRole == 'STAFF';

  bool get isDriveAdmin => currentRole == 'HOMESCHOOL_ADMIN';
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

    _authSubscription = _repository.authChanges.listen((authState) {
      unawaited(_onAuthStateChanged(authState.session));
    });

    if (isLoggedIn) {
      await loadHomeschoolContext();
    }

    _isBootstrapped = true;
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    await _runBusy('로그인 중...', () async {
      await _repository.signIn(email: email.trim(), password: password.trim());
      await _onAuthStateChanged(_repository.currentSession);
      _setStatus('로그인 성공');
    });
  }

  Future<void> signUp({required String email, required String password}) async {
    await _runBusy('회원가입 중...', () async {
      final response = await _repository.signUp(
        email: email.trim(),
        password: password.trim(),
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
  }

  Future<void> signOut() async {
    await _runBusy('로그아웃 중...', () async {
      await _repository.signOut();
      await _onAuthStateChanged(null);
      _setStatus('로그아웃 완료');
    });
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
    notifyListeners();

    await _runBusy('학기/반 정보를 불러오는 중...', () async {
      await _loadTermAndBelow();
      await loadHomeschoolMemberships();
      await loadHomeschoolInvites();
      await _loadOperationalData();
      await loadDriveIntegration();
      await loadGalleryItems();
      await loadCommunityFeed();
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
    notifyListeners();

    await _runBusy('뷰 전환 중...', () async {
      await loadHomeschoolMemberships();
      await loadHomeschoolInvites();
      await _loadOperationalData();
      await loadCommunityFeed();
      _setStatus('현재 뷰: $nextRole');
    });
  }

  Future<void> changeTerm(String? termId) async {
    selectedTermId = _normalizeNullable(termId);
    scheduleOptionDrafts = const [];
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
    scheduleOptionDrafts = const [];
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
        .toList(growable: false);

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
        .toList(growable: false);

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

      final sortedSessions = refreshedDraft.sessions.toList(growable: false)
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

    await _runBusy('Google Drive로 업로드하는 중...', () async {
      final uploadSessionId = await _repository.createUploadSession(
        homeschoolId: homeschoolId,
        uploaderUserId: user!.id,
        mimeType: file.mimeType,
        sizeBytes: file.sizeBytes,
      );

      try {
        final uploadResult = await _repository.uploadToDrive(
          homeschoolId: homeschoolId,
          uploadSessionId: uploadSessionId,
          file: file,
        );

        final mediaAssetId = await _repository.insertMediaAsset(
          homeschoolId: homeschoolId,
          uploadSessionId: uploadSessionId,
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

        await _repository.updateUploadStatus(
          uploadSessionId: uploadSessionId,
          status: 'COMPLETED',
        );
      } catch (error) {
        await _repository.updateUploadStatus(
          uploadSessionId: uploadSessionId,
          status: 'FAILED',
        );
        rethrow;
      }

      pendingMediaFile = null;
      await loadGalleryItems();
      _setStatus('Drive 업로드 완료');
    });
  }

  Future<void> startDriveOauth({
    required String rootFolderId,
    required String folderPolicy,
  }) async {
    if (!isDriveAdmin) {
      throw StateError('홈스쿨 관리자 권한이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    final currentSession = session;

    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 선택하세요.');
    }

    if (currentSession?.accessToken == null) {
      throw StateError('로그인 세션이 유효하지 않습니다. 다시 로그인하세요.');
    }

    await _runBusy('Google OAuth URL 준비 중...', () async {
      final authUrl = await _repository.startGoogleDriveOauth(
        homeschoolId: homeschoolId,
      );

      if (_webOauthBridge.supported) {
        await _webOauthBridge.stashContext(
          homeschoolId: homeschoolId,
          rootFolderId: rootFolderId.trim(),
          folderPolicy: folderPolicy,
          supabaseUrl: AppConfig.supabaseUrl,
          supabaseAnonKey: AppConfig.supabaseAnonKey,
          accessToken: currentSession!.accessToken,
        );

        await _webOauthBridge.openPopup(authUrl);
        _setStatus('OAuth 팝업을 열었습니다. 인증 후 동기화 버튼을 누르세요.');
        return;
      }

      final launchOk = await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launchOk) {
        throw StateError('브라우저에서 OAuth URL을 열지 못했습니다.');
      }

      _setStatus('외부 브라우저에서 OAuth를 진행하세요.');
    });
  }

  Future<void> syncOauthResult() async {
    if (!_webOauthBridge.supported) {
      return;
    }

    final result = await _webOauthBridge.consumeResult();
    if (result == null) {
      _setStatus('동기화할 OAuth 결과가 없습니다.');
      return;
    }

    final success = result['success'] == true;
    if (!success) {
      _setStatus('OAuth 실패: ${result['error'] ?? 'unknown'}');
      return;
    }

    await loadDriveIntegration();
    _setStatus('Google Drive OAuth 연결 완료');
  }

  Future<void> saveDriveSettings({
    required String rootFolderId,
    required String folderPolicy,
    required String accessToken,
    required String refreshToken,
    required String tokenExpiresAt,
  }) async {
    if (!isDriveAdmin || user == null) {
      throw StateError('홈스쿨 관리자 권한이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 선택하세요.');
    }

    await _runBusy('Drive 설정 저장 중...', () async {
      await _repository.upsertDriveIntegration(
        homeschoolId: homeschoolId,
        userId: user!.id,
        rootFolderId: rootFolderId.trim(),
        folderPolicy: folderPolicy,
        accessToken: accessToken,
        refreshToken: refreshToken,
        tokenExpiresAtIso: tokenExpiresAt,
      );
      await loadDriveIntegration();
      _setStatus('Drive 설정 저장 완료');
    });
  }

  Future<void> disconnectDrive() async {
    if (!isDriveAdmin) {
      throw StateError('홈스쿨 관리자 권한이 필요합니다.');
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      throw StateError('홈스쿨을 선택하세요.');
    }

    await _runBusy('Drive 연동 해제 중...', () async {
      await _repository.disconnectDrive(homeschoolId: homeschoolId);
      await loadDriveIntegration();
      _setStatus('Drive 연동 해제 완료');
    });
  }

  Future<void> loadHomeschoolContext() async {
    if (user == null) {
      _clearDomainState();
      notifyListeners();
      return;
    }

    await loadPendingInvites();
    memberships = await _repository.fetchMemberships(userId: user!.id);

    if (memberships.isEmpty) {
      selectedHomeschoolId = null;
      currentRole = null;
      _viewRoleByHomeschool.clear();
      terms = const [];
      classGroups = const [];
      courses = const [];
      timeSlots = const [];
      sessions = const [];
      proposals = const [];
      proposalSessionsById = const {};
      scheduleOptionDrafts = const [];
      selectedScheduleOptionId = null;
      galleryItems = const [];
      mediaChildrenByAsset = const {};
      communityPosts = const [];
      communityMediaByPost = const {};
      communityCommentsByPost = const {};
      communityLikeCountsByPost = const {};
      likedCommunityPostIds = const <String>{};
      communityReports = const [];
      homeschoolMemberships = const [];
      homeschoolInvites = const [];
      homeschoolMemberDirectory = const [];
      families = const [];
      children = const [];
      classEnrollments = const [];
      familyGuardianUserIdsByFamily = const {};
      teacherProfiles = const [];
      memberUnavailabilityBlocks = const [];
      sessionTeacherAssignments = const [];
      teachingPlans = const [];
      studentActivityLogs = const [];
      announcements = const [];
      auditLogs = const [];
      pendingCommunityMediaFile = null;
      driveIntegration = null;

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

    await _loadTermAndBelow();
    await loadHomeschoolMemberships();
    await loadHomeschoolInvites();
    await _loadOperationalData();
    await loadDriveIntegration();
    await syncOauthResult();
    await loadGalleryItems();
    await loadCommunityFeed();

    _setStatus('운영 컨텍스트 로드 완료');
    notifyListeners();
  }

  Future<void> loadDriveIntegration() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      driveIntegration = null;
      notifyListeners();
      return;
    }

    driveIntegration = await _repository.fetchDriveIntegration(
      homeschoolId: homeschoolId,
    );
    notifyListeners();
  }

  Future<void> loadGalleryItems() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      galleryItems = const [];
      mediaChildrenByAsset = const {};
      notifyListeners();
      return;
    }

    galleryItems = await _repository.fetchGalleryItems(
      homeschoolId: homeschoolId,
      classGroupId: selectedClassGroupId,
    );

    mediaChildrenByAsset = await _repository.fetchMediaChildrenByAsset(
      mediaAssetIds: galleryItems
          .map((item) => item.id)
          .toList(growable: false),
    );

    notifyListeners();
  }

  Future<void> loadHomeschoolMemberships() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      homeschoolMemberships = const [];
      notifyListeners();
      return;
    }

    homeschoolMemberships = await _repository.fetchHomeschoolMemberships(
      homeschoolId: homeschoolId,
    );
    notifyListeners();
  }

  Future<void> loadHomeschoolInvites() async {
    if (!canManageMemberships) {
      homeschoolInvites = const [];
      notifyListeners();
      return;
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      homeschoolInvites = const [];
      notifyListeners();
      return;
    }

    homeschoolInvites = await _repository.fetchHomeschoolInvites(
      homeschoolId: homeschoolId,
    );
    notifyListeners();
  }

  Future<void> loadHomeschoolMemberDirectory({
    String query = '',
    int limit = 120,
  }) async {
    if (!canManageTeacherAssignments) {
      homeschoolMemberDirectory = const [];
      notifyListeners();
      return;
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      homeschoolMemberDirectory = const [];
      notifyListeners();
      return;
    }

    homeschoolMemberDirectory = await _repository.searchHomeschoolMembers(
      homeschoolId: homeschoolId,
      query: query,
      limit: limit,
    );
    notifyListeners();
  }

  Future<void> loadPendingInvites() async {
    final currentUser = user;
    if (currentUser == null) {
      pendingInvites = const [];
      notifyListeners();
      return;
    }

    final email = _normalizeNullable(currentUser.email);
    if (email == null) {
      pendingInvites = const [];
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
      families = const [];
      familyGuardianUserIdsByFamily = const {};
      notifyListeners();
      return;
    }

    families = await _repository.fetchFamilies(homeschoolId: homeschoolId);
    notifyListeners();
  }

  Future<void> loadFamilyGuardians() async {
    if (families.isEmpty) {
      familyGuardianUserIdsByFamily = const {};
      notifyListeners();
      return;
    }

    final familyIds = families
        .map((family) => family.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    familyGuardianUserIdsByFamily = await _repository
        .fetchFamilyGuardianUserIds(familyIds: familyIds);
    notifyListeners();
  }

  Future<void> loadChildren() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      children = const [];
      notifyListeners();
      return;
    }

    children = await _repository.fetchChildren(homeschoolId: homeschoolId);
    notifyListeners();
  }

  Future<void> loadClassEnrollments() async {
    final classGroupIds = classGroups
        .map((group) => group.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    classEnrollments = await _repository.fetchClassEnrollments(
      classGroupIds: classGroupIds,
    );
    notifyListeners();
  }

  Future<void> loadTeacherProfiles() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      teacherProfiles = const [];
      notifyListeners();
      return;
    }

    teacherProfiles = await _repository.fetchTeacherProfiles(
      homeschoolId: homeschoolId,
    );
    notifyListeners();
  }

  Future<void> loadMemberUnavailabilityBlocks() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      memberUnavailabilityBlocks = const [];
      notifyListeners();
      return;
    }

    memberUnavailabilityBlocks = await _repository
        .fetchMemberUnavailabilityBlocks(homeschoolId: homeschoolId);
    notifyListeners();
  }

  Future<void> loadSessionTeacherAssignments() async {
    final sessionIds = sessions
        .map((session) => session.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    sessionTeacherAssignments = await _repository
        .fetchSessionTeacherAssignments(classSessionIds: sessionIds);
    notifyListeners();
  }

  Future<void> loadTeachingPlans() async {
    final sessionIds = sessions
        .map((session) => session.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    teachingPlans = await _repository.fetchTeachingPlans(
      classSessionIds: sessionIds,
    );
    notifyListeners();
  }

  Future<void> loadStudentActivityLogs() async {
    final childIds = children
        .map((child) => child.id)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);

    studentActivityLogs = await _repository.fetchStudentActivityLogs(
      childIds: childIds,
    );
    notifyListeners();
  }

  Future<void> loadAnnouncements() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      announcements = const [];
      notifyListeners();
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
              .toList(growable: false);

    notifyListeners();
  }

  Future<void> loadAuditLogs() async {
    if (!isAdminLike) {
      auditLogs = const [];
      notifyListeners();
      return;
    }

    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      auditLogs = const [];
      notifyListeners();
      return;
    }

    auditLogs = await _repository.fetchAuditLogs(homeschoolId: homeschoolId);
    notifyListeners();
  }

  Future<void> _loadOperationalData() async {
    await loadHomeschoolMemberDirectory();
    await loadFamilies();
    await loadFamilyGuardians();
    await loadChildren();
    await loadClassEnrollments();
    await loadTeacherProfiles();
    await loadMemberUnavailabilityBlocks();
    await loadSessionTeacherAssignments();
    await loadTeachingPlans();
    await loadStudentActivityLogs();
    await loadAnnouncements();
    await loadAuditLogs();
  }

  Future<void> loadCommunityFeed() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      communityPosts = const [];
      communityMediaByPost = const {};
      communityCommentsByPost = const {};
      communityLikeCountsByPost = const {};
      likedCommunityPostIds = const <String>{};
      communityReports = const [];
      pendingCommunityMediaFile = null;
      notifyListeners();
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
              .toList(growable: false);

    final postIds = filteredPosts
        .map((post) => post.id)
        .toList(growable: false);

    communityPosts = filteredPosts;
    communityMediaByPost = await _repository.fetchCommunityMediaByPost(
      postIds: postIds,
    );
    communityCommentsByPost = await _repository.fetchCommunityCommentsByPost(
      postIds: postIds,
    );

    if (user != null) {
      final reactionSnapshot = await _repository.fetchCommunityReactions(
        postIds: postIds,
        currentUserId: user!.id,
      );
      communityLikeCountsByPost = reactionSnapshot.likeCountsByPostId;
      likedCommunityPostIds = reactionSnapshot.likedPostIds;
    } else {
      communityLikeCountsByPost = const {};
      likedCommunityPostIds = const <String>{};
    }

    if (canModerateCommunity) {
      communityReports = await _repository.fetchCommunityReports(
        homeschoolId: homeschoolId,
      );
    } else {
      communityReports = const [];
    }

    notifyListeners();
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
        final uploadSessionId = await _repository.createUploadSession(
          homeschoolId: homeschoolId,
          uploaderUserId: user!.id,
          mimeType: pendingFile.mimeType,
          sizeBytes: pendingFile.sizeBytes,
        );

        try {
          final uploadResult = await _repository.uploadToDrive(
            homeschoolId: homeschoolId,
            uploadSessionId: uploadSessionId,
            file: pendingFile,
          );

          final mediaAssetId = await _repository.insertMediaAsset(
            homeschoolId: homeschoolId,
            uploadSessionId: uploadSessionId,
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

          await _repository.updateUploadStatus(
            uploadSessionId: uploadSessionId,
            status: 'COMPLETED',
          );
        } catch (_) {
          await _repository.updateUploadStatus(
            uploadSessionId: uploadSessionId,
            status: 'FAILED',
          );
          rethrow;
        }
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

  Future<void> createFamily({
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

    await _runBusy('가정을 생성하는 중...', () async {
      final created = await _repository.createFamily(
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
  }

  Future<void> createChild({
    required String familyId,
    required String name,
    required String birthDate,
    required String profileNote,
  }) async {
    if (!canManageFamilies) {
      throw StateError('관리자/스태프 권한이 필요합니다.');
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw StateError('아이 이름을 입력하세요.');
    }
    if (DateTime.tryParse(birthDate.trim()) == null) {
      throw StateError('생년월일은 YYYY-MM-DD 형식으로 입력하세요.');
    }

    await _runBusy('아이 정보를 등록하는 중...', () async {
      final created = await _repository.createChild(
        familyId: familyId,
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

  Future<void> createTeacherProfile({
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

    await _runBusy('교사 프로필을 생성하는 중...', () async {
      final created = await _repository.createTeacherProfile(
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
      await loadHomeschoolMemberships();
      await _logAudit(
        actionType: 'MEMBERSHIP_GRANT',
        resourceType: 'homeschool_memberships',
        resourceId: '$normalizedUserId:$role',
      );
      _setStatus('$normalizedUserId 에게 $role 권한을 부여했습니다.');
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

      if (user != null) {
        memberships = await _repository.fetchMemberships(userId: user!.id);
        currentRole = _resolveViewRole(selectedHomeschoolId);
      }
      await loadHomeschoolMemberships();
      await _logAudit(
        actionType: 'MEMBERSHIP_REVOKE',
        resourceType: 'homeschool_memberships',
        resourceId: '$normalizedUserId:$role',
      );
      _setStatus('$normalizedUserId 의 $role 권한을 회수했습니다.');
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
        .toList(growable: false);
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
        .toList(growable: false);
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
    final currentUserId = user?.id;
    if (currentUserId == null || currentUserId.isEmpty) {
      return const [];
    }

    return teacherProfiles
        .where((profile) => profile.userId == currentUserId)
        .toList(growable: false);
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

    final list = rows.toList(growable: false)
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
        .toList(growable: false);
  }

  List<Membership> membershipsByUser(String userId) {
    return homeschoolMemberships
        .where((row) => row.userId == userId)
        .toList(growable: false);
  }

  List<String> get parentCandidateUserIds {
    final fromMemberships = homeschoolMemberships
        .where((row) => row.role == 'PARENT')
        .map((row) => row.userId);
    final fromGuardians = familyGuardianUserIdsByFamily.values
        .expand((rows) => rows)
        .where((id) => id.isNotEmpty);

    return {...fromMemberships, ...fromGuardians}.toList(growable: false);
  }

  List<ChildProfile> childrenForFamily(String familyId) {
    return children
        .where((child) => child.familyId == familyId)
        .toList(growable: false);
  }

  List<String> enrolledChildIdsForClassGroup(String classGroupId) {
    return classEnrollments
        .where((row) => row.classGroupId == classGroupId)
        .map((row) => row.childId)
        .toSet()
        .toList(growable: false);
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
        .toList(growable: false);

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

    return messages.toList(growable: false);
  }

  Map<String, Set<String>> blockedSlotIdsByTeacherProfile() {
    final blocks = memberUnavailabilityBlocks
        .where((row) => row.ownerKind == 'TEACHER_PROFILE')
        .toList(growable: false);
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
        .toList(growable: false);
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

    return issues.toList(growable: false);
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
        .toList(growable: false);
  }

  List<StudentActivityLog> activityLogsForChild(String childId) {
    return studentActivityLogs
        .where((log) => log.childId == childId)
        .toList(growable: false);
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

  Future<void> _loadTermAndBelow() async {
    await _loadTerms();
    await _loadClassGroups();
    await _loadTimetableAssets();
    await _loadSessions();
    await _loadProposals();
  }

  Future<void> _loadTerms() async {
    final homeschoolId = selectedHomeschoolId;
    if (homeschoolId == null || homeschoolId.isEmpty) {
      terms = const [];
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
      classGroups = const [];
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
      courses = const [];
      timeSlots = const [];
      return;
    }

    courses = await _repository.fetchCourses(homeschoolId: homeschoolId);
    timeSlots = await _repository.fetchTimeSlots(termId: termId);
  }

  Future<void> _loadSessions() async {
    final classGroupId = selectedClassGroupId;
    if (classGroupId == null || classGroupId.isEmpty) {
      sessions = const [];
      return;
    }

    sessions = await _repository.fetchSessions(classGroupId: classGroupId);
  }

  Future<void> _loadProposals() async {
    final termId = selectedTermId;
    if (termId == null || termId.isEmpty) {
      proposals = const [];
      proposalSessionsById = const {};
      scheduleOptionDrafts = const [];
      selectedScheduleOptionId = null;
      return;
    }

    proposals = await _repository.fetchProposals(termId: termId);

    final proposalIds = proposals
        .map((proposal) => proposal.id)
        .toList(growable: false);
    proposalSessionsById = await _repository.fetchProposalSessionsByProposal(
      proposalIds: proposalIds,
    );
  }

  void _replaceScheduleOptionDraft(ScheduleOptionDraft updated) {
    scheduleOptionDrafts = scheduleOptionDrafts
        .map((draft) => draft.id == updated.id ? updated : draft)
        .toList(growable: false);
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

  void _clearDomainState() {
    memberships = const [];
    homeschoolMemberships = const [];
    homeschoolInvites = const [];
    homeschoolMemberDirectory = const [];
    pendingInvites = const [];
    families = const [];
    children = const [];
    classEnrollments = const [];
    familyGuardianUserIdsByFamily = const {};
    teacherProfiles = const [];
    memberUnavailabilityBlocks = const [];
    sessionTeacherAssignments = const [];
    teachingPlans = const [];
    studentActivityLogs = const [];
    announcements = const [];
    auditLogs = const [];
    _viewRoleByHomeschool.clear();
    selectedHomeschoolId = null;
    currentRole = null;
    terms = const [];
    selectedTermId = null;
    classGroups = const [];
    selectedClassGroupId = null;
    courses = const [];
    timeSlots = const [];
    sessions = const [];
    proposals = const [];
    proposalSessionsById = const {};
    scheduleOptionDrafts = const [];
    selectedScheduleOptionId = null;
    driveIntegration = null;
    galleryItems = const [];
    mediaChildrenByAsset = const {};
    pendingMediaFile = null;
    communityPosts = const [];
    communityMediaByPost = const {};
    communityCommentsByPost = const {};
    communityLikeCountsByPost = const {};
    likedCommunityPostIds = const <String>{};
    communityReports = const [];
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
      .toList(growable: false);
}

List<String> _parseCommaIds(String csv) {
  return csv
      .split(',')
      .map((chunk) => chunk.trim())
      .where((chunk) => chunk.isNotEmpty)
      .toSet()
      .toList(growable: false);
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
