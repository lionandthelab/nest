import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';

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
              DropdownButtonFormField<String>(
                key: ValueKey('parent-child-${selectedChild?.id ?? ''}'),
                initialValue: selectedChild?.id,
                decoration: const InputDecoration(
                  labelText: '아이 선택',
                  prefixIcon: Icon(Icons.child_care_outlined),
                ),
                items: myChildren
                    .map(
                      (child) => DropdownMenuItem<String>(
                        value: child.id,
                        child: Text('${child.name} (${child.familyName})'),
                      ),
                    )
                    .toList(growable: false),
                onChanged: onSelectChild,
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
                            : DateFormat('yyyy-MM-dd').format(
                                selectedChild.birthDate!,
                              ),
                      ),
                    ),
                  ],
                ),
                if (childClassBundles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: childClassBundles.values
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
