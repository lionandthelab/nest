import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/entity_visuals.dart';
import '../widgets/nest_empty_state.dart';

class FamilyAdminTab extends StatefulWidget {
  const FamilyAdminTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<FamilyAdminTab> createState() => _FamilyAdminTabState();
}

class _FamilyAdminTabState extends State<FamilyAdminTab> {
  String? _selectedFamilyId;
  String? _selectedClassGroupId;
  String? _selectedCourseId;
  String? _selectedClassroomId;
  bool _familyInitialized = false;
  bool _classInitialized = false;
  bool _courseInitialized = false;
  bool _classroomInitialized = false;
  String _setupUnit = 'FAMILY';

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    _syncSelections(controller);

    if (!controller.canManageFamilies) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('학기 설정', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('가정/아이 배정 관리는 관리자/스태프만 사용할 수 있습니다.'),
            ],
          ),
        ),
      );
    }

    final pendingChildReqs = controller.childRegistrationRequests
        .where((r) => r.isPending)
        .toList();

    final unitCards = switch (_setupUnit) {
      'FAMILY' => [
        if (pendingChildReqs.isNotEmpty) ...[
          _buildChildRegistrationRequestsCard(controller, pendingChildReqs),
          const SizedBox(height: 12),
        ],
        _buildFamilyManagementCard(controller),
        const SizedBox(height: 12),
        _buildChildManagementCard(controller),
      ],
      'TEACHER' => [_buildTeacherManagementCard(controller)],
      'CLASS' => [_buildClassCrudCard(controller)],
      'COURSE' => [_buildCourseManageCard(controller)],
      'CLASSROOM' => [_buildClassroomManageCard(controller)],
      _ => [_buildFamilyManagementCard(controller)],
    };

    return ListView(
      children: [
        _buildTermSetupHeaderCard(controller),
        const SizedBox(height: 12),
        ...unitCards,
      ],
    );
  }

  Widget _buildTermSetupHeaderCard(NestController controller) {
    final familyDone =
        controller.families.isNotEmpty && controller.children.isNotEmpty;
    final teacherDone = controller.teacherProfiles.isNotEmpty;
    final classDone =
        controller.classGroups.isNotEmpty &&
        controller.classEnrollments.isNotEmpty;
    final courseDone = controller.courses.isNotEmpty;
    final classroomDone = controller.classrooms.isNotEmpty;
    final completed = [
      familyDone,
      teacherDone,
      classDone,
      courseDone,
      classroomDone,
    ].where((done) => done).length;
    final guardianCount = controller.familyGuardianUserIdsByFamily.values
        .expand((rows) => rows)
        .toSet()
        .length;

    Widget stepChip({
      required int order,
      required String title,
      required bool done,
      required String key,
    }) {
      final selected = _setupUnit == key;
      return ChoiceChip(
        label: Text('$order. $title'),
        selected: selected,
        onSelected: controller.isBusy
            ? null
            : (_) {
                setState(() {
                  _setupUnit = key;
                });
              },
        avatar: done
            ? const Icon(Icons.check_circle, size: 16)
            : Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 16,
              ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('학기 설정', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '가정, 선생님, 반, 과목, 교실을 단위별로 설정한 뒤 시간표 탭에서 배치하세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            _buildSetupSummaryGrid(
              stats: [
                _SetupStat(
                  title: '가정',
                  value: controller.families.length,
                  unit: '가정',
                  subtitle: '운영 중인 가정',
                  icon: Icons.home_work_outlined,
                  accent: NestColors.dustyRose,
                ),
                _SetupStat(
                  title: '아이',
                  value: controller.children.length,
                  unit: '명',
                  subtitle: '전체 아동',
                  icon: Icons.child_friendly_outlined,
                  accent: NestColors.mutedSage,
                ),
                _SetupStat(
                  title: '학부모',
                  value: guardianCount,
                  unit: '명',
                  subtitle: '연결된 보호자',
                  icon: Icons.family_restroom_outlined,
                  accent: NestColors.clay,
                ),
                _SetupStat(
                  title: '선생님',
                  value: controller.teacherProfiles.length,
                  unit: '명',
                  subtitle: '배정 가능한 교사',
                  icon: Icons.school_outlined,
                  accent: NestColors.deepWood,
                ),
                _SetupStat(
                  title: '반',
                  value: controller.classGroups.length,
                  unit: '반',
                  subtitle: '운영 클래스',
                  icon: Icons.groups_2_outlined,
                  accent: NestColors.dustyRose,
                ),
                _SetupStat(
                  title: '과목',
                  value: controller.courses.length,
                  unit: '개',
                  subtitle: '등록 과목',
                  icon: Icons.menu_book_outlined,
                  accent: NestColors.mutedSage,
                ),
                _SetupStat(
                  title: '교실',
                  value: controller.classrooms.length,
                  unit: '개',
                  subtitle: '사용 교실',
                  icon: Icons.meeting_room_outlined,
                  accent: NestColors.clay,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: completed / 5,
                color: NestColors.dustyRose,
                backgroundColor: NestColors.roseMist,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '완료 $completed / 5',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                stepChip(
                  order: 1,
                  title: '가정',
                  done: familyDone,
                  key: 'FAMILY',
                ),
                stepChip(
                  order: 2,
                  title: '선생님',
                  done: teacherDone,
                  key: 'TEACHER',
                ),
                stepChip(order: 3, title: '반', done: classDone, key: 'CLASS'),
                stepChip(
                  order: 4,
                  title: '과목',
                  done: courseDone,
                  key: 'COURSE',
                ),
                stepChip(
                  order: 5,
                  title: '교실',
                  done: classroomDone,
                  key: 'CLASSROOM',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _syncSelections(NestController controller) {
    final familyIds = controller.families.map((row) => row.id).toSet();
    final classIds = controller.classGroups.map((row) => row.id).toSet();
    final courseIds = controller.courses.map((row) => row.id).toSet();
    final classroomIds = controller.classrooms.map((row) => row.id).toSet();

    if (!_familyInitialized) {
      _selectedFamilyId = controller.families.firstOrNull?.id;
      _familyInitialized = true;
    }
    if (_selectedFamilyId != null && !familyIds.contains(_selectedFamilyId)) {
      _selectedFamilyId = controller.families.firstOrNull?.id;
    }

    if (!_classInitialized) {
      _selectedClassGroupId =
          controller.selectedClassGroupId ??
          controller.classGroups.firstOrNull?.id;
      _classInitialized = true;
    }
    if (_selectedClassGroupId != null &&
        !classIds.contains(_selectedClassGroupId)) {
      _selectedClassGroupId =
          controller.selectedClassGroupId ??
          controller.classGroups.firstOrNull?.id;
    }

    if (!_courseInitialized) {
      _selectedCourseId = controller.courses.firstOrNull?.id;
      _courseInitialized = true;
    }
    if (_selectedCourseId != null && !courseIds.contains(_selectedCourseId)) {
      _selectedCourseId = controller.courses.firstOrNull?.id;
    }

    if (!_classroomInitialized) {
      _selectedClassroomId = controller.classrooms.firstOrNull?.id;
      _classroomInitialized = true;
    }
    if (_selectedClassroomId != null &&
        !classroomIds.contains(_selectedClassroomId)) {
      _selectedClassroomId = controller.classrooms.firstOrNull?.id;
    }
  }

  Widget _buildChildRegistrationRequestsCard(
    NestController controller,
    List<ChildRegistrationRequest> requests,
  ) {
    return Card(
      color: NestColors.roseMist.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.child_care, size: 20, color: NestColors.clay),
                const SizedBox(width: 8),
                Text(
                  '아이 등록 요청 (${requests.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '부모가 아이 등록을 요청했습니다. 승인하면 가정과 아이가 자동으로 생성됩니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            ...requests.map((req) {
              final created = req.createdAt == null
                  ? '-'
                  : DateFormat('yyyy-MM-dd HH:mm').format(req.createdAt!);
              final birth = req.birthDate == null
                  ? '미등록'
                  : DateFormat('yyyy-MM-dd').format(req.birthDate!);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NestColors.roseMist),
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '아이: ${req.childName}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '가정: ${req.familyName}  ·  생일: $birth',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '요청일: $created',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: controller.isBusy
                              ? null
                              : () async {
                                  try {
                                    await controller.rejectChildRegistration(
                                      requestId: req.id,
                                    );
                                    _showMessage(controller.statusMessage);
                                  } catch (_) {
                                    _showMessage(controller.statusMessage);
                                  }
                                },
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('거절'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: controller.isBusy
                              ? null
                              : () async {
                                  try {
                                    await controller.approveChildRegistration(
                                      requestId: req.id,
                                    );
                                    _showMessage(controller.statusMessage);
                                  } catch (_) {
                                    _showMessage(controller.statusMessage);
                                  }
                                },
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('승인'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyManagementCard(NestController controller) {
    final families = controller.families.toList()
      ..sort((a, b) => a.familyName.compareTo(b.familyName));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '가정 관리',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _buildSectionCountBadge(
                        value: families.length,
                        unit: '가정',
                        icon: Icons.home_work_outlined,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () => _openFamilyEditorDialog(controller: controller),
                  icon: const Icon(Icons.group_add),
                  label: const Text('가정 추가'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy ? null : _refreshFamilyDomain,
                  icon: const Icon(Icons.refresh),
                  label: const Text('새로고침'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '카드를 클릭하면 가정 정보 수정으로 바로 이동합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            if (families.isEmpty)
              _buildEmptyHint('등록된 가정이 없습니다. 가정 추가로 시작하세요.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: families
                    .map((family) {
                      final childCount = controller
                          .childrenForFamily(family.id)
                          .length;
                      final selected = _selectedFamilyId == family.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: controller.isBusy
                            ? null
                            : () {
                                setState(() {
                                  _selectedFamilyId = family.id;
                                });
                                _openFamilyEditorDialog(
                                  controller: controller,
                                  initial: family,
                                );
                              },
                        child: SizedBox(
                          width: 300,
                          child: LabeledEntityTile(
                            title: family.familyName,
                            subtitle:
                                '아이 $childCount명'
                                '${family.note.trim().isEmpty ? '' : ' · ${family.note.trim()}'}',
                            icon: Icons.home_outlined,
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.edit_outlined,
                              size: 18,
                              color: selected
                                  ? NestColors.mutedSage
                                  : NestColors.deepWood.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilySelectionCards({
    required NestController controller,
    required String title,
    required String? selectedFamilyId,
    required ValueChanged<String> onSelect,
  }) {
    final families = controller.families.toList()
      ..sort((a, b) => a.familyName.compareTo(b.familyName));

    if (families.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: families.map((family) {
        final selected = family.id == selectedFamilyId;
        final childCount =
            controller.childrenForFamily(family.id).length;
        return ChoiceChip(
          label: Text(
            '${family.familyName} ($childCount)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          selected: selected,
          onSelected: controller.isBusy
              ? null
              : (_) => onSelect(family.id),
          avatar: const Icon(Icons.home_outlined, size: 18),
        );
      }).toList(),
    );
  }

  Widget _buildChildManagementCard(NestController controller) {
    final selectedFamily = controller.families
        .where((row) => row.id == _selectedFamilyId)
        .firstOrNull;
    final familyChildren =
        (selectedFamily == null
                ? const <ChildProfile>[]
                : controller.childrenForFamily(selectedFamily.id))
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '아이 관리',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _buildSectionCountBadge(
                        value: controller.children.length,
                        unit: '명',
                        icon: Icons.child_friendly_outlined,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.isBusy || controller.families.isEmpty
                      ? null
                      : () => _openChildEditorDialog(
                          controller: controller,
                          initialFamilyId:
                              _selectedFamilyId ?? controller.families.first.id,
                        ),
                  icon: const Icon(Icons.child_care_outlined),
                  label: const Text('아이 추가'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '가정을 선택하고 카드를 클릭하면 아이 정보를 바로 수정할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            if (controller.families.isEmpty)
              _buildEmptyHint('먼저 가정을 등록하세요.')
            else ...[
              _buildFamilySelectionCards(
                controller: controller,
                title: '',
                selectedFamilyId: selectedFamily?.id,
                onSelect: (familyId) {
                  if (controller.isBusy) {
                    return;
                  }
                  setState(() {
                    _selectedFamilyId = familyId;
                  });
                },
              ),
              const SizedBox(height: 10),
              if (selectedFamily == null)
                _buildEmptyHint('가정을 선택하세요.')
              else if (familyChildren.isEmpty)
                _buildEmptyHint('선택한 가정에 등록된 아이가 없습니다. 아이 추가를 눌러주세요.')
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: familyChildren
                      .map((child) {
                        final birthLabel = child.birthDate == null
                            ? '생일 미입력'
                            : DateFormat('yyyy-MM-dd').format(child.birthDate!);
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: controller.isBusy
                              ? null
                              : () => _openChildEditorDialog(
                                  controller: controller,
                                  initial: child,
                                ),
                          child: SizedBox(
                            width: 290,
                            child: LabeledEntityTile(
                              title: child.name,
                              subtitle: '$birthLabel · ${_childStatusLabel(child.status)}',
                              icon: Icons.child_care_outlined,
                              trailing: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openFamilyEditorDialog({
    required NestController controller,
    Family? initial,
  }) async {
    final nameController = TextEditingController(
      text: initial?.familyName ?? '',
    );
    final noteController = TextEditingController(text: initial?.note ?? '');
    final accountQueryController = TextEditingController();
    var guardianType = 'GUARDIAN';
    HomeschoolMemberDirectoryEntry? selectedGuardianAccount;
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> saveFamily() async {
                if (isSaving || nameController.text.trim().isEmpty) {
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });

                try {
                  final updatedFamily = initial == null
                      ? await controller.createFamily(
                          familyName: nameController.text,
                          note: noteController.text,
                        )
                      : await controller.updateFamily(
                          familyId: initial.id,
                          familyName: nameController.text,
                          note: noteController.text,
                        );

                  if (mounted) {
                    setState(() {
                      _selectedFamilyId = updatedFamily.id;
                    });
                  }
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              Future<void> connectGuardian() async {
                final target = initial;
                if (target == null) {
                  _showMessage('가정을 먼저 저장한 뒤 학부모 계정을 연결하세요.');
                  return;
                }
                if (selectedGuardianAccount == null) {
                  _showMessage('연결할 학부모 계정을 선택하세요.');
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });
                try {
                  await controller.upsertFamilyGuardian(
                    familyId: target.id,
                    userId: selectedGuardianAccount!.userId,
                    guardianType: guardianType,
                  );
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      selectedGuardianAccount = null;
                      accountQueryController.clear();
                      isSaving = false;
                    });
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              Future<void> disconnectGuardian(String userId) async {
                final target = initial;
                if (target == null || isSaving) {
                  return;
                }
                final label = controller.findMemberDisplayName(userId);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('학부모 연결 해제'),
                    content: Text('"$label" 계정을 이 가정에서 연결 해제할까요?'),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(confirmContext).pop(false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        child: const Text('해제'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) {
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });
                try {
                  await controller.deleteFamilyGuardian(
                    familyId: target.id,
                    userId: userId,
                  );
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              final linkedGuardianUserIds =
                  initial == null
                        ? <String>[]
                        : (controller.familyGuardianUserIdsByFamily[initial
                                          .id] ??
                                      const <String>[])
                                  .toList()
                              ..sort();
              final linkedSet = linkedGuardianUserIds.toSet();
              final parentMatches = controller
                  .searchHomeschoolMemberDirectory(
                    accountQueryController.text,
                    maxResults: 12,
                  )
                  .where(
                    (entry) =>
                        entry.roles.contains('PARENT') &&
                        !linkedSet.contains(entry.userId),
                  )
                  .toList();

              Future<void> deleteFamily() async {
                final target = initial;
                if (target == null || isSaving) {
                  return;
                }

                final childCount = controller
                    .childrenForFamily(target.id)
                    .length;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('가정 삭제'),
                    content: Text(
                      '"${target.familyName}" 가정을 삭제할까요?\n'
                      '소속 아이 $childCount명과 연결된 배정/기록이 함께 정리될 수 있습니다.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(confirmContext).pop(false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) {
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });
                try {
                  await controller.deleteFamily(familyId: target.id);
                  if (mounted) {
                    setState(() {
                      _selectedFamilyId = controller.families.firstOrNull?.id;
                    });
                  }
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: Text(initial == null ? '가정 추가' : '가정 수정'),
                content: SizedBox(
                  width: 640,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: '가정 이름'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteController,
                          decoration: const InputDecoration(labelText: '메모'),
                          minLines: 1,
                          maxLines: 3,
                        ),
                        const SizedBox(height: 12),
                        if (initial == null)
                          _buildEmptyHint('가정을 먼저 생성하면 학부모 계정 연결 기능이 열립니다.')
                        else ...[
                          Text(
                            '학부모 계정 연결',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'PARENT 권한을 가진 계정을 검색해 이 가정에 연결합니다.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: NestColors.deepWood.withValues(
                                    alpha: 0.72,
                                  ),
                                ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: accountQueryController,
                            decoration: const InputDecoration(
                              labelText: '학부모 계정 검색',
                              hintText: '이름, 이메일, UUID',
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          const SizedBox(height: 8),
                          if (parentMatches.isEmpty)
                            _buildEmptyHint('연결 가능한 학부모 계정이 없습니다.')
                          else
                            Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: NestColors.roseMist),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: parentMatches.length,
                                itemBuilder: (context, index) {
                                  final member = parentMatches[index];
                                  final selected =
                                      selectedGuardianAccount?.userId ==
                                      member.userId;
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      selected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      size: 18,
                                    ),
                                    title: Text(
                                      member.fullName.trim().isEmpty
                                          ? member.email
                                          : member.fullName,
                                    ),
                                    subtitle: Text(
                                      member.email.isEmpty
                                          ? member.userId
                                          : member.email,
                                    ),
                                    onTap: isSaving
                                        ? null
                                        : () {
                                            setDialogState(() {
                                              selectedGuardianAccount = member;
                                            });
                                          },
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (selectedGuardianAccount != null)
                            Chip(
                              avatar: const Icon(
                                Icons.person_outline,
                                size: 16,
                              ),
                              label: Text(
                                selectedGuardianAccount!.displayLabel,
                              ),
                              onDeleted: isSaving
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        selectedGuardianAccount = null;
                                      });
                                    },
                            ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: guardianType,
                                  decoration: const InputDecoration(
                                    labelText: '보호자 유형',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'FATHER',
                                      child: Text('아버지'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'MOTHER',
                                      child: Text('어머니'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'GUARDIAN',
                                      child: Text('보호자'),
                                    ),
                                  ],
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          if (value == null) {
                                            return;
                                          }
                                          setDialogState(() {
                                            guardianType = value;
                                          });
                                        },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: isSaving ? null : connectGuardian,
                                icon: const Icon(Icons.link),
                                label: const Text('연결'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '연결된 학부모',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 8),
                          if (linkedGuardianUserIds.isEmpty)
                            _buildEmptyHint('연결된 학부모 계정이 없습니다.')
                          else
                            ...linkedGuardianUserIds.map((userId) {
                              final entry = _directoryEntryForUserId(userId);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: NestColors.roseMist,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.family_restroom_outlined,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.fullName.trim().isEmpty
                                                  ? entry.email
                                                  : entry.fullName,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                            Text(
                                              entry.email.isEmpty
                                                  ? entry.userId
                                                  : entry.email,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                      FilledButton.tonalIcon(
                                        onPressed: isSaving
                                            ? null
                                            : () => disconnectGuardian(userId),
                                        icon: const Icon(Icons.link_off),
                                        label: const Text('연결 해제'),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  if (initial != null)
                    TextButton.icon(
                      onPressed: isSaving ? null : deleteFamily,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('삭제'),
                    ),
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : saveFamily,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(initial == null ? '생성' : '저장'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      noteController.dispose();
      accountQueryController.dispose();
    }
  }

  Future<void> _openChildEditorDialog({
    required NestController controller,
    ChildProfile? initial,
    String? initialFamilyId,
  }) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final birthController = TextEditingController(
      text: initial?.birthDate == null
          ? DateFormat(
              'yyyy-MM-dd',
            ).format(DateTime.now().subtract(const Duration(days: 365 * 6)))
          : DateFormat('yyyy-MM-dd').format(initial!.birthDate!),
    );
    final noteController = TextEditingController(
      text: initial?.profileNote ?? '',
    );
    var selectedFamilyId =
        initial?.familyId ??
        initialFamilyId ??
        controller.families.firstOrNull?.id;
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> saveChild() async {
                if (isSaving) {
                  return;
                }
                final familyId = selectedFamilyId;
                if (familyId == null || familyId.isEmpty) {
                  _showMessage('가정을 선택하세요.');
                  return;
                }
                if (nameController.text.trim().isEmpty) {
                  _showMessage('아이 이름을 입력하세요.');
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });

                try {
                  final updatedChild = initial == null
                      ? await controller.createChild(
                          familyId: familyId,
                          name: nameController.text,
                          birthDate: birthController.text,
                          profileNote: noteController.text,
                        )
                      : await controller.updateChild(
                          childId: initial.id,
                          familyId: familyId,
                          name: nameController.text,
                          birthDate: birthController.text,
                          profileNote: noteController.text,
                        );
                  if (mounted) {
                    setState(() {
                      _selectedFamilyId = updatedChild.familyId;
                    });
                  }
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              Future<void> deleteChild() async {
                final target = initial;
                if (target == null || isSaving) {
                  return;
                }

                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('아이 삭제'),
                    content: Text(
                      '"${target.name}" 정보를 삭제할까요?\n'
                      '반 배정, 활동 기록, 태깅된 미디어 연결이 함께 정리될 수 있습니다.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(confirmContext).pop(false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) {
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });
                try {
                  await controller.deleteChild(childId: target.id);
                  if (mounted) {
                    setState(() {
                      _selectedFamilyId =
                          controller.families
                              .where((row) => row.id == target.familyId)
                              .firstOrNull
                              ?.id ??
                          controller.families.firstOrNull?.id;
                    });
                  }
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              final selectedFamilyName = controller.families
                  .where((row) => row.id == selectedFamilyId)
                  .map((row) => row.familyName)
                  .firstOrNull;

              return AlertDialog(
                title: Text(initial == null ? '아이 추가' : '아이 수정'),
                content: SizedBox(
                  width: 620,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFamilySelectionCards(
                          controller: controller,
                          title: '소속 가정',
                          selectedFamilyId: selectedFamilyId,
                          onSelect: (familyId) {
                            if (isSaving || controller.isBusy) {
                              return;
                            }
                            setDialogState(() {
                              selectedFamilyId = familyId;
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        if (selectedFamilyName != null)
                          Chip(
                            avatar: const Icon(Icons.home_outlined, size: 16),
                            label: Text('선택됨: $selectedFamilyName'),
                          ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: '아이 이름'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: birthController,
                          decoration: const InputDecoration(
                            labelText: '생년월일 (YYYY-MM-DD)',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: noteController,
                          decoration: const InputDecoration(
                            labelText: '프로필 메모',
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  if (initial != null)
                    TextButton.icon(
                      onPressed: isSaving ? null : deleteChild,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('삭제'),
                    ),
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : saveChild,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(initial == null ? '생성' : '저장'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      birthController.dispose();
      noteController.dispose();
    }
  }

  Widget _buildClassCrudCard(NestController controller) {
    final classGroups = controller.classGroups.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '반 관리',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _buildSectionCountBadge(
                        value: classGroups.length,
                        unit: '반',
                        icon: Icons.groups_2_outlined,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () => _openClassEditorDialog(controller: controller),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('반 추가'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '반 카드를 클릭하면 반 정보 수정과 아이 복수 배정을 한 번에 처리할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            if (classGroups.isEmpty)
              _buildEmptyHint('현재 학기에 등록된 반이 없습니다. 반 추가로 시작하세요.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: classGroups
                    .map((classGroup) {
                      final enrolledCount = controller
                          .enrolledChildIdsForClassGroup(classGroup.id)
                          .length;
                      final selected = _selectedClassGroupId == classGroup.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: controller.isBusy
                            ? null
                            : () {
                                setState(() {
                                  _selectedClassGroupId = classGroup.id;
                                });
                                _openClassEditorDialog(
                                  controller: controller,
                                  initial: classGroup,
                                );
                              },
                        child: SizedBox(
                          width: 310,
                          child: LabeledEntityTile(
                            title: classGroup.name,
                            subtitle:
                                '정원 ${classGroup.capacity}명 · 아이 $enrolledCount명 배정',
                            icon: Icons.groups_2_outlined,
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.edit_outlined,
                              size: 18,
                              color: selected
                                  ? NestColors.mutedSage
                                  : NestColors.deepWood.withValues(alpha: 0.62),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openClassEditorDialog({
    required NestController controller,
    ClassGroup? initial,
  }) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final capacityController = TextEditingController(
      text: initial?.capacity.toString() ?? '12',
    );
    final queryController = TextEditingController();
    final selectedChildIds =
        (initial == null
                ? <String>{}
                : controller.enrolledChildIdsForClassGroup(initial.id).toSet())
            .toSet();
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final query = queryController.text.trim().toLowerCase();
              final children =
                  controller.children
                      .where((child) {
                        if (query.isEmpty) {
                          return true;
                        }
                        return child.name.toLowerCase().contains(query) ||
                            child.familyName.toLowerCase().contains(query);
                      })
                      .toList()
                    ..sort((a, b) {
                      final familyCompare = a.familyName.compareTo(
                        b.familyName,
                      );
                      if (familyCompare != 0) {
                        return familyCompare;
                      }
                      return a.name.compareTo(b.name);
                    });

              Future<void> saveClass() async {
                if (isSaving) {
                  return;
                }
                final trimmedName = nameController.text.trim();
                final capacity = int.tryParse(capacityController.text.trim());
                if (trimmedName.isEmpty) {
                  _showMessage('반 이름을 입력하세요.');
                  return;
                }
                if (capacity == null) {
                  _showMessage('정원은 숫자로 입력하세요.');
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });

                try {
                  String classGroupId;
                  if (initial == null) {
                    await controller.createClassGroup(
                      name: trimmedName,
                      capacity: capacity,
                    );
                    classGroupId = controller.selectedClassGroupId ?? '';
                    if (classGroupId.isEmpty) {
                      throw StateError('생성된 반 ID를 확인할 수 없습니다.');
                    }
                  } else {
                    await controller.updateClassGroup(
                      classGroupId: initial.id,
                      name: trimmedName,
                      capacity: capacity,
                    );
                    classGroupId = initial.id;
                  }

                  await controller.syncClassEnrollments(
                    classGroupId: classGroupId,
                    childIds: selectedChildIds,
                  );

                  if (mounted) {
                    setState(() {
                      _selectedClassGroupId = classGroupId;
                    });
                  }
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              Future<void> deleteClass() async {
                final target = initial;
                if (target == null || isSaving) {
                  return;
                }
                final childCount = controller
                    .enrolledChildIdsForClassGroup(target.id)
                    .length;
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('반 삭제'),
                    content: Text(
                      '반 "${target.name}" 을(를) 삭제할까요?\n'
                      '배정된 아이 $childCount명과 연결된 시간표/배정 데이터가 함께 정리될 수 있습니다.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(confirmContext).pop(false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) {
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });
                try {
                  await controller.deleteClassGroup(classGroupId: target.id);
                  if (mounted) {
                    setState(() {
                      _selectedClassGroupId = controller.selectedClassGroupId;
                    });
                  }
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: Text(initial == null ? '반 추가' : '반 수정'),
                content: SizedBox(
                  width: 720,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: nameController,
                                decoration: const InputDecoration(
                                  labelText: '반 이름',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 140,
                              child: TextField(
                                controller: capacityController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '정원',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '아이 배정 (복수 선택)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        if (controller.children.isEmpty)
                          _buildEmptyHint('등록된 아이가 없습니다. 가정 탭에서 아이를 먼저 추가하세요.')
                        else ...[
                          TextField(
                            controller: queryController,
                            decoration: const InputDecoration(
                              labelText: '아이 검색',
                              hintText: '아이 이름 또는 가정 이름',
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Chip(
                                avatar: const Icon(Icons.checklist, size: 16),
                                label: Text('선택 ${selectedChildIds.length}명'),
                              ),
                              TextButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          selectedChildIds
                                            ..clear()
                                            ..addAll(
                                              controller.children.map(
                                                (row) => row.id,
                                              ),
                                            );
                                        });
                                      },
                                icon: const Icon(Icons.select_all, size: 16),
                                label: const Text('전체 선택'),
                              ),
                              TextButton.icon(
                                onPressed: isSaving
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          selectedChildIds.clear();
                                        });
                                      },
                                icon: const Icon(Icons.deselect, size: 16),
                                label: const Text('선택 해제'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            constraints: const BoxConstraints(maxHeight: 300),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: NestColors.roseMist),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: children.length,
                              itemBuilder: (context, index) {
                                final child = children[index];
                                final checked = selectedChildIds.contains(
                                  child.id,
                                );
                                return CheckboxListTile(
                                  dense: true,
                                  value: checked,
                                  title: Text(child.name),
                                  subtitle: Text(
                                    '${child.familyName} · ${_childStatusLabel(child.status)}',
                                  ),
                                  onChanged: isSaving
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            if (value == true) {
                                              selectedChildIds.add(child.id);
                                            } else {
                                              selectedChildIds.remove(child.id);
                                            }
                                          });
                                        },
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  if (initial != null)
                    TextButton.icon(
                      onPressed: isSaving ? null : deleteClass,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('삭제'),
                    ),
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : saveClass,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(initial == null ? '생성' : '저장'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      capacityController.dispose();
      queryController.dispose();
    }
  }

  Widget _buildTeacherManagementCard(NestController controller) {
    final teachers = controller.teacherProfiles.toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '선생님 관리',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _buildSectionCountBadge(
                        value: teachers.length,
                        unit: '명',
                        icon: Icons.school_outlined,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () => _openTeacherEditorDialog(controller: controller),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('선생님 추가'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '카드를 클릭하면 선생님 정보 수정, 기존 계정 연결/해제, 불가 시간 설정을 한 번에 처리할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            if (teachers.isEmpty)
              _buildEmptyHint('등록된 선생님이 없습니다. 선생님 추가로 시작하세요.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: teachers
                    .map((teacher) {
                      final blockCount = controller.memberUnavailabilityBlocks
                          .where(
                            (block) =>
                                block.ownerKind == 'TEACHER_PROFILE' &&
                                block.ownerId == teacher.id,
                          )
                          .length;
                      final linkedLabel = teacher.userId == null
                          ? '계정 미연결'
                          : '계정 연결됨';
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: controller.isBusy
                            ? null
                            : () => _openTeacherEditorDialog(
                                controller: controller,
                                initial: teacher,
                              ),
                        child: SizedBox(
                          width: 290,
                          child: LabeledEntityTile(
                            title: teacher.displayName,
                            subtitle:
                                '${_teacherTypeLabel(teacher.teacherType)} · $linkedLabel · 불가시간 $blockCount건',
                            icon: Icons.school_outlined,
                            trailing: const Icon(Icons.edit_outlined, size: 18),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTeacherEditorDialog({
    required NestController controller,
    TeacherProfile? initial,
  }) async {
    final nameController = TextEditingController(
      text: initial?.displayName ?? '',
    );
    final accountQueryController = TextEditingController();
    final startController = TextEditingController(text: '09:00');
    final endController = TextEditingController(text: '10:00');
    final noteController = TextEditingController();

    var teacherType = initial?.teacherType ?? 'GUEST_TEACHER';
    var linkAccount = initial?.userId != null;
    var selectedDay = 1;
    var editingTeacher = initial;
    HomeschoolMemberDirectoryEntry? selectedAccount = initial?.userId == null
        ? null
        : _directoryEntryForUserId(initial!.userId!);
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final matches = controller.searchHomeschoolMemberDirectory(
                accountQueryController.text,
                maxResults: 8,
              );
              final blocks =
                  editingTeacher == null
                        ? const <MemberUnavailabilityBlock>[]
                        : controller.memberUnavailabilityBlocks
                                  .where(
                                    (block) =>
                                        block.ownerKind == 'TEACHER_PROFILE' &&
                                        block.ownerId == editingTeacher!.id,
                                  )
                                  .toList()
                              ..sort((a, b) {
                                final day =
                                    a.dayOfWeek.compareTo(b.dayOfWeek);
                                if (day != 0) {
                                  return day;
                                }
                                return a.startTime.compareTo(b.startTime);
                              });

              Future<void> saveTeacher() async {
                if (nameController.text.trim().isEmpty || isSaving) {
                  return;
                }

                if (linkAccount && selectedAccount == null) {
                  _showMessage('연결할 계정을 선택하세요.');
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });
                try {
                  if (editingTeacher == null) {
                    final created = await controller.createTeacherProfile(
                      displayName: nameController.text,
                      teacherType: teacherType,
                      userId: linkAccount ? selectedAccount?.userId : null,
                    );
                    editingTeacher = created;
                    _showMessage('선생님을 생성했습니다. 이어서 불가 시간을 설정하세요.');
                  } else {
                    final updated = await controller.updateTeacherProfile(
                      teacherProfileId: editingTeacher!.id,
                      displayName: nameController.text,
                      teacherType: teacherType,
                      userId: linkAccount ? selectedAccount?.userId : null,
                    );
                    editingTeacher = updated;
                    _showMessage('선생님 정보를 저장했습니다.');
                  }

                  if (mounted) {
                    setState(() {});
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                } finally {
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              Future<void> addUnavailability() async {
                final teacher = editingTeacher;
                if (teacher == null) {
                  _showMessage('먼저 선생님 정보를 저장하세요.');
                  return;
                }
                try {
                  await controller.createMemberUnavailabilityBlock(
                    ownerKind: 'TEACHER_PROFILE',
                    ownerId: teacher.id,
                    dayOfWeek: selectedDay,
                    startTime: startController.text,
                    endTime: endController.text,
                    note: noteController.text,
                  );
                  noteController.clear();
                  if (context.mounted) {
                    setDialogState(() {});
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                }
              }

              Future<void> removeUnavailability(String blockId) async {
                try {
                  await controller.deleteMemberUnavailabilityBlock(
                    blockId: blockId,
                  );
                  if (context.mounted) {
                    setDialogState(() {});
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                }
              }

              return AlertDialog(
                title: Text(editingTeacher == null ? '선생님 추가' : '선생님 수정'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: '표시 이름'),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'PARENT_TEACHER',
                              label: Text('부모 교사'),
                              icon: Icon(Icons.family_restroom, size: 16),
                            ),
                            ButtonSegment(
                              value: 'GUEST_TEACHER',
                              label: Text('초청 교사'),
                              icon: Icon(Icons.badge_outlined, size: 16),
                            ),
                          ],
                          selected: {teacherType},
                          onSelectionChanged: isSaving
                              ? null
                              : (values) {
                                  if (values.isEmpty) {
                                    return;
                                  }
                                  setDialogState(() {
                                    teacherType = values.first;
                                  });
                                },
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('기존 계정 연결'),
                          subtitle: const Text('이름/이메일/UUID 검색으로 연결'),
                          value: linkAccount,
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  setDialogState(() {
                                    linkAccount = value;
                                    if (!value) {
                                      selectedAccount = null;
                                      accountQueryController.clear();
                                    }
                                  });
                                },
                        ),
                        if (linkAccount) ...[
                          TextField(
                            controller: accountQueryController,
                            decoration: const InputDecoration(
                              labelText: '계정 검색',
                              hintText: '이름, 이메일, UUID로 검색',
                            ),
                            onChanged: (_) => setDialogState(() {}),
                          ),
                          const SizedBox(height: 8),
                          if (matches.isEmpty)
                            const NestEmptyState(
                              icon: Icons.search_off_outlined,
                              title: '검색 결과가 없습니다.',
                            )
                          else
                            Container(
                              constraints: const BoxConstraints(maxHeight: 180),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: NestColors.roseMist),
                              ),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: matches.length,
                                itemBuilder: (context, index) {
                                  final member = matches[index];
                                  final selected =
                                      selectedAccount?.userId == member.userId;
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      selected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_unchecked,
                                      size: 18,
                                    ),
                                    title: Text(
                                      member.fullName.trim().isEmpty
                                          ? member.email
                                          : member.fullName,
                                    ),
                                    subtitle: Text(
                                      member.email.isEmpty
                                          ? member.userId
                                          : member.email,
                                    ),
                                    onTap: isSaving
                                        ? null
                                        : () {
                                            setDialogState(() {
                                              selectedAccount = member;
                                              if (nameController.text
                                                  .trim()
                                                  .isEmpty) {
                                                nameController.text =
                                                    member.fullName
                                                        .trim()
                                                        .isNotEmpty
                                                    ? member.fullName
                                                    : member.email;
                                              }
                                            });
                                          },
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (selectedAccount != null)
                            Chip(
                              avatar: const Icon(Icons.link, size: 16),
                              label: Text(selectedAccount!.displayLabel),
                              onDeleted: isSaving
                                  ? null
                                  : () {
                                      setDialogState(() {
                                        selectedAccount = null;
                                      });
                                    },
                            ),
                        ],
                        const SizedBox(height: 10),
                        if (editingTeacher == null)
                          _buildEmptyHint(
                            '선생님 정보를 먼저 저장하면 이 아래에서 불가 시간을 바로 설정할 수 있습니다.',
                          )
                        else ...[
                          Text(
                            '불가 시간 설정',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: List.generate(7, (day) {
                              return ChoiceChip(
                                label: Text(_dayLabel(day)),
                                selected: selectedDay == day,
                                onSelected: controller.isBusy || isSaving
                                    ? null
                                    : (_) {
                                        setDialogState(() {
                                          selectedDay = day;
                                        });
                                      },
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: startController,
                                  decoration: const InputDecoration(
                                    labelText: '시작 (HH:MM)',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: endController,
                                  decoration: const InputDecoration(
                                    labelText: '종료 (HH:MM)',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: noteController,
                            decoration: const InputDecoration(labelText: '메모'),
                            minLines: 1,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: controller.isBusy || isSaving
                                ? null
                                : addUnavailability,
                            icon: const Icon(Icons.block),
                            label: const Text('불가 시간 추가'),
                          ),
                          const SizedBox(height: 10),
                          if (blocks.isEmpty)
                            const NestEmptyState(
                              icon: Icons.event_busy_outlined,
                              title: '등록된 불가 시간이 없습니다.',
                            )
                          else
                            ...blocks.map((block) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: NestColors.roseMist,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${_dayLabel(block.dayOfWeek)} ${_shortTime(block.startTime)}-${_shortTime(block.endTime)}'
                                          '${block.note.trim().isEmpty ? '' : ' · ${block.note.trim()}'}',
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: controller.isBusy || isSaving
                                            ? null
                                            : () => removeUnavailability(
                                                block.id,
                                              ),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  if (editingTeacher != null)
                    TextButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('선생님 삭제'),
                                  content: Text(
                                    '"${editingTeacher!.displayName}" 선생님을 삭제할까요?\n'
                                    '시간표에서 사용 중이면 삭제할 수 없습니다.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const Text('취소'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const Text('삭제'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed != true || !context.mounted) {
                                return;
                              }
                              setDialogState(() {
                                isSaving = true;
                              });
                              try {
                                await controller.deleteTeacherProfile(
                                  teacherProfileId: editingTeacher!.id,
                                );
                                _showMessage('선생님을 삭제했습니다.');
                                if (mounted) {
                                  setState(() {});
                                }
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              } catch (_) {
                                _showMessage(controller.statusMessage);
                                if (context.mounted) {
                                  setDialogState(() {
                                    isSaving = false;
                                  });
                                }
                              }
                            },
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.red),
                      label: const Text('삭제',
                          style: TextStyle(color: Colors.red)),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving ? null : saveTeacher,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(editingTeacher == null ? '생성' : '저장'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      accountQueryController.dispose();
      startController.dispose();
      endController.dispose();
      noteController.dispose();
    }
  }

  HomeschoolMemberDirectoryEntry _directoryEntryForUserId(String userId) {
    final found = widget.controller.homeschoolMemberDirectory
        .where((entry) => entry.userId == userId)
        .firstOrNull;
    if (found != null) {
      return found;
    }
    return HomeschoolMemberDirectoryEntry(
      userId: userId,
      email: '',
      fullName: widget.controller.findMemberDisplayName(userId),
      roles: const [],
    );
  }

  String _teacherTypeLabel(String type) {
    return switch (type) {
      'PARENT_TEACHER' => '부모 교사',
      'GUEST_TEACHER' => '초청 교사',
      _ => type,
    };
  }

  Widget _buildEmptyHint(String message) {
    return NestEmptyState(
      icon: Icons.family_restroom_outlined,
      title: message,
    );
  }

  Widget _buildSetupSummaryGrid({required List<_SetupStat> stats}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columnCount = width < 500
            ? 2
            : width < 760
            ? 3
            : width >= 980
            ? 7
            : 4;
        final itemWidth = (width - ((columnCount - 1) * 10)) / columnCount;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: stats
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: _buildSetupSummaryCard(stat: item),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildSetupSummaryCard({required _SetupStat stat}) {
    final formattedValue = NumberFormat.decimalPattern().format(stat.value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stat.accent.withValues(alpha: 0.34)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [stat.accent.withValues(alpha: 0.18), Colors.white],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stat.accent.withValues(alpha: 0.2),
                ),
                child: Icon(stat.icon, size: 14, color: NestColors.deepWood),
              ),
              const SizedBox(width: 6),
              Text(
                stat.title,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: NestColors.deepWood.withValues(alpha: 0.84),
                ),
              ),
              const Spacer(),
              Text(
                stat.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: NestColors.deepWood.withValues(alpha: 0.56),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formattedValue,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontSize: 24,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: NestColors.deepWood,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  stat.unit,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: NestColors.deepWood.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCountBadge({
    required int value,
    required String unit,
    required IconData icon,
  }) {
    final label = '${NumberFormat.decimalPattern().format(value)}$unit';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: NestColors.roseMist.withValues(alpha: 0.78),
        border: Border.all(color: NestColors.dustyRose.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: NestColors.deepWood.withValues(alpha: 0.72),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: NestColors.deepWood,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseManageCard(NestController controller) {
    final courses = controller.courses.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '과목 관리',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _buildSectionCountBadge(
                        value: courses.length,
                        unit: '개',
                        icon: Icons.menu_book_outlined,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () => _openCourseEditorDialog(controller: controller),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('과목 추가'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '과목 카드를 클릭하면 기본 수업 시간 수정과 삭제를 한 번에 처리할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            if (courses.isEmpty)
              _buildEmptyHint('등록된 과목이 없습니다. 과목 추가로 시작하세요.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: courses
                    .map((course) {
                      final usedInCurrentClass = controller.sessions.any(
                        (session) => session.courseId == course.id,
                      );
                      final selected = _selectedCourseId == course.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: controller.isBusy
                            ? null
                            : () {
                                setState(() {
                                  _selectedCourseId = course.id;
                                });
                                _openCourseEditorDialog(
                                  controller: controller,
                                  initial: course,
                                );
                              },
                        child: SizedBox(
                          width: 290,
                          child: LabeledEntityTile(
                            title: course.name,
                            subtitle:
                                '기본 ${course.defaultDurationMin}분${usedInCurrentClass ? ' · 현재 반 시간표 사용중' : ''}',
                            icon: Icons.menu_book_outlined,
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.edit_outlined,
                              size: 18,
                              color: selected
                                  ? NestColors.mutedSage
                                  : NestColors.deepWood.withValues(alpha: 0.62),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCourseEditorDialog({
    required NestController controller,
    Course? initial,
  }) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final durationController = TextEditingController(
      text: initial?.defaultDurationMin.toString() ?? '50',
    );
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final usedInCurrentClass =
                  initial != null &&
                  controller.sessions.any(
                    (session) => session.courseId == initial.id,
                  );

              Future<void> saveCourse() async {
                if (isSaving) {
                  return;
                }

                final trimmedName = nameController.text.trim();
                final duration = int.tryParse(durationController.text.trim());
                if (trimmedName.isEmpty) {
                  _showMessage('과목 이름을 입력하세요.');
                  return;
                }
                if (duration == null) {
                  _showMessage('기본 수업 시간은 숫자로 입력하세요.');
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });
                try {
                  if (initial == null) {
                    await controller.createCourse(
                      name: trimmedName,
                      defaultDurationMin: duration,
                    );
                    if (mounted) {
                      final matched = controller.courses
                          .where(
                            (course) =>
                                course.name.toLowerCase() ==
                                    trimmedName.toLowerCase() &&
                                course.defaultDurationMin == duration,
                          )
                          .toList();
                      setState(() {
                        _selectedCourseId = matched.firstOrNull?.id;
                      });
                    }
                  } else {
                    await controller.updateCourse(
                      courseId: initial.id,
                      name: trimmedName,
                      defaultDurationMin: duration,
                    );
                    if (mounted) {
                      setState(() {
                        _selectedCourseId = initial.id;
                      });
                    }
                  }
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              Future<void> deleteCourse() async {
                final target = initial;
                if (target == null || isSaving || usedInCurrentClass) {
                  return;
                }
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('과목 삭제'),
                    content: Text(
                      '"${target.name}" 과목을 삭제할까요?\n'
                      '시간표에서 사용 중인 과목은 삭제할 수 없습니다.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(confirmContext).pop(false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) {
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });
                try {
                  await controller.deleteCourse(courseId: target.id);
                  if (mounted) {
                    setState(() {
                      _selectedCourseId = controller.courses.firstOrNull?.id;
                    });
                  }
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: Text(initial == null ? '과목 추가' : '과목 수정'),
                content: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: '과목 이름'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: durationController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '기본 수업 시간(분)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (usedInCurrentClass)
                        _buildEmptyHint(
                          '현재 선택된 반의 시간표에서 사용 중인 과목입니다. 삭제는 불가능하며 이름/시간 수정만 가능합니다.',
                        ),
                    ],
                  ),
                ),
                actions: [
                  if (initial != null)
                    TextButton.icon(
                      onPressed:
                          isSaving || controller.isBusy || usedInCurrentClass
                          ? null
                          : deleteCourse,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('삭제'),
                    ),
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving || controller.isBusy
                        ? null
                        : saveCourse,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(initial == null ? '생성' : '저장'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      durationController.dispose();
    }
  }

  Widget _buildClassroomManageCard(NestController controller) {
    final classrooms = controller.classrooms.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '교실 관리',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      _buildSectionCountBadge(
                        value: classrooms.length,
                        unit: '개',
                        icon: Icons.meeting_room_outlined,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () =>
                            _openClassroomEditorDialog(controller: controller),
                  icon: const Icon(Icons.add_home_work_outlined),
                  label: const Text('교실 추가'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '교실 카드를 클릭하면 수용 인원/메모 수정과 삭제를 한 번에 처리할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            if (classrooms.isEmpty)
              _buildEmptyHint('등록된 교실이 없습니다. 교실 추가로 시작하세요.')
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: classrooms
                    .map((classroom) {
                      final used = controller.allTermSessions.any(
                        (session) =>
                            (session.location ?? '').trim() == classroom.name,
                      );
                      final selected = _selectedClassroomId == classroom.id;
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: controller.isBusy
                            ? null
                            : () {
                                setState(() {
                                  _selectedClassroomId = classroom.id;
                                });
                                _openClassroomEditorDialog(
                                  controller: controller,
                                  initial: classroom,
                                );
                              },
                        child: SizedBox(
                          width: 290,
                          child: LabeledEntityTile(
                            title: classroom.name,
                            subtitle:
                                '정원 ${classroom.capacity}명${used ? ' · 시간표 사용중' : ''}',
                            icon: Icons.meeting_room_outlined,
                            trailing: Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.edit_outlined,
                              size: 18,
                              color: selected
                                  ? NestColors.mutedSage
                                  : NestColors.deepWood.withValues(alpha: 0.62),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openClassroomEditorDialog({
    required NestController controller,
    Classroom? initial,
  }) async {
    final nameController = TextEditingController(text: initial?.name ?? '');
    final capacityController = TextEditingController(
      text: initial?.capacity.toString() ?? '20',
    );
    final noteController = TextEditingController(text: initial?.note ?? '');
    var isSaving = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              final usedBySession =
                  initial != null &&
                  controller.allTermSessions.any(
                    (session) =>
                        (session.location ?? '').trim() == initial.name.trim(),
                  );

              Future<void> saveClassroom() async {
                if (isSaving) {
                  return;
                }
                final trimmedName = nameController.text.trim();
                final capacity = int.tryParse(capacityController.text.trim());
                if (trimmedName.isEmpty) {
                  _showMessage('교실 이름을 입력하세요.');
                  return;
                }
                if (capacity == null) {
                  _showMessage('수용 인원은 숫자로 입력하세요.');
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });
                try {
                  if (initial == null) {
                    await controller.createClassroom(
                      name: trimmedName,
                      capacity: capacity,
                      note: noteController.text,
                    );
                    if (mounted) {
                      final matched = controller.classrooms
                          .where(
                            (classroom) =>
                                classroom.name.toLowerCase() ==
                                    trimmedName.toLowerCase() &&
                                classroom.capacity == capacity,
                          )
                          .toList();
                      setState(() {
                        _selectedClassroomId = matched.firstOrNull?.id;
                      });
                    }
                  } else {
                    await controller.updateClassroom(
                      classroomId: initial.id,
                      name: trimmedName,
                      capacity: capacity,
                      note: noteController.text,
                    );
                    if (mounted) {
                      setState(() {
                        _selectedClassroomId = initial.id;
                      });
                    }
                  }
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              Future<void> deleteClassroom() async {
                final target = initial;
                if (target == null || isSaving || usedBySession) {
                  return;
                }
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (confirmContext) => AlertDialog(
                    title: const Text('교실 삭제'),
                    content: Text(
                      '"${target.name}" 교실을 삭제할까요?\n'
                      '시간표에서 사용 중인 교실은 삭제할 수 없습니다.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(confirmContext).pop(false),
                        child: const Text('취소'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(confirmContext).pop(true),
                        child: const Text('삭제'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) {
                  return;
                }

                setDialogState(() {
                  isSaving = true;
                });
                try {
                  await controller.deleteClassroom(classroomId: target.id);
                  if (mounted) {
                    setState(() {
                      _selectedClassroomId =
                          controller.classrooms.firstOrNull?.id;
                    });
                  }
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (_) {
                  _showMessage(controller.statusMessage);
                  if (context.mounted) {
                    setDialogState(() {
                      isSaving = false;
                    });
                  }
                }
              }

              return AlertDialog(
                title: Text(initial == null ? '교실 추가' : '교실 수정'),
                content: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: '교실 이름'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: capacityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '수용 인원'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteController,
                        decoration: const InputDecoration(labelText: '메모'),
                        minLines: 1,
                        maxLines: 3,
                      ),
                      if (usedBySession) ...[
                        const SizedBox(height: 8),
                        _buildEmptyHint(
                          '현재 시간표에서 사용 중인 교실입니다. 이름/정보 수정은 가능하지만 삭제는 제한됩니다.',
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  if (initial != null)
                    TextButton.icon(
                      onPressed: isSaving || controller.isBusy || usedBySession
                          ? null
                          : deleteClassroom,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('삭제'),
                    ),
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving || controller.isBusy
                        ? null
                        : saveClassroom,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(initial == null ? '생성' : '저장'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      capacityController.dispose();
      noteController.dispose();
    }
  }

  Future<void> _refreshFamilyDomain() async {
    try {
      await widget.controller.loadFamilies();
      await widget.controller.loadFamilyGuardians();
      await widget.controller.loadChildren();
      await widget.controller.loadClassEnrollments();
      await widget.controller.loadTeacherProfiles();
      await widget.controller.loadMemberUnavailabilityBlocks();
      await widget.controller.loadHomeschoolMemberDirectory();
      _showMessage('가정/아이/배정 목록을 갱신했습니다.');
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

class _SetupStat {
  const _SetupStat({
    required this.title,
    required this.value,
    required this.unit,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  final String title;
  final int value;
  final String unit;
  final String subtitle;
  final IconData icon;
  final Color accent;
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _childStatusLabel(String status) {
  return switch (status) {
    'ACTIVE' => '활동 중',
    'INACTIVE' => '비활동',
    'GRADUATED' => '졸업',
    _ => status,
  };
}
