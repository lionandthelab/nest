import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
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
  final _classNameController = TextEditingController();
  final _classCapacityController = TextEditingController(text: '12');
  final _teacherDisplayNameController = TextEditingController();
  final _teacherAccountSearchController = TextEditingController();
  late final TextEditingController _birthDateController;

  String? _selectedFamilyId;
  String? _selectedClassGroupId;
  String? _classFormBoundToId;
  String _teacherType = 'GUEST_TEACHER';
  bool _linkTeacherAccount = false;
  HomeschoolMemberDirectoryEntry? _selectedTeacherAccount;
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
    _classNameController.dispose();
    _classCapacityController.dispose();
    _teacherDisplayNameController.dispose();
    _teacherAccountSearchController.dispose();
    _birthDateController.dispose();
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
        _buildClassCrudCard(controller),
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

  Widget _buildClassCrudCard(NestController controller) {
    final classItems = controller.classGroups
        .map(
          (group) => DropdownMenuItem(value: group.id, child: Text(group.name)),
        )
        .toList(growable: false);

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
            if (classItems.isEmpty)
              const Text('현재 학기에 등록된 반이 없습니다. 아래 정보로 새 반을 생성하세요.')
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedClassGroupId,
                decoration: const InputDecoration(labelText: '편집 대상 반'),
                items: classItems,
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _selectedClassGroupId = value;
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
    final memberMatches = controller.searchHomeschoolMemberDirectory(
      _teacherAccountSearchController.text,
      maxResults: 8,
    );

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
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('기존 계정 연결'),
              subtitle: const Text('이름/이메일/ID 검색으로 기존 계정을 연결합니다.'),
              value: _linkTeacherAccount,
              onChanged: controller.isBusy
                  ? null
                  : (value) {
                      setState(() {
                        _linkTeacherAccount = value;
                        _selectedTeacherAccount = null;
                        _teacherAccountSearchController.clear();
                      });
                    },
            ),
            if (_linkTeacherAccount) ...[
              TextField(
                controller: _teacherAccountSearchController,
                decoration: const InputDecoration(
                  labelText: '계정 검색',
                  hintText: '이름, 이메일, UUID로 검색',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 8),
              if (memberMatches.isEmpty)
                const Text('검색 결과가 없습니다.')
              else
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: NestColors.roseMist),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: memberMatches.length,
                    itemBuilder: (context, index) {
                      final member = memberMatches[index];
                      final selected =
                          _selectedTeacherAccount?.userId == member.userId;
                      return ListTile(
                        dense: true,
                        selected: selected,
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          size: 18,
                        ),
                        title: Text(
                          member.fullName.trim().isEmpty
                              ? member.email
                              : member.fullName,
                        ),
                        subtitle: Text(
                          '${member.email.isEmpty ? member.userId : member.email} · ${member.roles.join(', ')}',
                        ),
                        onTap: controller.isBusy
                            ? null
                            : () {
                                setState(() {
                                  _selectedTeacherAccount = member;
                                  if (_teacherDisplayNameController.text
                                      .trim()
                                      .isEmpty) {
                                    _teacherDisplayNameController.text =
                                        member.fullName.trim().isNotEmpty
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
              if (_selectedTeacherAccount != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Chip(
                    avatar: const Icon(Icons.link, size: 16),
                    label: Text(_selectedTeacherAccount!.displayLabel),
                    onDeleted: controller.isBusy
                        ? null
                        : () {
                            setState(() {
                              _selectedTeacherAccount = null;
                            });
                          },
                  ),
                ),
            ] else
              Text(
                '계정이 아직 없는 선생님은 초청교사로 등록할 수 있습니다.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _teacherDisplayNameController,
              decoration: const InputDecoration(labelText: '표시 이름'),
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
      await widget.controller.loadChildren();
      await widget.controller.loadClassEnrollments();
      await widget.controller.loadTeacherProfiles();
      await widget.controller.loadHomeschoolMemberDirectory();
      _showMessage('가정/아이/배정 목록을 갱신했습니다.');
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _createTeacherProfile() async {
    if (_linkTeacherAccount && _selectedTeacherAccount == null) {
      _showMessage('연결할 계정을 먼저 검색해 선택하세요.');
      return;
    }

    try {
      await widget.controller.createTeacherProfile(
        displayName: _teacherDisplayNameController.text,
        teacherType: _teacherType,
        userId: _linkTeacherAccount ? _selectedTeacherAccount?.userId : null,
      );
      _teacherDisplayNameController.clear();
      _teacherAccountSearchController.clear();
      setState(() {
        _selectedTeacherAccount = null;
      });
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
