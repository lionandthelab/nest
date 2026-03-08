import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/entity_visuals.dart';

class FamilyAdminTab extends StatefulWidget {
  const FamilyAdminTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<FamilyAdminTab> createState() => _FamilyAdminTabState();
}

class _FamilyAdminTabState extends State<FamilyAdminTab> {
  final _classNameController = TextEditingController();
  final _classCapacityController = TextEditingController(text: '12');
  final _courseNameController = TextEditingController();
  final _courseDurationController = TextEditingController(text: '50');

  String? _selectedFamilyId;
  String? _selectedClassGroupId;
  String? _classFormBoundToId;
  bool _familyInitialized = false;
  bool _classInitialized = false;
  String _setupUnit = 'FAMILY';

  @override
  void dispose() {
    _classNameController.dispose();
    _classCapacityController.dispose();
    _courseNameController.dispose();
    _courseDurationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    _syncSelections(controller);
    _syncClassForm(controller);

    if (!controller.canManageFamilies) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Term Setup', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('가정/아이 배정 관리는 관리자/스태프만 사용할 수 있습니다.'),
            ],
          ),
        ),
      );
    }

    final unitCards = switch (_setupUnit) {
      'FAMILY' => [
        _buildFamilyManagementCard(controller),
        const SizedBox(height: 12),
        _buildChildManagementCard(controller),
      ],
      'TEACHER' => [_buildTeacherManagementCard(controller)],
      'CLASS' => [
        _buildClassCrudCard(controller),
        const SizedBox(height: 12),
        _buildEnrollmentCard(controller),
      ],
      'COURSE' => [_buildCourseManageCard(controller)],
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
    final completed = [
      familyDone,
      teacherDone,
      classDone,
      courseDone,
    ].where((done) => done).length;

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
              '가정, 선생님, 반, 과목을 단위별로 설정한 뒤 시간표 탭에서 배치하세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: completed / 4,
                color: NestColors.dustyRose,
                backgroundColor: NestColors.roseMist,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '완료 $completed / 4',
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
              ],
            ),
            if (controller.classGroups.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('현재 반 목록', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: controller.classGroups
                    .map(
                      (group) => SizedBox(
                        width: 220,
                        child: LabeledEntityTile(
                          title: group.name,
                          subtitle: '정원 ${group.capacity}명',
                          icon: Icons.groups_2_outlined,
                          compact: true,
                          trailing: group.id == _selectedClassGroupId
                              ? Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: NestColors.mutedSage,
                                )
                              : null,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _syncSelections(NestController controller) {
    final familyIds = controller.families.map((row) => row.id).toSet();
    final classIds = controller.classGroups.map((row) => row.id).toSet();

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
  }

  void _syncClassForm(NestController controller, {bool force = false}) {
    final classGroupId = _selectedClassGroupId;
    if (classGroupId == null || classGroupId.isEmpty) {
      if (force || _classFormBoundToId != null) {
        _classNameController.clear();
        _classCapacityController.text = '12';
        _classFormBoundToId = null;
      }
      return;
    }

    final classGroup = controller.classGroups
        .where((row) => row.id == classGroupId)
        .firstOrNull;
    if (classGroup == null) {
      return;
    }

    if (force || _classFormBoundToId != classGroup.id) {
      _classNameController.text = classGroup.name;
      _classCapacityController.text = classGroup.capacity.toString();
      _classFormBoundToId = classGroup.id;
    }
  }

  Widget _buildFamilyManagementCard(NestController controller) {
    final families = controller.families.toList(growable: false)
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
                  child: Text(
                    '가정 관리',
                    style: Theme.of(context).textTheme.titleLarge,
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
                    .toList(growable: false),
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
    final families = controller.families.toList(growable: false)
      ..sort((a, b) => a.familyName.compareTo(b.familyName));

    if (families.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: NestColors.deepWood.withValues(alpha: 0.74),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: families
              .map((family) {
                final selected = family.id == selectedFamilyId;
                final childCount = controller
                    .childrenForFamily(family.id)
                    .length;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: controller.isBusy ? null : () => onSelect(family.id),
                  child: SizedBox(
                    width: 240,
                    child: LabeledEntityTile(
                      title: family.familyName,
                      subtitle: '아이 $childCount명',
                      icon: Icons.home_outlined,
                      compact: true,
                      trailing: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: selected
                            ? NestColors.mutedSage
                            : NestColors.deepWood.withValues(alpha: 0.46),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ],
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
            .toList(growable: false)
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
                  child: Text(
                    '아이 관리',
                    style: Theme.of(context).textTheme.titleLarge,
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
                title: '아이 조회 대상 가정',
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
                              subtitle: '$birthLabel · ${child.status}',
                              icon: Icons.child_care_outlined,
                              trailing: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                        );
                      })
                      .toList(growable: false),
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

              return AlertDialog(
                title: Text(initial == null ? '가정 추가' : '가정 수정'),
                content: SizedBox(
                  width: 520,
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
                    ],
                  ),
                ),
                actions: [
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('반 관리 (CRUD)', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '반을 생성/수정/삭제하면 반별 시간표 편성 대상이 즉시 반영됩니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            if (controller.classGroups.isEmpty)
              const Text('현재 학기에 등록된 반이 없습니다. 아래 정보로 새 반을 생성하세요.')
            else
              _buildClassSelectionCards(
                controller: controller,
                title: '편집 대상 반',
                selectedClassGroupId: _selectedClassGroupId,
                onSelect: (classGroupId) {
                  if (controller.isBusy) {
                    return;
                  }
                  setState(() {
                    _selectedClassGroupId = classGroupId;
                    _syncClassForm(controller, force: true);
                  });
                },
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _classNameController,
              decoration: const InputDecoration(labelText: '반 이름'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _classCapacityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '정원'),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.isBusy ? null : _createClassGroup,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('반 생성'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy || _selectedClassGroupId == null
                      ? null
                      : _updateClassGroup,
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('반 수정'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy || _selectedClassGroupId == null
                      ? null
                      : _deleteClassGroup,
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.red.shade700,
                  ),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('반 삭제'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClassSelectionCards({
    required NestController controller,
    required String title,
    required String? selectedClassGroupId,
    required ValueChanged<String> onSelect,
  }) {
    final classes = controller.classGroups.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));

    if (classes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: NestColors.deepWood.withValues(alpha: 0.74),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: classes
              .map((classGroup) {
                final selected = classGroup.id == selectedClassGroupId;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: controller.isBusy
                      ? null
                      : () => onSelect(classGroup.id),
                  child: SizedBox(
                    width: 200,
                    child: LabeledEntityTile(
                      title: classGroup.name,
                      subtitle: '정원 ${classGroup.capacity}명',
                      icon: Icons.groups_2_outlined,
                      compact: true,
                      trailing: Icon(
                        selected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: selected
                            ? NestColors.mutedSage
                            : NestColors.deepWood.withValues(alpha: 0.46),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _buildEnrollmentCard(NestController controller) {
    final classGroupId = _selectedClassGroupId;
    final selectedClass = controller.classGroups
        .where((row) => row.id == classGroupId)
        .firstOrNull;
    final enrolledIds = classGroupId == null
        ? const <String>[]
        : controller.enrolledChildIdsForClassGroup(classGroupId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('반 배정', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '선택한 반에 아이를 체크로 배정/해제합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            if (controller.classGroups.isEmpty)
              const Text('현재 학기에 반이 없습니다.')
            else
              _buildClassSelectionCards(
                controller: controller,
                title: '배정 대상 반',
                selectedClassGroupId: selectedClass?.id,
                onSelect: (nextClassGroupId) {
                  if (controller.isBusy) {
                    return;
                  }
                  setState(() {
                    _selectedClassGroupId = nextClassGroupId;
                    _syncClassForm(controller, force: true);
                  });
                },
              ),
            const SizedBox(height: 8),
            if (controller.children.isEmpty)
              const Text('등록된 아이가 없습니다.')
            else
              ...controller.children.map((child) {
                final checked = enrolledIds.contains(child.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NestColors.roseMist),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: checked,
                          onChanged: controller.isBusy || classGroupId == null
                              ? null
                              : (value) => _toggleEnrollment(
                                  childId: child.id,
                                  checked: value == true,
                                  classGroupId: classGroupId,
                                ),
                        ),
                        EntityAvatar(
                          label: child.name,
                          icon: Icons.child_care_outlined,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                child.name,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '${child.familyName} · ${child.status}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (checked)
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: NestColors.mutedSage,
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

  Widget _buildTeacherManagementCard(NestController controller) {
    final teachers = controller.teacherProfiles.toList(growable: false)
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
                  child: Text(
                    '선생님 관리',
                    style: Theme.of(context).textTheme.titleLarge,
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
                    .toList(growable: false),
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
                              .toList(growable: false)
                    ..sort((a, b) {
                      final day = a.dayOfWeek.compareTo(b.dayOfWeek);
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
                            const Text('검색 결과가 없습니다.')
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
                            const Text('등록된 불가 시간이 없습니다.')
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.roseMist.withValues(alpha: 0.36),
      ),
      child: Text(message),
    );
  }

  Widget _buildCourseManageCard(NestController controller) {
    final courses = controller.courses.toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('과목 관리', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '시간표 배치에 사용할 과목을 관리합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _courseNameController,
                    decoration: const InputDecoration(labelText: '과목 이름'),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: _courseDurationController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '기본 분(min)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: controller.isBusy ? null : _createCourse,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('과목 추가'),
            ),
            const SizedBox(height: 12),
            if (courses.isEmpty)
              const Text('등록된 과목이 없습니다.')
            else
              ...courses.map((course) {
                final usedInCurrentClass = controller.sessions.any(
                  (session) => session.courseId == course.id,
                );
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: NestColors.roseMist),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                course.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                '기본 ${course.defaultDurationMin}분${usedInCurrentClass ? ' · 현재 반 시간표 사용중' : ''}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: controller.isBusy || usedInCurrentClass
                              ? null
                              : () => _deleteCourse(course.id),
                          icon: const Icon(Icons.delete_outline),
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

  Future<void> _createClassGroup() async {
    final capacity = int.tryParse(_classCapacityController.text.trim());
    if (capacity == null) {
      _showMessage('정원은 숫자로 입력하세요.');
      return;
    }

    try {
      await widget.controller.createClassGroup(
        name: _classNameController.text,
        capacity: capacity,
      );
      setState(() {
        _selectedClassGroupId = widget.controller.selectedClassGroupId;
        _syncClassForm(widget.controller, force: true);
      });
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _updateClassGroup() async {
    final classGroupId = _selectedClassGroupId;
    if (classGroupId == null || classGroupId.isEmpty) {
      _showMessage('수정할 반을 선택하세요.');
      return;
    }

    final capacity = int.tryParse(_classCapacityController.text.trim());
    if (capacity == null) {
      _showMessage('정원은 숫자로 입력하세요.');
      return;
    }

    try {
      await widget.controller.updateClassGroup(
        classGroupId: classGroupId,
        name: _classNameController.text,
        capacity: capacity,
      );
      setState(() {
        _syncClassForm(widget.controller, force: true);
      });
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _deleteClassGroup() async {
    final classGroupId = _selectedClassGroupId;
    if (classGroupId == null || classGroupId.isEmpty) {
      _showMessage('삭제할 반을 선택하세요.');
      return;
    }

    final className = widget.controller.findClassGroupName(classGroupId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('반 삭제'),
        content: Text(
          '반 "$className" 을(를) 삭제할까요?\n연결된 시간표/배정 데이터도 함께 삭제될 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.controller.deleteClassGroup(classGroupId: classGroupId);
      setState(() {
        _selectedClassGroupId = widget.controller.selectedClassGroupId;
        _syncClassForm(widget.controller, force: true);
      });
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _toggleEnrollment({
    required String classGroupId,
    required String childId,
    required bool checked,
  }) async {
    try {
      if (checked) {
        await widget.controller.assignChildToClass(
          classGroupId: classGroupId,
          childId: childId,
        );
      } else {
        await widget.controller.unassignChildFromClass(
          classGroupId: classGroupId,
          childId: childId,
        );
      }
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
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

  Future<void> _createCourse() async {
    final duration = int.tryParse(_courseDurationController.text.trim());
    if (duration == null) {
      _showMessage('기본 시간은 숫자로 입력하세요.');
      return;
    }

    try {
      await widget.controller.createCourse(
        name: _courseNameController.text,
        defaultDurationMin: duration,
      );
      _courseNameController.clear();
      _courseDurationController.text = '50';
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _deleteCourse(String courseId) async {
    try {
      await widget.controller.deleteCourse(courseId: courseId);
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
