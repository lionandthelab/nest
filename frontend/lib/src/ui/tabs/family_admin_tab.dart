import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class FamilyAdminTab extends StatefulWidget {
  const FamilyAdminTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<FamilyAdminTab> createState() => _FamilyAdminTabState();
}

class _FamilyAdminTabState extends State<FamilyAdminTab> {
  final _familyNameController = TextEditingController();
  final _familyNoteController = TextEditingController();
  final _childNameController = TextEditingController();
  final _childNoteController = TextEditingController();
  final _teacherDisplayNameController = TextEditingController();
  final _teacherUserIdController = TextEditingController();
  late final TextEditingController _birthDateController;

  String? _selectedFamilyId;
  String? _selectedClassGroupId;
  String _teacherType = 'GUEST_TEACHER';
  bool _familyInitialized = false;
  bool _classInitialized = false;

  @override
  void initState() {
    super.initState();
    final defaultBirth = DateTime.now().subtract(const Duration(days: 365 * 6));
    _birthDateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(defaultBirth),
    );
  }

  @override
  void dispose() {
    _familyNameController.dispose();
    _familyNoteController.dispose();
    _childNameController.dispose();
    _childNoteController.dispose();
    _teacherDisplayNameController.dispose();
    _teacherUserIdController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

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
              Text(
                'Family Admin',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text('가정/아이 배정 관리는 관리자/스태프만 사용할 수 있습니다.'),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        _buildFamilyCreateCard(controller),
        const SizedBox(height: 12),
        _buildChildCreateCard(controller),
        const SizedBox(height: 12),
        _buildTeacherProfileCard(controller),
        const SizedBox(height: 12),
        _buildEnrollmentCard(controller),
        const SizedBox(height: 12),
        _buildFamilyOverviewCard(controller),
      ],
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

  Widget _buildFamilyCreateCard(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('가정 등록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '홈스쿨 내 가정 단위를 먼저 만들고 아이를 연결합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _familyNameController,
              decoration: const InputDecoration(labelText: '가정 이름'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _familyNoteController,
              decoration: const InputDecoration(labelText: '메모'),
              minLines: 1,
              maxLines: 2,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.isBusy ? null : _createFamily,
                  icon: const Icon(Icons.group_add),
                  label: const Text('가정 생성'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy ? null : _refreshFamilyDomain,
                  icon: const Icon(Icons.refresh),
                  label: const Text('가정/아이 새로고침'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildCreateCard(NestController controller) {
    final familyItems = controller.families
        .map(
          (family) => DropdownMenuItem(
            value: family.id,
            child: Text(family.familyName),
          ),
        )
        .toList(growable: false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('아이 등록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (familyItems.isEmpty)
              const Text('먼저 가정을 등록하세요.')
            else ...[
              DropdownButtonFormField<String>(
                initialValue: _selectedFamilyId,
                decoration: const InputDecoration(labelText: '소속 가정'),
                items: familyItems,
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _selectedFamilyId = value;
                        });
                      },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _childNameController,
                decoration: const InputDecoration(labelText: '아이 이름'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _birthDateController,
                decoration: const InputDecoration(
                  labelText: '생년월일 (YYYY-MM-DD)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _childNoteController,
                decoration: const InputDecoration(labelText: '프로필 메모'),
                minLines: 1,
                maxLines: 3,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: controller.isBusy ? null : _createChild,
                icon: const Icon(Icons.child_friendly),
                label: const Text('아이 등록'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnrollmentCard(NestController controller) {
    final classItems = controller.classGroups
        .map(
          (group) => DropdownMenuItem(value: group.id, child: Text(group.name)),
        )
        .toList(growable: false);

    final classGroupId = _selectedClassGroupId;
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
            if (classItems.isEmpty)
              const Text('현재 학기에 반이 없습니다.')
            else
              DropdownButtonFormField<String>(
                initialValue: classGroupId,
                decoration: const InputDecoration(labelText: '반 선택'),
                items: classItems,
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _selectedClassGroupId = value;
                        });
                      },
              ),
            const SizedBox(height: 8),
            if (controller.children.isEmpty)
              const Text('등록된 아이가 없습니다.')
            else
              ...controller.children.map((child) {
                final checked = enrolledIds.contains(child.id);
                return CheckboxListTile(
                  value: checked,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(child.name),
                  subtitle: Text('${child.familyName} · ${child.status}'),
                  onChanged: controller.isBusy || classGroupId == null
                      ? null
                      : (value) => _toggleEnrollment(
                          childId: child.id,
                          checked: value == true,
                          classGroupId: classGroupId,
                        ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherProfileCard(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('교사 프로필 등록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '시간표 배정을 위해 교사 프로필을 생성합니다. (부모교사/초청교사)',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _teacherDisplayNameController,
              decoration: const InputDecoration(labelText: '표시 이름'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _teacherUserIdController,
              decoration: const InputDecoration(
                labelText: '연결 사용자 ID (선택)',
                hintText: 'auth.users.id',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _teacherType,
              decoration: const InputDecoration(labelText: '교사 유형'),
              items: const [
                DropdownMenuItem(
                  value: 'PARENT_TEACHER',
                  child: Text('PARENT_TEACHER'),
                ),
                DropdownMenuItem(
                  value: 'GUEST_TEACHER',
                  child: Text('GUEST_TEACHER'),
                ),
              ],
              onChanged: controller.isBusy
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _teacherType = value;
                      });
                    },
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: controller.isBusy ? null : _createTeacherProfile,
              icon: const Icon(Icons.person_add),
              label: const Text('교사 프로필 생성'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyOverviewCard(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('가정 현황', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (controller.families.isEmpty)
              const Text('등록된 가정이 없습니다.')
            else
              ...controller.families.map((family) {
                final familyChildren = controller.childrenForFamily(family.id);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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
                          family.familyName,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if (family.note.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              family.note,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        const SizedBox(height: 8),
                        if (familyChildren.isEmpty)
                          const Text('등록된 아이 없음')
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: familyChildren
                                .map((child) => Chip(label: Text(child.name)))
                                .toList(growable: false),
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

  Future<void> _createFamily() async {
    try {
      await widget.controller.createFamily(
        familyName: _familyNameController.text,
        note: _familyNoteController.text,
      );
      _familyNameController.clear();
      _familyNoteController.clear();
      setState(() {
        _selectedFamilyId = widget.controller.families.firstOrNull?.id;
      });
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _createChild() async {
    final familyId = _selectedFamilyId;
    if (familyId == null || familyId.isEmpty) {
      _showMessage('가정을 선택하세요.');
      return;
    }

    try {
      await widget.controller.createChild(
        familyId: familyId,
        name: _childNameController.text,
        birthDate: _birthDateController.text,
        profileNote: _childNoteController.text,
      );
      _childNameController.clear();
      _childNoteController.clear();
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
      await widget.controller.loadChildren();
      await widget.controller.loadClassEnrollments();
      await widget.controller.loadTeacherProfiles();
      _showMessage('가정/아이/배정 목록을 갱신했습니다.');
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _createTeacherProfile() async {
    try {
      await widget.controller.createTeacherProfile(
        displayName: _teacherDisplayNameController.text,
        teacherType: _teacherType,
        userId: _teacherUserIdController.text,
      );
      _teacherDisplayNameController.clear();
      _teacherUserIdController.clear();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
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
