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
    final myChildren = controller.myChildren.toList(growable: false)
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
            if (myChildren.isEmpty)
              _buildEmptyHint('연결된 아이가 없습니다. 관리자에게 가정/아이 배정을 요청하세요.')
            else ...[
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
