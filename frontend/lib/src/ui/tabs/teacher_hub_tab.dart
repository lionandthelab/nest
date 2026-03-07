import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/hub_scaffold.dart';
import '../widgets/search_select_field.dart';

class TeacherHubTab extends StatefulWidget {
  const TeacherHubTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<TeacherHubTab> createState() => _TeacherHubTabState();
}

class _TeacherHubTabState extends State<TeacherHubTab> {
  final _planObjectivesController = TextEditingController();
  final _planMaterialsController = TextEditingController();
  final _planActivitiesController = TextEditingController();
  final _logContentController = TextEditingController();
  final _announceTitleController = TextEditingController();
  final _announceBodyController = TextEditingController();
  final _unavailabilityStartController = TextEditingController(text: '09:00');
  final _unavailabilityEndController = TextEditingController(text: '10:00');
  final _unavailabilityNoteController = TextEditingController();

  String? _planSessionId;
  String? _planTeacherProfileId;
  String? _logChildId;
  String? _logSessionId;
  String? _logTeacherProfileId;
  String? _unavailabilityTeacherProfileId;
  String _logActivityType = 'OBSERVATION';
  bool _announcePinned = false;
  int _selectedUnavailabilityDay = 1;
  String _sectionId = 'classes';

  String? _selectedManagedClassGroupId;
  String? _managedClassLoadSignature;
  bool _isLoadingManagedClasses = false;
  Map<String, _TeacherClassBundle> _managedClassBundles = const {};

  @override
  void dispose() {
    _planObjectivesController.dispose();
    _planMaterialsController.dispose();
    _planActivitiesController.dispose();
    _logContentController.dispose();
    _announceTitleController.dispose();
    _announceBodyController.dispose();
    _unavailabilityStartController.dispose();
    _unavailabilityEndController.dispose();
    _unavailabilityNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    _syncManagedClassLoad(controller);

    final selectedBundle = _selectedManagedClassGroupId == null
        ? null
        : _managedClassBundles[_selectedManagedClassGroupId!];
    _syncDefaults(controller, selectedBundle);

    return HubScaffold(
      title: 'Teacher Hub',
      subtitle: '내가 담당하는 반별로 시간표, 공지, 아동 상태를 관리합니다.',
      icon: Icons.school,
      isBusy: controller.isBusy || _isLoadingManagedClasses,
      metrics: [
        HubMetric(
          label: '담당 반',
          value: '${_managedClassBundles.length}',
          icon: Icons.groups,
        ),
        HubMetric(
          label: '선택 반 수업',
          value: '${selectedBundle?.sessions.length ?? 0}',
          icon: Icons.view_week,
        ),
        HubMetric(
          label: '선택 반 아동',
          value: '${selectedBundle?.children.length ?? 0}',
          icon: Icons.child_care,
        ),
      ],
      sections: [
        HubSection(
          id: 'classes',
          label: '반 운영보드',
          icon: Icons.space_dashboard_outlined,
          content: _buildClassBoardSection(controller, selectedBundle),
        ),
        HubSection(
          id: 'operations',
          label: '수업 운영',
          icon: Icons.campaign,
          content: _buildOperationsSection(controller, selectedBundle),
        ),
        HubSection(
          id: 'children',
          label: '아이 상태',
          icon: Icons.monitor_heart_outlined,
          content: _buildChildStatusSection(controller, selectedBundle),
        ),
      ],
      selectedSectionId: _sectionId,
      onSelectSection: (value) {
        setState(() {
          _sectionId = value;
        });
      },
    );
  }

  void _syncManagedClassLoad(NestController controller) {
    final profileIds =
        controller.currentUserTeacherProfiles
            .map((profile) => profile.id)
            .toList(growable: false)
          ..sort();
    final classIds =
        controller.classGroups.map((group) => group.id).toList(growable: false)
          ..sort();

    final signature = '${profileIds.join(',')}::${classIds.join(',')}';
    if (_managedClassLoadSignature == signature) {
      return;
    }

    _managedClassLoadSignature = signature;
    _managedClassBundles = const {};
    _selectedManagedClassGroupId = null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadManagedClassBundles();
    });
  }

  Future<void> _loadManagedClassBundles() async {
    if (_isLoadingManagedClasses) {
      return;
    }

    final controller = widget.controller;
    final myTeacherIds = controller.currentUserTeacherProfiles
        .map((row) => row.id)
        .toSet();

    if (myTeacherIds.isEmpty) {
      setState(() {
        _managedClassBundles = const {};
        _selectedManagedClassGroupId = null;
      });
      return;
    }

    setState(() {
      _isLoadingManagedClasses = true;
    });

    try {
      final announcements = await controller.fetchAnnouncementsForHomeschool();
      final bundles = <String, _TeacherClassBundle>{};

      final classGroups = controller.classGroups.toList(growable: false)
        ..sort((a, b) => a.name.compareTo(b.name));

      for (final classGroup in classGroups) {
        final sessions = await controller.fetchSessionsForClassGroup(
          classGroupId: classGroup.id,
        );
        if (sessions.isEmpty) {
          continue;
        }

        final sessionIds = sessions
            .map((session) => session.id)
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
        final assignments = await controller
            .fetchSessionTeacherAssignmentsForSessions(
              classSessionIds: sessionIds,
            );

        final isAssignedClass = assignments.any(
          (row) => myTeacherIds.contains(row.teacherProfileId),
        );
        if (!isAssignedClass) {
          continue;
        }

        final plans = await controller.fetchTeachingPlansForSessions(
          classSessionIds: sessionIds,
        );
        final classAnnouncements = announcements
            .where(
              (row) =>
                  row.classGroupId == null || row.classGroupId == classGroup.id,
            )
            .toList(growable: false);
        final children = controller.childrenForClassGroup(classGroup.id);

        bundles[classGroup.id] = _TeacherClassBundle(
          classGroup: classGroup,
          sessions: sessions,
          assignments: assignments,
          plans: plans,
          announcements: classAnnouncements,
          children: children,
        );
      }

      if (!mounted) {
        return;
      }

      final currentId = _selectedManagedClassGroupId;
      final selectedId = currentId != null && bundles.containsKey(currentId)
          ? currentId
          : bundles.keys.firstOrNull;

      setState(() {
        _managedClassBundles = bundles;
        _selectedManagedClassGroupId = selectedId;
      });
    } catch (_) {
      _showMessage(controller.statusMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingManagedClasses = false;
        });
      }
    }
  }

  void _syncDefaults(
    NestController controller,
    _TeacherClassBundle? selectedBundle,
  ) {
    final sessionIds =
        selectedBundle?.sessions.map((row) => row.id).toSet() ??
        const <String>{};
    final childIds =
        selectedBundle?.children.map((row) => row.id).toSet() ??
        const <String>{};

    final myTeacherProfiles = controller.currentUserTeacherProfiles;
    final teacherCandidates = myTeacherProfiles.isNotEmpty
        ? myTeacherProfiles
        : controller.teacherProfiles;
    final teacherIds = teacherCandidates.map((row) => row.id).toSet();

    _planSessionId ??= selectedBundle?.sessions.firstOrNull?.id;
    _logSessionId ??= selectedBundle?.sessions.firstOrNull?.id;
    _logChildId ??= selectedBundle?.children.firstOrNull?.id;
    _planTeacherProfileId ??= teacherCandidates.firstOrNull?.id;
    _logTeacherProfileId ??= teacherCandidates.firstOrNull?.id;
    _unavailabilityTeacherProfileId ??= myTeacherProfiles.firstOrNull?.id;

    if (_planSessionId != null && !sessionIds.contains(_planSessionId)) {
      _planSessionId = selectedBundle?.sessions.firstOrNull?.id;
    }
    if (_logSessionId != null && !sessionIds.contains(_logSessionId)) {
      _logSessionId = selectedBundle?.sessions.firstOrNull?.id;
    }
    if (_logChildId != null && !childIds.contains(_logChildId)) {
      _logChildId = selectedBundle?.children.firstOrNull?.id;
    }
    if (_planTeacherProfileId != null &&
        !teacherIds.contains(_planTeacherProfileId)) {
      _planTeacherProfileId = teacherCandidates.firstOrNull?.id;
    }
    if (_logTeacherProfileId != null &&
        !teacherIds.contains(_logTeacherProfileId)) {
      _logTeacherProfileId = teacherCandidates.firstOrNull?.id;
    }
  }

  Widget _buildClassBoardSection(
    NestController controller,
    _TeacherClassBundle? selectedBundle,
  ) {
    final managedClasses = _managedClassBundles.values.toList(growable: false)
      ..sort((a, b) => a.classGroup.name.compareTo(b.classGroup.name));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('담당 반별 뷰', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (managedClasses.isEmpty)
              _buildEmptyHint('담당 교사로 배정된 반이 없습니다.')
            else ...[
              SelectFieldCard(
                label: '담당 반 선택',
                hintText: '반을 선택하세요',
                icon: Icons.groups_2_outlined,
                enabled: !controller.isBusy,
                value: selectedBundle?.classGroup.name,
                helpText: '검색으로 담당 반을 빠르게 전환할 수 있습니다.',
                onTap: () => _selectManagedClass(managedClasses),
              ),
              const SizedBox(height: 12),
              if (selectedBundle != null) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.view_week_outlined, size: 16),
                      label: Text('수업 ${selectedBundle.sessions.length}개'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.child_care_outlined, size: 16),
                      label: Text('아동 ${selectedBundle.children.length}명'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.menu_book_outlined, size: 16),
                      label: Text('계획 ${selectedBundle.plans.length}건'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('시간표', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                ..._buildSessionCards(controller, selectedBundle),
              ],
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSessionCards(
    NestController controller,
    _TeacherClassBundle bundle,
  ) {
    final sessions = bundle.sessions.toList(growable: false)
      ..sort((a, b) {
        final left = controller.findTimeSlot(a.timeSlotId);
        final right = controller.findTimeSlot(b.timeSlotId);
        if (left == null || right == null) {
          return a.timeSlotId.compareTo(b.timeSlotId);
        }
        final dayCompare = left.dayOfWeek.compareTo(right.dayOfWeek);
        if (dayCompare != 0) {
          return dayCompare;
        }
        return left.startTime.compareTo(right.startTime);
      });

    if (sessions.isEmpty) {
      return [_buildEmptyHint('등록된 수업이 없습니다.')];
    }

    return sessions
        .map((session) {
          final slot = controller.findTimeSlot(session.timeSlotId);
          final slotLabel = slot == null
              ? session.timeSlotId
              : '${_dayLabel(slot.dayOfWeek)} ${_shortTime(slot.startTime)}-${_shortTime(slot.endTime)}';
          final teacherLabel = _teacherLabelForSession(
            controller: controller,
            sessionId: session.id,
            assignments: bundle.assignments,
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: NestColors.roseMist),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.findCourseName(session.courseId),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text('$slotLabel · $teacherLabel'),
              ],
            ),
          );
        })
        .toList(growable: false);
  }

  Widget _buildOperationsSection(
    NestController controller,
    _TeacherClassBundle? selectedBundle,
  ) {
    return Column(
      children: [
        _buildTeacherUnavailabilityCard(controller),
        const SizedBox(height: 12),
        _buildTeachingPlanCard(controller, selectedBundle),
        const SizedBox(height: 12),
        _buildClassAnnouncementCard(controller, selectedBundle),
      ],
    );
  }

  Widget _buildTeachingPlanCard(
    NestController controller,
    _TeacherClassBundle? selectedBundle,
  ) {
    final sessions = selectedBundle?.sessions ?? const <ClassSession>[];
    final teacherCandidates = controller.currentUserTeacherProfiles.isNotEmpty
        ? controller.currentUserTeacherProfiles
        : controller.teacherProfiles;
    final selectedSession = sessions
        .where((session) => session.id == _planSessionId)
        .firstOrNull;
    final selectedTeacher = teacherCandidates
        .where((teacher) => teacher.id == _planTeacherProfileId)
        .firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('수업 계획', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (selectedBundle == null)
              _buildEmptyHint('먼저 담당 반을 선택하세요.')
            else if (sessions.isEmpty || teacherCandidates.isEmpty)
              _buildEmptyHint('수업 세션/교사 프로필 데이터가 필요합니다.')
            else ...[
              SelectFieldCard(
                label: '수업 세션',
                hintText: '세션을 선택하세요',
                icon: Icons.class_outlined,
                enabled: !controller.isBusy,
                value: selectedSession == null
                    ? null
                    : _sessionTitle(controller, selectedSession),
                helpText: '계획을 등록할 수업을 선택합니다.',
                onTap: () => _selectPlanSession(controller, sessions),
              ),
              const SizedBox(height: 8),
              SelectFieldCard(
                label: '작성 교사',
                hintText: '교사를 선택하세요',
                icon: Icons.person_outline,
                enabled: !controller.isBusy,
                value: selectedTeacher?.displayName,
                helpText: '현재 계정과 연결된 교사 프로필이 우선 노출됩니다.',
                onTap: () => _selectPlanTeacher(teacherCandidates),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _planObjectivesController,
                decoration: const InputDecoration(
                  labelText: '수업 목표',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _planMaterialsController,
                decoration: const InputDecoration(
                  labelText: '준비물',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _planActivitiesController,
                decoration: const InputDecoration(
                  labelText: '활동 계획',
                  prefixIcon: Icon(Icons.format_list_bulleted),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: controller.isBusy ? null : _createTeachingPlan,
                icon: const Icon(Icons.note_add),
                label: const Text('계획 등록'),
              ),
            ],
            const SizedBox(height: 12),
            Text('최근 계획', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (selectedBundle == null || selectedBundle.plans.isEmpty)
              _buildEmptyHint('등록된 계획이 없습니다.')
            else
              ...selectedBundle.plans.take(10).map((plan) {
                final sessionName =
                    selectedBundle.sessions
                        .where((session) => session.id == plan.classSessionId)
                        .map(
                          (session) => session.title.isEmpty
                              ? controller.findCourseName(session.courseId)
                              : session.title,
                        )
                        .firstOrNull ??
                    plan.classSessionId;
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.menu_book_outlined, size: 18),
                  title: Text(sessionName),
                  subtitle: Text(plan.objectives),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildClassAnnouncementCard(
    NestController controller,
    _TeacherClassBundle? selectedBundle,
  ) {
    final rows = selectedBundle?.announcements ?? const <Announcement>[];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('반 공지', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (selectedBundle == null)
              _buildEmptyHint('반을 먼저 선택하세요.')
            else ...[
              TextField(
                controller: _announceTitleController,
                decoration: const InputDecoration(
                  labelText: '제목',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _announceBodyController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '본문',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                value: _announcePinned,
                title: const Text('상단 고정'),
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _announcePinned = value;
                        });
                      },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: controller.isBusy ? null : _createAnnouncement,
                icon: const Icon(Icons.campaign),
                label: const Text('공지 게시'),
              ),
            ],
            const SizedBox(height: 12),
            Text('최근 공지', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (rows.isEmpty)
              _buildEmptyHint('공지 내역이 없습니다.')
            else
              ...rows.take(12).map((row) {
                final when = row.createdAt == null
                    ? '-'
                    : DateFormat('MM-dd HH:mm').format(row.createdAt!);
                final scope = row.classGroupId == null
                    ? '전체'
                    : selectedBundle?.classGroup.name ?? '반';
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: row.pinned
                      ? const Icon(Icons.push_pin, size: 18)
                      : const Icon(Icons.campaign_outlined, size: 18),
                  title: Text(row.title),
                  subtitle: Text('$scope · ${row.body}'),
                  trailing: Text(
                    when,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildChildStatusSection(
    NestController controller,
    _TeacherClassBundle? selectedBundle,
  ) {
    final children = selectedBundle?.children ?? const <ChildProfile>[];
    final childIds = children.map((child) => child.id).toSet();
    final sessionIds = (selectedBundle?.sessions ?? const <ClassSession>[])
        .map((session) => session.id)
        .toSet();
    final logs =
        controller.studentActivityLogs
            .where(
              (log) =>
                  childIds.contains(log.childId) &&
                  (log.classSessionId == null ||
                      sessionIds.contains(log.classSessionId)),
            )
            .toList(growable: false)
          ..sort((a, b) {
            final left = a.recordedAt?.millisecondsSinceEpoch ?? 0;
            final right = b.recordedAt?.millisecondsSinceEpoch ?? 0;
            return right.compareTo(left);
          });

    final teacherCandidates = controller.currentUserTeacherProfiles.isNotEmpty
        ? controller.currentUserTeacherProfiles
        : controller.teacherProfiles;
    final selectedChild = children
        .where((child) => child.id == _logChildId)
        .firstOrNull;
    final selectedSession = (selectedBundle?.sessions ?? const <ClassSession>[])
        .where((session) => session.id == _logSessionId)
        .firstOrNull;
    final selectedTeacher = teacherCandidates
        .where((teacher) => teacher.id == _logTeacherProfileId)
        .firstOrNull;
    final activityTypeLabel = switch (_logActivityType) {
      'ATTENDANCE' => '출결',
      'ASSIGNMENT' => '과제',
      _ => '관찰',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('아이별 상태 관리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (selectedBundle == null)
              _buildEmptyHint('반을 먼저 선택하세요.')
            else if (children.isEmpty || teacherCandidates.isEmpty)
              _buildEmptyHint('아이/교사 데이터가 필요합니다.')
            else ...[
              SelectFieldCard(
                label: '아이',
                hintText: '아이를 선택하세요',
                icon: Icons.child_care_outlined,
                enabled: !controller.isBusy,
                value: selectedChild == null
                    ? null
                    : '${selectedChild.name} (${selectedChild.familyName})',
                onTap: () => _selectLogChild(children),
              ),
              const SizedBox(height: 8),
              SelectFieldCard(
                label: '연결 수업',
                hintText: '세션 미지정',
                icon: Icons.class_outlined,
                enabled: !controller.isBusy,
                value: selectedSession == null
                    ? '세션 미지정'
                    : _sessionTitle(controller, selectedSession),
                helpText: '세션 없이 기록할 수도 있습니다.',
                onTap: () => _selectLogSession(controller, selectedBundle),
              ),
              const SizedBox(height: 8),
              SelectFieldCard(
                label: '기록 교사',
                hintText: '교사를 선택하세요',
                icon: Icons.person_outline,
                enabled: !controller.isBusy,
                value: selectedTeacher?.displayName,
                onTap: () => _selectLogTeacher(teacherCandidates),
              ),
              const SizedBox(height: 8),
              SelectFieldCard(
                label: '활동 유형',
                hintText: '유형 선택',
                icon: Icons.category_outlined,
                enabled: !controller.isBusy,
                value: activityTypeLabel,
                onTap: _selectLogActivityType,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _logContentController,
                decoration: const InputDecoration(
                  labelText: '활동 내용',
                  prefixIcon: Icon(Icons.edit_note),
                ),
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: controller.isBusy ? null : _createActivityLog,
                icon: const Icon(Icons.fact_check),
                label: const Text('활동 기록 등록'),
              ),
            ],
            const SizedBox(height: 12),
            Text('최근 기록', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              _buildEmptyHint('등록된 활동 기록이 없습니다.')
            else
              ...logs.take(24).map((log) {
                final childName =
                    children
                        .where((child) => child.id == log.childId)
                        .map((child) => child.name)
                        .firstOrNull ??
                    log.childId;
                final when = log.recordedAt == null
                    ? '-'
                    : DateFormat('MM-dd HH:mm').format(log.recordedAt!);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history, size: 18),
                  title: Text('$childName · ${log.activityType}'),
                  subtitle: Text(log.content),
                  trailing: Text(
                    when,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherUnavailabilityCard(NestController controller) {
    final myProfiles = controller.currentUserTeacherProfiles;
    final myProfileIds = myProfiles.map((row) => row.id).toSet();
    final selectedProfileId = _unavailabilityTeacherProfileId;
    final blocks =
        controller.memberUnavailabilityBlocks
            .where(
              (row) =>
                  row.ownerKind == 'TEACHER_PROFILE' &&
                  selectedProfileId != null &&
                  row.ownerId == selectedProfileId,
            )
            .toList(growable: false)
          ..sort((a, b) {
            final day = a.dayOfWeek.compareTo(b.dayOfWeek);
            if (day != 0) {
              return day;
            }
            return a.startTime.compareTo(b.startTime);
          });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('내 불가 시간', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '등록한 시간은 관리자 시간표 생성 시 자동으로 회피됩니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            if (myProfiles.isEmpty)
              _buildEmptyHint('연결된 교사 프로필이 없습니다.')
            else ...[
              SelectFieldCard(
                label: '교사 프로필',
                hintText: '교사 프로필을 선택하세요',
                icon: Icons.person_outline,
                enabled: !controller.isBusy,
                value: myProfiles
                    .where((profile) => profile.id == selectedProfileId)
                    .map((profile) => profile.displayName)
                    .firstOrNull,
                onTap: () => _selectUnavailabilityTeacherProfile(myProfiles),
              ),
              const SizedBox(height: 8),
              Text(
                '요일 선택',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.74),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: List.generate(7, (day) {
                  return ChoiceChip(
                    label: Text(_dayLabel(day)),
                    selected: _selectedUnavailabilityDay == day,
                    onSelected: controller.isBusy
                        ? null
                        : (_) {
                            setState(() {
                              _selectedUnavailabilityDay = day;
                            });
                          },
                  );
                }),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeField(
                      controller: _unavailabilityStartController,
                      label: '시작 (HH:MM)',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTimeField(
                      controller: _unavailabilityEndController,
                      label: '종료 (HH:MM)',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _unavailabilityNoteController,
                decoration: const InputDecoration(labelText: '메모 (선택)'),
                minLines: 1,
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed:
                    controller.isBusy ||
                        selectedProfileId == null ||
                        !myProfileIds.contains(selectedProfileId)
                    ? null
                    : _createTeacherUnavailabilityBlock,
                icon: const Icon(Icons.add),
                label: const Text('불가 시간 추가'),
              ),
            ],
            const SizedBox(height: 10),
            if (blocks.isEmpty)
              _buildEmptyHint('등록된 불가 시간이 없습니다.')
            else
              ...blocks.map((block) {
                final day = _dayLabel(block.dayOfWeek);
                final start = _shortTime(block.startTime);
                final end = _shortTime(block.endTime);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('$day $start-$end'),
                  subtitle: Text(block.note),
                  trailing: IconButton(
                    onPressed: controller.isBusy
                        ? null
                        : () => _deleteUnavailabilityBlock(block.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.access_time),
      ),
    );
  }

  String _teacherLabelForSession({
    required NestController controller,
    required String sessionId,
    required List<SessionTeacherAssignment> assignments,
  }) {
    final rows =
        assignments
            .where((row) => row.classSessionId == sessionId)
            .toList(growable: false)
          ..sort((a, b) {
            final left = a.assignmentRole == 'MAIN' ? 0 : 1;
            final right = b.assignmentRole == 'MAIN' ? 0 : 1;
            if (left != right) {
              return left.compareTo(right);
            }
            return controller
                .findTeacherName(a.teacherProfileId)
                .compareTo(controller.findTeacherName(b.teacherProfileId));
          });

    if (rows.isEmpty) {
      return '담당교사 미지정';
    }

    return rows
        .map((row) {
          final name = controller.findTeacherName(row.teacherProfileId);
          return row.assignmentRole == 'MAIN' ? '주강사 $name' : '보조 $name';
        })
        .join(', ');
  }

  Widget _buildEmptyHint(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.roseMist.withValues(alpha: 0.36),
      ),
      child: Text(message),
    );
  }

  String _sessionTitle(NestController controller, ClassSession session) {
    return session.title.isEmpty
        ? controller.findCourseName(session.courseId)
        : session.title;
  }

  Future<void> _selectManagedClass(
    List<_TeacherClassBundle> managedClasses,
  ) async {
    final options = managedClasses
        .map(
          (bundle) => SelectSheetOption<String>(
            value: bundle.classGroup.id,
            title: bundle.classGroup.name,
            subtitle:
                '수업 ${bundle.sessions.length}개 · 아동 ${bundle.children.length}명',
            keywords: bundle.classGroup.name,
          ),
        )
        .toList(growable: false);
    final selected = await showSelectSheet<String>(
      context: context,
      title: '담당 반 선택',
      helpText: '운영할 반을 선택하면 하단 정보가 즉시 갱신됩니다.',
      options: options,
      currentValue: _selectedManagedClassGroupId,
    );
    if (!mounted ||
        selected == null ||
        selected == _selectedManagedClassGroupId) {
      return;
    }
    setState(() {
      _selectedManagedClassGroupId = selected;
    });
  }

  Future<void> _selectPlanSession(
    NestController controller,
    List<ClassSession> sessions,
  ) async {
    final options = sessions
        .map(
          (session) => SelectSheetOption<String>(
            value: session.id,
            title: _sessionTitle(controller, session),
            subtitle: session.id,
            keywords:
                '${_sessionTitle(controller, session)} ${controller.findCourseName(session.courseId)}',
          ),
        )
        .toList(growable: false);
    final selected = await showSelectSheet<String>(
      context: context,
      title: '수업 세션 선택',
      helpText: '수업 계획을 작성할 세션을 선택하세요.',
      options: options,
      currentValue: _planSessionId,
    );
    if (!mounted || selected == null || selected == _planSessionId) {
      return;
    }
    setState(() {
      _planSessionId = selected;
    });
  }

  Future<void> _selectPlanTeacher(
    List<TeacherProfile> teacherCandidates,
  ) async {
    final options = teacherCandidates
        .map(
          (teacher) => SelectSheetOption<String>(
            value: teacher.id,
            title: teacher.displayName,
            subtitle: teacher.teacherType,
            keywords: '${teacher.displayName} ${teacher.teacherType}',
          ),
        )
        .toList(growable: false);
    final selected = await showSelectSheet<String>(
      context: context,
      title: '작성 교사 선택',
      helpText: '계획 기록자로 표시할 교사를 선택하세요.',
      options: options,
      currentValue: _planTeacherProfileId,
    );
    if (!mounted || selected == null || selected == _planTeacherProfileId) {
      return;
    }
    setState(() {
      _planTeacherProfileId = selected;
    });
  }

  Future<void> _selectLogChild(List<ChildProfile> children) async {
    final options = children
        .map(
          (child) => SelectSheetOption<String>(
            value: child.id,
            title: child.name,
            subtitle: child.familyName,
            keywords: '${child.name} ${child.familyName}',
          ),
        )
        .toList(growable: false);
    final selected = await showSelectSheet<String>(
      context: context,
      title: '아이 선택',
      helpText: '상태 기록을 남길 아이를 선택하세요.',
      options: options,
      currentValue: _logChildId,
    );
    if (!mounted || selected == null || selected == _logChildId) {
      return;
    }
    setState(() {
      _logChildId = selected;
    });
  }

  Future<void> _selectLogSession(
    NestController controller,
    _TeacherClassBundle? selectedBundle,
  ) async {
    final options = <SelectSheetOption<String>>[
      const SelectSheetOption<String>(
        value: '__NONE__',
        title: '세션 미지정',
        subtitle: '특정 수업에 연결하지 않습니다.',
      ),
      ...(selectedBundle?.sessions ?? const <ClassSession>[]).map(
        (session) => SelectSheetOption<String>(
          value: session.id,
          title: _sessionTitle(controller, session),
          subtitle: session.id,
          keywords:
              '${_sessionTitle(controller, session)} ${controller.findCourseName(session.courseId)}',
        ),
      ),
    ];

    final selected = await showSelectSheet<String>(
      context: context,
      title: '연결 수업 선택',
      helpText: '상태 기록과 연결할 수업을 선택하세요.',
      options: options,
      currentValue: _logSessionId ?? '__NONE__',
    );
    if (!mounted || selected == null) {
      return;
    }
    final nextValue = selected == '__NONE__' ? null : selected;
    if (nextValue == _logSessionId) {
      return;
    }
    setState(() {
      _logSessionId = nextValue;
    });
  }

  Future<void> _selectLogTeacher(List<TeacherProfile> teacherCandidates) async {
    final options = teacherCandidates
        .map(
          (teacher) => SelectSheetOption<String>(
            value: teacher.id,
            title: teacher.displayName,
            subtitle: teacher.teacherType,
            keywords: '${teacher.displayName} ${teacher.teacherType}',
          ),
        )
        .toList(growable: false);
    final selected = await showSelectSheet<String>(
      context: context,
      title: '기록 교사 선택',
      helpText: '상태 기록을 작성하는 교사 프로필을 선택하세요.',
      options: options,
      currentValue: _logTeacherProfileId,
    );
    if (!mounted || selected == null || selected == _logTeacherProfileId) {
      return;
    }
    setState(() {
      _logTeacherProfileId = selected;
    });
  }

  Future<void> _selectLogActivityType() async {
    const options = <SelectSheetOption<String>>[
      SelectSheetOption<String>(
        value: 'ATTENDANCE',
        title: '출결',
        subtitle: '출석/지각/결석 상태를 기록합니다.',
      ),
      SelectSheetOption<String>(
        value: 'OBSERVATION',
        title: '관찰',
        subtitle: '학습 태도와 정서 관찰을 기록합니다.',
      ),
      SelectSheetOption<String>(
        value: 'ASSIGNMENT',
        title: '과제',
        subtitle: '과제 수행/피드백 내용을 기록합니다.',
      ),
    ];
    final selected = await showSelectSheet<String>(
      context: context,
      title: '활동 유형 선택',
      helpText: '기록의 성격에 맞는 활동 유형을 고르세요.',
      options: options,
      currentValue: _logActivityType,
    );
    if (!mounted || selected == null || selected == _logActivityType) {
      return;
    }
    setState(() {
      _logActivityType = selected;
    });
  }

  Future<void> _selectUnavailabilityTeacherProfile(
    List<TeacherProfile> profiles,
  ) async {
    final options = profiles
        .map(
          (profile) => SelectSheetOption<String>(
            value: profile.id,
            title: profile.displayName,
            subtitle: profile.teacherType,
            keywords: '${profile.displayName} ${profile.teacherType}',
          ),
        )
        .toList(growable: false);
    final selected = await showSelectSheet<String>(
      context: context,
      title: '교사 프로필 선택',
      helpText: '불가 시간을 적용할 교사 프로필을 선택하세요.',
      options: options,
      currentValue: _unavailabilityTeacherProfileId,
    );
    if (!mounted ||
        selected == null ||
        selected == _unavailabilityTeacherProfileId) {
      return;
    }
    setState(() {
      _unavailabilityTeacherProfileId = selected;
    });
  }

  Future<void> _createTeachingPlan() async {
    final sessionId = _planSessionId;
    final teacherId = _planTeacherProfileId;
    if (sessionId == null || teacherId == null) {
      _showMessage('세션/교사를 선택하세요.');
      return;
    }

    try {
      await widget.controller.createTeachingPlan(
        classSessionId: sessionId,
        teacherProfileId: teacherId,
        objectives: _planObjectivesController.text,
        materials: _planMaterialsController.text,
        activities: _planActivitiesController.text,
      );
      _planObjectivesController.clear();
      _planMaterialsController.clear();
      _planActivitiesController.clear();
      await _loadManagedClassBundles();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _createActivityLog() async {
    final childId = _logChildId;
    final teacherId = _logTeacherProfileId;
    if (childId == null || teacherId == null) {
      _showMessage('아이/교사를 선택하세요.');
      return;
    }

    try {
      await widget.controller.createStudentActivityLog(
        childId: childId,
        classSessionId: _logSessionId,
        teacherProfileId: teacherId,
        activityType: _logActivityType,
        content: _logContentController.text,
      );
      _logContentController.clear();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _createAnnouncement() async {
    final classGroupId = _selectedManagedClassGroupId;
    if (classGroupId == null || classGroupId.isEmpty) {
      _showMessage('반을 먼저 선택하세요.');
      return;
    }

    try {
      await widget.controller.createAnnouncement(
        title: _announceTitleController.text,
        body: _announceBodyController.text,
        classGroupId: classGroupId,
        pinned: _announcePinned,
      );
      _announceTitleController.clear();
      _announceBodyController.clear();
      setState(() {
        _announcePinned = false;
      });
      await _loadManagedClassBundles();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _createTeacherUnavailabilityBlock() async {
    final profileId = _unavailabilityTeacherProfileId;
    if (profileId == null || profileId.isEmpty) {
      _showMessage('교사 프로필을 선택하세요.');
      return;
    }

    try {
      await widget.controller.createMemberUnavailabilityBlock(
        ownerKind: 'TEACHER_PROFILE',
        ownerId: profileId,
        dayOfWeek: _selectedUnavailabilityDay,
        startTime: _unavailabilityStartController.text,
        endTime: _unavailabilityEndController.text,
        note: _unavailabilityNoteController.text,
      );
      _unavailabilityNoteController.clear();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _deleteUnavailabilityBlock(String blockId) async {
    try {
      await widget.controller.deleteMemberUnavailabilityBlock(blockId: blockId);
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  String _dayLabel(int dayOfWeek) {
    const labels = <int, String>{
      0: 'Sun',
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
    };
    return labels[dayOfWeek] ?? '$dayOfWeek';
  }

  String _shortTime(String value) {
    final parsed = DateFormat('HH:mm:ss').tryParse(value);
    if (parsed == null) {
      final fallback = DateFormat('HH:mm').tryParse(value);
      return fallback == null ? value : DateFormat('HH:mm').format(fallback);
    }
    return DateFormat('HH:mm').format(parsed);
  }

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _TeacherClassBundle {
  const _TeacherClassBundle({
    required this.classGroup,
    required this.sessions,
    required this.assignments,
    required this.plans,
    required this.announcements,
    required this.children,
  });

  final ClassGroup classGroup;
  final List<ClassSession> sessions;
  final List<SessionTeacherAssignment> assignments;
  final List<TeachingPlan> plans;
  final List<Announcement> announcements;
  final List<ChildProfile> children;
}

extension _FirstOrNullList<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension _FirstOrNullIterable<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
