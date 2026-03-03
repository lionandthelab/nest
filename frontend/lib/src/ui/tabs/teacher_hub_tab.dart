import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/hub_scaffold.dart';

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
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'managed-class-${_selectedManagedClassGroupId ?? ''}',
                ),
                initialValue: _selectedManagedClassGroupId,
                decoration: const InputDecoration(
                  labelText: '담당 반 선택',
                  prefixIcon: Icon(Icons.groups_2_outlined),
                ),
                items: managedClasses
                    .map(
                      (bundle) => DropdownMenuItem<String>(
                        value: bundle.classGroup.id,
                        child: Text(bundle.classGroup.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  setState(() {
                    _selectedManagedClassGroupId = value;
                  });
                },
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

    final sessionItems = sessions
        .map(
          (session) => DropdownMenuItem<String>(
            value: session.id,
            child: Text(
              session.title.isEmpty
                  ? controller.findCourseName(session.courseId)
                  : session.title,
            ),
          ),
        )
        .toList(growable: false);
    final teacherItems = teacherCandidates
        .map(
          (teacher) => DropdownMenuItem<String>(
            value: teacher.id,
            child: Text(teacher.displayName),
          ),
        )
        .toList(growable: false);

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
            else if (sessionItems.isEmpty || teacherItems.isEmpty)
              _buildEmptyHint('수업 세션/교사 프로필 데이터가 필요합니다.')
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _planSessionId,
                decoration: const InputDecoration(
                  labelText: '수업 세션',
                  prefixIcon: Icon(Icons.class_outlined),
                ),
                items: sessionItems,
                onChanged: controller.isBusy
                    ? null
                    : (value) => setState(() => _planSessionId = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _planTeacherProfileId,
                decoration: const InputDecoration(
                  labelText: '작성 교사',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: teacherItems,
                onChanged: controller.isBusy
                    ? null
                    : (value) => setState(() => _planTeacherProfileId = value),
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

    final sessionItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '__NONE__', child: Text('세션 미지정')),
      ...(selectedBundle?.sessions ?? const <ClassSession>[]).map(
        (session) => DropdownMenuItem<String>(
          value: session.id,
          child: Text(
            session.title.isEmpty
                ? controller.findCourseName(session.courseId)
                : session.title,
          ),
        ),
      ),
    ];

    final teacherCandidates = controller.currentUserTeacherProfiles.isNotEmpty
        ? controller.currentUserTeacherProfiles
        : controller.teacherProfiles;

    final teacherItems = teacherCandidates
        .map(
          (teacher) => DropdownMenuItem<String>(
            value: teacher.id,
            child: Text(teacher.displayName),
          ),
        )
        .toList(growable: false);

    final sessionValue = _logSessionId ?? '__NONE__';

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
            else if (children.isEmpty || teacherItems.isEmpty)
              _buildEmptyHint('아이/교사 데이터가 필요합니다.')
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _logChildId,
                decoration: const InputDecoration(
                  labelText: '아이',
                  prefixIcon: Icon(Icons.child_care_outlined),
                ),
                items: children
                    .map(
                      (child) => DropdownMenuItem<String>(
                        value: child.id,
                        child: Text('${child.name} (${child.familyName})'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: controller.isBusy
                    ? null
                    : (value) => setState(() => _logChildId = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('child-log-session-$sessionValue'),
                initialValue: sessionValue,
                decoration: const InputDecoration(
                  labelText: '연결 수업',
                  prefixIcon: Icon(Icons.class_outlined),
                ),
                items: sessionItems,
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _logSessionId = value == '__NONE__' ? null : value;
                        });
                      },
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _logTeacherProfileId,
                decoration: const InputDecoration(
                  labelText: '기록 교사',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: teacherItems,
                onChanged: controller.isBusy
                    ? null
                    : (value) => setState(() => _logTeacherProfileId = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _logActivityType,
                decoration: const InputDecoration(
                  labelText: '활동 유형',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'ATTENDANCE', child: Text('출결')),
                  DropdownMenuItem(value: 'OBSERVATION', child: Text('관찰')),
                  DropdownMenuItem(value: 'ASSIGNMENT', child: Text('과제')),
                ],
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
                        setState(() {
                          _logActivityType = value;
                        });
                      },
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
              DropdownButtonFormField<String>(
                key: ValueKey('teacher-unavailable-${selectedProfileId ?? ''}'),
                initialValue: selectedProfileId,
                decoration: const InputDecoration(
                  labelText: '교사 프로필',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: myProfiles
                    .map(
                      (profile) => DropdownMenuItem<String>(
                        value: profile.id,
                        child: Text(profile.displayName),
                      ),
                    )
                    .toList(growable: false),
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _unavailabilityTeacherProfileId = value;
                        });
                      },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedUnavailabilityDay,
                      decoration: const InputDecoration(labelText: '요일'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Sun')),
                        DropdownMenuItem(value: 1, child: Text('Mon')),
                        DropdownMenuItem(value: 2, child: Text('Tue')),
                        DropdownMenuItem(value: 3, child: Text('Wed')),
                        DropdownMenuItem(value: 4, child: Text('Thu')),
                        DropdownMenuItem(value: 5, child: Text('Fri')),
                        DropdownMenuItem(value: 6, child: Text('Sat')),
                      ],
                      onChanged: controller.isBusy
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedUnavailabilityDay = value;
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
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
