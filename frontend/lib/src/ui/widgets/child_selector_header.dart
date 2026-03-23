import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import 'entity_visuals.dart';
import 'search_select_field.dart';

class ChildSelectorHeader extends StatelessWidget {
  const ChildSelectorHeader({
    super.key,
    required this.controller,
    required this.selectedChildId,
    required this.childClassBundles,
    required this.onSelectChild,
    required this.isLoadingChildClasses,
  });

  final NestController controller;
  final String? selectedChildId;
  final Map<String, ChildClassBundle> childClassBundles;
  final ValueChanged<String?> onSelectChild;
  final bool isLoadingChildClasses;

  @override
  Widget build(BuildContext context) {
    final myChildren = controller.myChildren.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final selectedChild = myChildren
        .where((child) => child.id == selectedChildId)
        .firstOrNull;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (myChildren.isEmpty) ...[
              _buildEmptyHint('연결된 아이가 없습니다.'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () => _showRegisterChildDialog(context),
                icon: const Icon(Icons.child_care),
                label: const Text('내 아이 등록 요청'),
              ),
            ] else ...[
              SelectFieldCard(
                label: '아이 선택',
                hintText: '아이를 선택하세요',
                icon: Icons.child_care_outlined,
                enabled: true,
                value: selectedChild == null
                    ? null
                    : '${selectedChild.name} (${selectedChild.familyName})',
                onTap: () => _selectChild(context, myChildren, selectedChildId),
              ),
              if (selectedChild != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: LinearGradient(
                      colors: [
                        NestColors.roseMist.withValues(alpha: 0.88),
                        Colors.white,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: NestColors.roseMist),
                  ),
                  child: Row(
                    children: [
                      EntityAvatar(
                        label: selectedChild.name,
                        icon: Icons.child_care_outlined,
                        size: 52,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedChild.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              selectedChild.familyName,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: NestColors.deepWood.withValues(
                                      alpha: 0.72,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  avatar: const Icon(
                                    Icons.flag_circle_outlined,
                                    size: 14,
                                  ),
                                  label: Text(_childStatusLabel(selectedChild.status)),
                                  visualDensity: VisualDensity.compact,
                                ),
                                Chip(
                                  avatar: const Icon(
                                    Icons.cake_outlined,
                                    size: 14,
                                  ),
                                  label: Text(
                                    selectedChild.birthDate == null
                                        ? '생일 미등록'
                                        : DateFormat(
                                            'yyyy-MM-dd',
                                          ).format(selectedChild.birthDate!),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (childClassBundles.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('소속 반', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 6),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 640;
                      final itemWidth = compact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 10) / 2;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: childClassBundles.values
                            .map(
                              (bundle) => SizedBox(
                                width: itemWidth,
                                child: LabeledEntityTile(
                                  title: bundle.classGroup.name,
                                  subtitle: '주간 ${bundle.sessions.length}수업',
                                  icon: Icons.groups_2_outlined,
                                  compact: true,
                                  trailing: Icon(
                                    Icons.chevron_right,
                                    color: NestColors.deepWood.withValues(
                                      alpha: 0.55,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                ],
                if (isLoadingChildClasses) ...[
                  const SizedBox(height: 8),
                  const LinearProgressIndicator(),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectChild(
    BuildContext context,
    List<ChildProfile> children,
    String? selectedChildId,
  ) async {
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
      helpText: '아이별 시간표/학습 현황을 확인할 대상을 선택하세요.',
      options: options,
      currentValue: selectedChildId,
    );
    if (selected == null) {
      return;
    }
    onSelectChild(selected);
  }

  Future<void> _showRegisterChildDialog(BuildContext context) async {
    final familyNameCtrl = TextEditingController();
    final childNameCtrl = TextEditingController();
    DateTime? birthDate;

    // Pre-fill family name from user metadata
    final meta = controller.user?.userMetadata;
    final fullName = meta?['full_name'];
    if (fullName is String && fullName.trim().isNotEmpty) {
      familyNameCtrl.text = '${fullName.trim()} 가정';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('내 아이 등록 요청'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: familyNameCtrl,
                      decoration: const InputDecoration(
                        labelText: '가정 이름',
                        hintText: '예: 홍길동 가정',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: childNameCtrl,
                      decoration: const InputDecoration(
                        labelText: '아이 이름',
                        hintText: '예: 홍길순',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        birthDate == null
                            ? '생년월일 (선택)'
                            : DateFormat('yyyy-MM-dd').format(birthDate!),
                      ),
                      trailing: const Icon(Icons.calendar_today, size: 18),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2018, 1, 1),
                          firstDate: DateTime(2005),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => birthDate = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('취소'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('요청'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    final familyName = familyNameCtrl.text.trim();
    final childName = childNameCtrl.text.trim();
    familyNameCtrl.dispose();
    childNameCtrl.dispose();

    if (familyName.isEmpty || childName.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가정 이름과 아이 이름을 입력하세요.')),
        );
      }
      return;
    }

    try {
      await controller.requestChildRegistration(
        familyName: familyName,
        childName: childName,
        birthDate: birthDate == null
            ? null
            : DateFormat('yyyy-MM-dd').format(birthDate!),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(controller.statusMessage)),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(controller.statusMessage)),
        );
      }
    }
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
}

String _childStatusLabel(String status) {
  return switch (status) {
    'ACTIVE' => '활동 중',
    'INACTIVE' => '비활동',
    'GRADUATED' => '졸업',
    _ => status,
  };
}
