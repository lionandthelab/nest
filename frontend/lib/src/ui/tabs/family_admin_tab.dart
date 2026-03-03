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
  final _quickClassPrefixController = TextEditingController(text: 'Robin');
  final _quickClassCountController = TextEditingController(text: '2');
  final _quickCapacityController = TextEditingController(text: '12');
  final _quickTeacherNamesController = TextEditingController(
    text: '초청교사A, 초청교사B',
  );
  final _teacherDisplayNameController = TextEditingController();
  final _teacherAccountSearchController = TextEditingController();
  final _courseNameController = TextEditingController();
  final _courseDurationController = TextEditingController(text: '50');
  final _unavailabilityStartController = TextEditingController(text: '09:00');
  final _unavailabilityEndController = TextEditingController(text: '10:00');
  final _unavailabilityNoteController = TextEditingController();
  late final TextEditingController _birthDateController;

  String? _selectedFamilyId;
  String? _selectedClassGroupId;
  String? _classFormBoundToId;
  String _teacherType = 'GUEST_TEACHER';
  bool _linkTeacherAccount = false;
  HomeschoolMemberDirectoryEntry? _selectedTeacherAccount;
  bool _familyInitialized = false;
  bool _classInitialized = false;
  String _unavailabilityOwnerKind = 'TEACHER_PROFILE';
  String? _selectedUnavailabilityOwnerId;
  int _selectedUnavailabilityDay = 1;
  String _setupUnit = 'FAMILY';
  List<String> _quickDraftClassNames = const [];
  List<String> _quickDraftTeacherNames = const [];

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
    _quickClassPrefixController.dispose();
    _quickClassCountController.dispose();
    _quickCapacityController.dispose();
    _quickTeacherNamesController.dispose();
    _teacherDisplayNameController.dispose();
    _teacherAccountSearchController.dispose();
    _courseNameController.dispose();
    _courseDurationController.dispose();
    _unavailabilityStartController.dispose();
    _unavailabilityEndController.dispose();
    _unavailabilityNoteController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    _syncSelections(controller);
    _syncClassForm(controller);
    _syncUnavailabilitySelection(controller);

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
        _buildFamilyCreateCard(controller),
        const SizedBox(height: 12),
        _buildChildCreateCard(controller),
        const SizedBox(height: 12),
        _buildFamilyOverviewCard(controller),
      ],
      'TEACHER' => [
        _buildTeacherProfileCard(controller),
        const SizedBox(height: 12),
        _buildMemberUnavailabilityCard(controller),
      ],
      'CLASS' => [
        _buildQuickOnboardingCard(controller),
        const SizedBox(height: 12),
        _buildClassCrudCard(controller),
        const SizedBox(height: 12),
        _buildEnrollmentCard(controller),
      ],
      'COURSE' => [_buildCourseManageCard(controller)],
      _ => [_buildFamilyCreateCard(controller)],
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

  void _syncUnavailabilitySelection(NestController controller) {
    final ownerIds = _unavailabilityOwnerKind == 'TEACHER_PROFILE'
        ? controller.teacherProfiles
              .map((row) => row.id)
              .toList(growable: false)
        : controller.parentCandidateUserIds.toList(growable: false);

    if (ownerIds.isEmpty) {
      _selectedUnavailabilityOwnerId = null;
      return;
    }

    if (_selectedUnavailabilityOwnerId == null ||
        !ownerIds.contains(_selectedUnavailabilityOwnerId)) {
      _selectedUnavailabilityOwnerId = ownerIds.first;
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

  Widget _buildQuickOnboardingCard(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('운영 초안 생성기', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '몇 가지 질문으로 반/교사 초안을 먼저 만든 뒤, 목록을 보정하고 일괄 생성할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _quickClassPrefixController,
              decoration: const InputDecoration(labelText: '질문 1) 반 이름 접두어'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _quickClassCountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '질문 2) 만들 반 개수',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _quickCapacityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '질문 3) 반 기본 정원',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _quickTeacherNamesController,
              decoration: const InputDecoration(
                labelText: '질문 4) 교사 이름(콤마 구분)',
                hintText: '예: 김민지, 이도윤, Park Teacher',
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.isBusy ? null : _buildQuickDraft,
                  icon: const Icon(Icons.auto_fix_high),
                  label: const Text('초안 만들기'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy || _quickDraftClassNames.isEmpty
                      ? null
                      : _applyQuickDraft,
                  icon: const Icon(Icons.done_all),
                  label: const Text('초안 일괄 생성'),
                ),
              ],
            ),
            if (_quickDraftClassNames.isNotEmpty ||
                _quickDraftTeacherNames.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('생성 예정 반', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              if (_quickDraftClassNames.isEmpty)
                const Text('없음')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickDraftClassNames
                      .map((name) => Chip(label: Text(name)))
                      .toList(growable: false),
                ),
              const SizedBox(height: 8),
              Text('생성 예정 교사', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              if (_quickDraftTeacherNames.isEmpty)
                const Text('없음')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickDraftTeacherNames
                      .map((name) => Chip(label: Text(name)))
                      .toList(growable: false),
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

  Widget _buildMemberUnavailabilityCard(NestController controller) {
    final isTeacher = _unavailabilityOwnerKind == 'TEACHER_PROFILE';
    final ownerItems = isTeacher
        ? controller.teacherProfiles
              .map(
                (row) => DropdownMenuItem<String>(
                  value: row.id,
                  child: Text(row.displayName),
                ),
              )
              .toList(growable: false)
        : controller.parentCandidateUserIds
              .map(
                (userId) => DropdownMenuItem<String>(
                  value: userId,
                  child: Text(controller.findMemberDisplayName(userId)),
                ),
              )
              .toList(growable: false);

    final blocks = controller.memberUnavailabilityBlocks.toList(growable: false)
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) {
          return day;
        }
        final start = a.startTime.compareTo(b.startTime);
        if (start != 0) {
          return start;
        }
        return controller
            .findAvailabilityOwnerLabel(a)
            .compareTo(controller.findAvailabilityOwnerLabel(b));
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('교사/부모 불가 시간', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '설정한 불가 시간은 시간표 초안 생성 시 자동 회피됩니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'TEACHER_PROFILE', label: Text('교사')),
                ButtonSegment(value: 'MEMBER_USER', label: Text('부모')),
              ],
              selected: {_unavailabilityOwnerKind},
              onSelectionChanged: controller.isBusy
                  ? null
                  : (values) {
                      if (values.isEmpty) {
                        return;
                      }
                      setState(() {
                        _unavailabilityOwnerKind = values.first;
                        _syncUnavailabilitySelection(controller);
                      });
                    },
            ),
            const SizedBox(height: 8),
            if (ownerItems.isEmpty)
              Text(isTeacher ? '등록된 교사가 없습니다.' : '선택 가능한 부모 계정이 없습니다.')
            else
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'owner-${_unavailabilityOwnerKind}_${_selectedUnavailabilityOwnerId ?? ''}',
                ),
                initialValue: _selectedUnavailabilityOwnerId,
                decoration: const InputDecoration(labelText: '대상'),
                items: ownerItems,
                onChanged: controller.isBusy
                    ? null
                    : (value) {
                        setState(() {
                          _selectedUnavailabilityOwnerId = value;
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
                  child: TextField(
                    controller: _unavailabilityStartController,
                    decoration: const InputDecoration(labelText: '시작 (HH:MM)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _unavailabilityEndController,
                    decoration: const InputDecoration(labelText: '종료 (HH:MM)'),
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
              onPressed: controller.isBusy || ownerItems.isEmpty
                  ? null
                  : _createUnavailabilityBlock,
              icon: const Icon(Icons.block),
              label: const Text('불가 시간 추가'),
            ),
            const SizedBox(height: 10),
            Text('등록된 불가 시간', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            if (blocks.isEmpty)
              const Text('등록된 불가 시간이 없습니다.')
            else
              ...blocks.map((block) {
                final label = controller.findAvailabilityOwnerLabel(block);
                final day = _dayLabel(block.dayOfWeek);
                final start = _shortTime(block.startTime);
                final end = _shortTime(block.endTime);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
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
                              Text(label),
                              const SizedBox(height: 2),
                              Text(
                                '$day $start-$end${block.note.trim().isEmpty ? '' : ' · ${block.note.trim()}'}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: controller.isBusy
                              ? null
                              : () => _deleteUnavailabilityBlock(block.id),
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

  void _buildQuickDraft() {
    final prefix = _quickClassPrefixController.text.trim();
    final classCount =
        int.tryParse(_quickClassCountController.text.trim()) ?? 0;

    if (prefix.isEmpty || classCount <= 0) {
      _showMessage('반 접두어와 개수를 올바르게 입력하세요.');
      return;
    }

    final classNames = List.generate(
      classCount,
      (index) => '$prefix ${index + 1}',
    );

    final teacherNames = _quickTeacherNamesController.text
        .split(',')
        .map((name) => name.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList(growable: false);

    setState(() {
      _quickDraftClassNames = classNames;
      _quickDraftTeacherNames = teacherNames;
    });
    _showMessage('초안을 생성했습니다. 목록을 확인하고 일괄 생성하세요.');
  }

  Future<void> _applyQuickDraft() async {
    if (_quickDraftClassNames.isEmpty && _quickDraftTeacherNames.isEmpty) {
      _showMessage('먼저 초안을 만드세요.');
      return;
    }

    final capacity = int.tryParse(_quickCapacityController.text.trim());
    if (capacity == null || capacity < 1 || capacity > 200) {
      _showMessage('기본 정원은 1~200 사이 숫자로 입력하세요.');
      return;
    }

    var createdClasses = 0;
    var skippedClasses = 0;
    var createdTeachers = 0;
    var skippedTeachers = 0;

    try {
      for (final className in _quickDraftClassNames) {
        final exists = widget.controller.classGroups.any(
          (group) => group.name.trim() == className,
        );
        if (exists) {
          skippedClasses += 1;
          continue;
        }
        await widget.controller.createClassGroup(
          name: className,
          capacity: capacity,
        );
        createdClasses += 1;
      }

      for (final teacherName in _quickDraftTeacherNames) {
        final exists = widget.controller.teacherProfiles.any(
          (profile) => profile.displayName.trim() == teacherName,
        );
        if (exists) {
          skippedTeachers += 1;
          continue;
        }
        await widget.controller.createTeacherProfile(
          displayName: teacherName,
          teacherType: 'GUEST_TEACHER',
        );
        createdTeachers += 1;
      }

      await widget.controller.loadClassEnrollments();
      await widget.controller.loadTeacherProfiles();
      setState(() {
        _quickDraftClassNames = const [];
        _quickDraftTeacherNames = const [];
      });
      _showMessage(
        '일괄 생성 완료: 반 $createdClasses개(중복 $skippedClasses개), 교사 $createdTeachers명(중복 $skippedTeachers명)',
      );
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

  Future<void> _createUnavailabilityBlock() async {
    final ownerId = _selectedUnavailabilityOwnerId;
    if (ownerId == null || ownerId.isEmpty) {
      _showMessage('대상을 선택하세요.');
      return;
    }

    try {
      await widget.controller.createMemberUnavailabilityBlock(
        ownerKind: _unavailabilityOwnerKind,
        ownerId: ownerId,
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
