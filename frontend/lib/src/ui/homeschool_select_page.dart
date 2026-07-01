import 'package:flutter/material.dart';

import '../models/nest_models.dart';
import '../state/nest_controller.dart';
import 'nest_theme.dart';
import 'widgets/entity_visuals.dart';
import 'widgets/homeschool_create_dialog.dart';

/// 홈스쿨 선택 전용 화면.
///
/// 소속 홈스쿨을 (역할이 여러 개여도) **홈스쿨당 카드 1개**로 보여주고, 카드를
/// 누르면 그 홈스쿨의 "가장 최근 역할"로 진입한다. 로그인 직후 다중 소속일 때의
/// 첫 선택 화면으로도, 헤더에서 홈스쿨을 바꿀 때의 전환 화면으로도 쓰인다.
class HomeschoolSelectPage extends StatelessWidget {
  const HomeschoolSelectPage({
    super.key,
    required this.controller,
    required this.onSelect,
    this.showBack = false,
  });

  final NestController controller;

  /// 홈스쿨 id 를 넘겨준다(선택 확정).
  final void Function(String homeschoolId) onSelect;

  /// true 면 AppBar 뒤로가기를 노출(전환 화면). false 면 첫 진입 게이트.
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final homeschools = controller.distinctHomeschools;
        final selectedId = controller.selectedHomeschoolId;
        final content = SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 8),
                  Text(
                    '홈스쿨 선택',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    homeschools.length > 1
                        ? '여러 홈스쿨에 소속되어 있어요. 들어갈 홈스쿨을 선택하세요.'
                        : '홈스쿨을 선택하세요.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.65),
                        ),
                  ),
                  const SizedBox(height: 18),
                  ...homeschools.map(
                    (hs) => _HomeschoolCard(
                      homeschool: hs,
                      roles: controller.rolesForHomeschool(hs.id),
                      recentRole: controller.recentRoleForHomeschool(hs.id),
                      selected: hs.id == selectedId,
                      onTap: () => onSelect(hs.id),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => showHomeschoolCreateDialog(
                      context: context,
                      controller: controller,
                    ),
                    icon: const Icon(Icons.add_home_outlined, size: 18),
                    label: const Text('새 홈스쿨 개설'),
                  ),
                ],
              ),
            ),
          ),
        );

        return Scaffold(
          backgroundColor: NestColors.creamyWhite,
          appBar: showBack
              ? AppBar(
                  title: const Text('홈스쿨 전환'),
                  backgroundColor: NestColors.creamyWhite,
                )
              : null,
          body: content,
        );
      },
    );
  }
}

class _HomeschoolCard extends StatelessWidget {
  const _HomeschoolCard({
    required this.homeschool,
    required this.roles,
    required this.recentRole,
    required this.selected,
    required this.onTap,
  });

  final Homeschool homeschool;
  final List<String> roles;
  final String? recentRole;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? NestColors.dustyRose : NestColors.roseMist,
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                EntityAvatar(
                  label: homeschool.name,
                  icon: Icons.home_outlined,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        homeschool.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final role in roles)
                            _RoleChip(
                              label: _roleLabel(role),
                              highlight: role == recentRole,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? Icons.check_circle : Icons.chevron_right,
                  color: selected ? NestColors.dustyRose : NestColors.clay,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label, required this.highlight});

  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight
            ? NestColors.dustyRose.withValues(alpha: 0.22)
            : NestColors.creamyWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlight ? NestColors.dustyRose : NestColors.roseMist,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (highlight) ...[
            const Icon(Icons.history, size: 12, color: NestColors.deepWood),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: NestColors.deepWood,
            ),
          ),
        ],
      ),
    );
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'HOMESCHOOL_ADMIN':
      return '관리자';
    case 'STAFF':
      return '스태프';
    case 'TEACHER':
      return '교사';
    case 'GUEST_TEACHER':
      return '초청교사';
    case 'PARENT':
      return '학부모';
    default:
      return role;
  }
}
