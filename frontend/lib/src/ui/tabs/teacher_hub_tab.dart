import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  String _sectionId = 'operations';

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
    _syncDefaults(controller);

    return HubScaffold(
      title: 'Teacher Hub',
      subtitle: '수업 운영, 계획 작성, 활동 기록까지 한 화면 흐름으로 처리합니다.',
      icon: Icons.school,
      isBusy: controller.isBusy,
      metrics: [
        HubMetric(
          label: '배정 수업',
          value: '${controller.sessions.length}',
          icon: Icons.view_week,
        ),
        HubMetric(
          label: '수업 계획',
          value: '${controller.teachingPlans.length}',
          icon: Icons.menu_book,
        ),
        HubMetric(
          label: '활동 기록',
          value: '${controller.studentActivityLogs.length}',
          icon: Icons.fact_check,
        ),
      ],
      sections: [
        HubSection(
          id: 'operations',
          label: '수업 운영',
          icon: Icons.tune,
          content: Column(
            children: [
              _buildTeacherUnavailabilityCard(controller),
              const SizedBox(height: 12),
              _buildTeacherAnnouncementCard(controller),
            ],
          ),
        ),
        HubSection(
          id: 'plans',
          label: '계획 작성',
          icon: Icons.edit_note,
          content: _buildTeachingPlanCard(controller),
        ),
        HubSection(
          id: 'logs',
          label: '활동 기록',
          icon: Icons.history_edu,
          content: _buildActivityLogCard(controller),
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

  void _syncDefaults(NestController controller) {
    final sessionIds = controller.sessions.map((row) => row.id).toSet();
    final childIds = controller.children.map((row) => row.id).toSet();
    final teacherIds = controller.teacherProfiles.map((row) => row.id).toSet();
    final myTeacherIds = controller.currentUserTeacherProfiles
        .map((row) => row.id)
        .toSet();

    _planSessionId ??= controller.sessions.firstOrNull?.id;
    _logSessionId ??= controller.sessions.firstOrNull?.id;
    _logChildId ??= controller.children.firstOrNull?.id;
    _planTeacherProfileId ??= controller.defaultTeacherProfileId;
    _logTeacherProfileId ??= controller.defaultTeacherProfileId;
    _unavailabilityTeacherProfileId ??=
        controller.currentUserTeacherProfiles.firstOrNull?.id;

    if (_planSessionId != null && !sessionIds.contains(_planSessionId)) {
      _planSessionId = controller.sessions.firstOrNull?.id;
    }
    if (_logSessionId != null && !sessionIds.contains(_logSessionId)) {
      _logSessionId = controller.sessions.firstOrNull?.id;
    }
    if (_logChildId != null && !childIds.contains(_logChildId)) {
      _logChildId = controller.children.firstOrNull?.id;
    }
    if (_planTeacherProfileId != null &&
        !teacherIds.contains(_planTeacherProfileId)) {
      _planTeacherProfileId = controller.defaultTeacherProfileId;
    }
    if (_logTeacherProfileId != null &&
        !teacherIds.contains(_logTeacherProfileId)) {
      _logTeacherProfileId = controller.defaultTeacherProfileId;
    }
    if (_unavailabilityTeacherProfileId != null &&
        !myTeacherIds.contains(_unavailabilityTeacherProfileId)) {
      _unavailabilityTeacherProfileId =
          controller.currentUserTeacherProfiles.firstOrNull?.id;
    }
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  if (compact) {
                    return Column(
                      children: [
                        _buildDayField(controller),
                        const SizedBox(height: 8),
                        _buildTimeField(
                          controller: _unavailabilityStartController,
                          label: '시작 (HH:MM)',
                        ),
                        const SizedBox(height: 8),
                        _buildTimeField(
                          controller: _unavailabilityEndController,
                          label: '종료 (HH:MM)',
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 3, child: _buildDayField(controller)),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildTimeField(
                          controller: _unavailabilityStartController,
                          label: '시작 (HH:MM)',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildTimeField(
                          controller: _unavailabilityEndController,
                          label: '종료 (HH:MM)',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _unavailabilityNoteController,
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                  prefixIcon: Icon(Icons.edit_note),
                ),
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
            const SizedBox(height: 14),
            Text('등록 항목', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (blocks.isEmpty)
              _buildEmptyHint('등록된 불가 시간이 없습니다.')
            else
              ...blocks.map((block) {
                final day = _dayLabel(block.dayOfWeek);
                final start = _shortTime(block.startTime);
                final end = _shortTime(block.endTime);
                final note = block.note.trim();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NestColors.roseMist),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.schedule),
                      title: Text('$day · $start - $end'),
                      subtitle: note.isEmpty ? null : Text(note),
                      trailing: IconButton(
                        onPressed: controller.isBusy
                            ? null
                            : () => _deleteUnavailabilityBlock(block.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTeachingPlanCard(NestController controller) {
    final sessionItems = controller.sessions
        .map(
          (session) => DropdownMenuItem(
            value: session.id,
            child: Text(
              session.title.isEmpty
                  ? controller.findCourseName(session.courseId)
                  : session.title,
            ),
          ),
        )
        .toList(growable: false);

    final teacherItems = controller.teacherProfiles
        .map(
          (teacher) => DropdownMenuItem(
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
            Text('수업 계획 등록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (sessionItems.isEmpty || teacherItems.isEmpty)
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
            const SizedBox(height: 14),
            Text('최근 수업 계획', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (controller.teachingPlans.isEmpty)
              _buildEmptyHint('등록된 계획이 없습니다.')
            else
              ...controller.teachingPlans.take(20).map((plan) {
                final sessionName =
                    controller.sessions
                        .where((session) => session.id == plan.classSessionId)
                        .map(
                          (session) => session.title.isEmpty
                              ? controller.findCourseName(session.courseId)
                              : session.title,
                        )
                        .firstOrNull ??
                    plan.classSessionId;
                final teacherName = controller.findTeacherName(
                  plan.teacherProfileId,
                );
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.menu_book_outlined, size: 18),
                  title: Text('$sessionName · $teacherName'),
                  subtitle: Text(plan.objectives),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityLogCard(NestController controller) {
    final childItems = controller.children
        .map(
          (child) => DropdownMenuItem(
            value: child.id,
            child: Text('${child.name} (${child.familyName})'),
          ),
        )
        .toList(growable: false);
    final sessionItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '__NONE__', child: Text('세션 미지정')),
      ...controller.sessions.map(
        (session) => DropdownMenuItem(
          value: session.id,
          child: Text(
            session.title.isEmpty
                ? controller.findCourseName(session.courseId)
                : session.title,
          ),
        ),
      ),
    ];
    final teacherItems = controller.teacherProfiles
        .map(
          (teacher) => DropdownMenuItem(
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
            Text('아동 활동 기록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (childItems.isEmpty || teacherItems.isEmpty)
              _buildEmptyHint('아이/교사 데이터가 필요합니다.')
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _logChildId,
                decoration: const InputDecoration(
                  labelText: '아이',
                  prefixIcon: Icon(Icons.child_care_outlined),
                ),
                items: childItems,
                onChanged: controller.isBusy
                    ? null
                    : (value) => setState(() => _logChildId = value),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(sessionValue),
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
            const SizedBox(height: 14),
            Text('최근 활동 기록', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (controller.studentActivityLogs.isEmpty)
              _buildEmptyHint('등록된 활동 기록이 없습니다.')
            else
              ...controller.studentActivityLogs.take(24).map((log) {
                final childName =
                    controller.children
                        .where((child) => child.id == log.childId)
                        .map((child) => child.name)
                        .firstOrNull ??
                    log.childId;
                final teacherName = controller.findTeacherName(
                  log.recordedByTeacherId,
                );
                final when = log.recordedAt == null
                    ? '-'
                    : DateFormat('MM-dd HH:mm').format(log.recordedAt!);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history, size: 18),
                  title: Text(
                    '$childName · ${log.activityType} · $teacherName',
                  ),
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

  Widget _buildTeacherAnnouncementCard(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('교사 공지 작성', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
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
        ),
      ),
    );
  }

  Widget _buildDayField(NestController controller) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedUnavailabilityDay,
      decoration: const InputDecoration(
        labelText: '요일',
        prefixIcon: Icon(Icons.calendar_today_outlined),
      ),
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
    try {
      await widget.controller.createAnnouncement(
        title: _announceTitleController.text,
        body: _announceBodyController.text,
        classGroupId: widget.controller.selectedClassGroupId,
        pinned: _announcePinned,
      );
      _announceTitleController.clear();
      _announceBodyController.clear();
      setState(() {
        _announcePinned = false;
      });
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

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

extension _FirstOrNullIterable<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
