import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/hub_scaffold.dart';

class ParentHubTab extends StatefulWidget {
  const ParentHubTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<ParentHubTab> createState() => _ParentHubTabState();
}

class _ParentHubTabState extends State<ParentHubTab> {
  final _unavailabilityStartController = TextEditingController(text: '09:00');
  final _unavailabilityEndController = TextEditingController(text: '10:00');
  final _unavailabilityNoteController = TextEditingController();

  int _selectedUnavailabilityDay = 1;
  String _sectionId = 'children';
  String? _selectedChildId;
  String? _lastScheduledChildLoadId;
  bool _isLoadingChildClasses = false;
  Map<String, _ChildClassBundle> _childClassBundles = const {};

  @override
  void dispose() {
    _unavailabilityStartController.dispose();
    _unavailabilityEndController.dispose();
    _unavailabilityNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final myChildren = controller.myChildren.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));

    _syncSelectedChild(myChildren);

    final selectedChild = myChildren
        .where((child) => child.id == _selectedChildId)
        .firstOrNull;
    final childLogs =
        selectedChild == null
              ? const <StudentActivityLog>[]
              : controller
                    .activityLogsForChild(selectedChild.id)
                    .toList(growable: false)
          ..sort((a, b) {
            final left = a.recordedAt?.millisecondsSinceEpoch ?? 0;
            final right = b.recordedAt?.millisecondsSinceEpoch ?? 0;
            return right.compareTo(left);
          });

    final enrolledClassCount = _childClassBundles.length;
    final enrolledSessionCount = _childClassBundles.values
        .map((bundle) => bundle.sessions.length)
        .fold<int>(0, (acc, value) => acc + value);

    return HubScaffold(
      title: 'Parent Hub',
      subtitle: '내 아이를 기준으로 반 배정, 시간표, 최근 상태를 확인합니다.',
      icon: Icons.family_restroom,
      isBusy: controller.isBusy || _isLoadingChildClasses,
      metrics: [
        HubMetric(
          label: '내 아이',
          value: '${myChildren.length}',
          icon: Icons.child_care,
        ),
        HubMetric(
          label: '배정 반',
          value: '$enrolledClassCount',
          icon: Icons.groups,
        ),
        HubMetric(
          label: '시간표 수업',
          value: '$enrolledSessionCount',
          icon: Icons.view_week,
        ),
      ],
      sections: [
        HubSection(
          id: 'children',
          label: '아이 정보',
          icon: Icons.badge,
          content: _buildChildOverviewCard(
            controller: controller,
            children: myChildren,
            selectedChild: selectedChild,
            childLogs: childLogs,
          ),
        ),
        HubSection(
          id: 'timetable',
          label: '아이 시간표',
          icon: Icons.calendar_view_week,
          content: _buildChildTimetableCard(controller, selectedChild),
        ),
        HubSection(
          id: 'status',
          label: '아이 상태',
          icon: Icons.monitor_heart_outlined,
          content: _buildChildStatusCard(controller, selectedChild, childLogs),
        ),
        HubSection(
          id: 'availability',
          label: '내 불가 시간',
          icon: Icons.block,
          content: _buildMyUnavailabilityCard(controller),
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

  void _syncSelectedChild(List<ChildProfile> children) {
    final previous = _selectedChildId;
    final firstId = children.firstOrNull?.id;
    final stillValid =
        previous != null && children.any((child) => child.id == previous);

    if (!stillValid) {
      _selectedChildId = firstId;
      _childClassBundles = const {};
      _lastScheduledChildLoadId = null;
    }

    final selectedId = _selectedChildId;
    if (selectedId == null || selectedId.isEmpty) {
      return;
    }

    if (_lastScheduledChildLoadId == selectedId) {
      return;
    }

    _lastScheduledChildLoadId = selectedId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _loadChildClassBundles(selectedId);
    });
  }

  Future<void> _loadChildClassBundles(String childId) async {
    if (_isLoadingChildClasses) {
      return;
    }

    final controller = widget.controller;
    setState(() {
      _isLoadingChildClasses = true;
    });

    try {
      final classGroups =
          controller.classGroupsForChild(childId).toList(growable: false)
            ..sort((a, b) => a.name.compareTo(b.name));

      final allAnnouncements = await controller
          .fetchAnnouncementsForHomeschool();
      final bundleMap = <String, _ChildClassBundle>{};

      for (final classGroup in classGroups) {
        final sessions = await controller.fetchSessionsForClassGroup(
          classGroupId: classGroup.id,
        );
        final sessionIds = sessions
            .map((session) => session.id)
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
        final assignments = await controller
            .fetchSessionTeacherAssignmentsForSessions(
              classSessionIds: sessionIds,
            );

        final classAnnouncements = allAnnouncements
            .where(
              (row) =>
                  row.classGroupId == null || row.classGroupId == classGroup.id,
            )
            .toList(growable: false);

        bundleMap[classGroup.id] = _ChildClassBundle(
          classGroup: classGroup,
          sessions: sessions,
          assignments: assignments,
          announcements: classAnnouncements,
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _childClassBundles = bundleMap;
      });
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingChildClasses = false;
        });
      }
    }
  }

  Widget _buildChildOverviewCard({
    required NestController controller,
    required List<ChildProfile> children,
    required ChildProfile? selectedChild,
    required List<StudentActivityLog> childLogs,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('내 아이별 뷰', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (children.isEmpty)
              _buildEmptyHint('연결된 아이가 없습니다. 관리자에게 가정/아이 배정을 요청하세요.')
            else ...[
              DropdownButtonFormField<String>(
                key: ValueKey('parent-child-${selectedChild?.id ?? ''}'),
                initialValue: selectedChild?.id,
                decoration: const InputDecoration(
                  labelText: '아이 선택',
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
                onChanged: (value) {
                  setState(() {
                    _selectedChildId = value;
                    _childClassBundles = const {};
                    _lastScheduledChildLoadId = null;
                  });
                },
              ),
              if (selectedChild != null) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.flag_circle_outlined, size: 16),
                      label: Text('상태: ${selectedChild.status}'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.home_outlined, size: 16),
                      label: Text('가정: ${selectedChild.familyName}'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.cake_outlined, size: 16),
                      label: Text(
                        selectedChild.birthDate == null
                            ? '생년월일 미등록'
                            : DateFormat(
                                'yyyy-MM-dd',
                              ).format(selectedChild.birthDate!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('소속 반', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                if (_childClassBundles.isEmpty)
                  _buildEmptyHint('소속 반/시간표를 불러오는 중이거나 배정된 반이 없습니다.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _childClassBundles.values
                        .map(
                          (bundle) => Chip(
                            avatar: const Icon(
                              Icons.groups_2_outlined,
                              size: 16,
                            ),
                            label: Text(
                              '${bundle.classGroup.name} (${bundle.sessions.length}수업)',
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                const SizedBox(height: 12),
                Text('최근 상태', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                if (childLogs.isEmpty)
                  _buildEmptyHint('아직 기록된 상태 로그가 없습니다.')
                else
                  ...childLogs.take(3).map((log) {
                    final when = log.recordedAt == null
                        ? '-'
                        : DateFormat('MM-dd HH:mm').format(log.recordedAt!);
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history, size: 18),
                      title: Text('${log.activityType} · $when'),
                      subtitle: Text(log.content),
                    );
                  }),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChildTimetableCard(
    NestController controller,
    ChildProfile? selectedChild,
  ) {
    if (selectedChild == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildEmptyHint('아이를 먼저 선택하세요.'),
        ),
      );
    }

    if (_childClassBundles.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildEmptyHint('이 아이의 반 시간표가 없습니다.'),
        ),
      );
    }

    final bundles = _childClassBundles.values.toList(growable: false)
      ..sort((a, b) => a.classGroup.name.compareTo(b.classGroup.name));

    return Column(
      children: bundles
          .map((bundle) {
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

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bundle.classGroup.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      if (sessions.isEmpty)
                        _buildEmptyHint('등록된 수업이 없습니다.')
                      else
                        ...sessions.map((session) {
                          final slot = controller.findTimeSlot(
                            session.timeSlotId,
                          );
                          final teachers = _teacherLabelForSession(
                            controller: controller,
                            sessionId: session.id,
                            assignments: bundle.assignments,
                          );
                          final slotLabel = slot == null
                              ? session.timeSlotId
                              : '${_dayLabel(slot.dayOfWeek)} ${_shortTime(slot.startTime)}-${_shortTime(slot.endTime)}';

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
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text('$slotLabel · $teachers'),
                              ],
                            ),
                          );
                        }),
                      const SizedBox(height: 4),
                      Text(
                        '공지 ${bundle.announcements.length}건',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildChildStatusCard(
    NestController controller,
    ChildProfile? selectedChild,
    List<StudentActivityLog> logs,
  ) {
    if (selectedChild == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildEmptyHint('아이를 먼저 선택하세요.'),
        ),
      );
    }

    final countsByType = <String, int>{};
    for (final log in logs) {
      countsByType[log.activityType] =
          (countsByType[log.activityType] ?? 0) + 1;
    }

    final sessionClassNameById = <String, String>{};
    for (final bundle in _childClassBundles.values) {
      for (final session in bundle.sessions) {
        sessionClassNameById[session.id] = bundle.classGroup.name;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('아이 상태 기록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('총 기록 ${logs.length}건')),
                ...countsByType.entries.map(
                  (entry) => Chip(label: Text('${entry.key} ${entry.value}건')),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (logs.isEmpty)
              _buildEmptyHint('등록된 상태 로그가 없습니다.')
            else
              ...logs.take(40).map((log) {
                final when = log.recordedAt == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd HH:mm').format(log.recordedAt!);
                final className = log.classSessionId == null
                    ? '세션 미지정'
                    : sessionClassNameById[log.classSessionId!] ?? '연결 반 확인 필요';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NestColors.roseMist),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${log.activityType} · $className',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(log.content),
                        const SizedBox(height: 4),
                        Text(
                          '$when · ${controller.findTeacherName(log.recordedByTeacherId)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildMyUnavailabilityCard(NestController controller) {
    final currentUserId = controller.user?.id;
    final blocks =
        controller.memberUnavailabilityBlocks
            .where(
              (row) =>
                  row.ownerKind == 'MEMBER_USER' &&
                  currentUserId != null &&
                  row.ownerId == currentUserId,
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
            Text('내 불가 시간 설정', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '등록한 시간은 시간표 생성 시 자동으로 회피됩니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            if (currentUserId == null)
              _buildEmptyHint('로그인 정보를 확인할 수 없습니다.')
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 740;
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
                onPressed: controller.isBusy
                    ? null
                    : () => _createParentUnavailabilityBlock(currentUserId),
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
          final teacherName = controller.findTeacherName(row.teacherProfileId);
          return row.assignmentRole == 'MAIN'
              ? '주강사 $teacherName'
              : '보조 $teacherName';
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

  Future<void> _createParentUnavailabilityBlock(String userId) async {
    try {
      await widget.controller.createMemberUnavailabilityBlock(
        ownerKind: 'MEMBER_USER',
        ownerId: userId,
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

class _ChildClassBundle {
  const _ChildClassBundle({
    required this.classGroup,
    required this.sessions,
    required this.assignments,
    required this.announcements,
  });

  final ClassGroup classGroup;
  final List<ClassSession> sessions;
  final List<SessionTeacherAssignment> assignments;
  final List<Announcement> announcements;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
