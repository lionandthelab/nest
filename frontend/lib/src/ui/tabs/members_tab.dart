import 'package:flutter/material.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class MembersTab extends StatefulWidget {
  const MembersTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  final _targetUserIdController = TextEditingController();
  String _targetRole = 'TEACHER';

  @override
  void dispose() {
    _targetUserIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    if (!controller.canManageMemberships) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Member Admin',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text('홈스쿨 관리자만 권한 관리를 할 수 있습니다.'),
            ],
          ),
        ),
      );
    }

    final userIds = controller.membershipUserIds.toList(growable: false)
      ..sort();

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Member & Role Admin',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '관리자는 사용자에게 부모/교사/관리자 권한을 부여하고 회수할 수 있습니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _targetUserIdController,
                  decoration: const InputDecoration(
                    labelText: '대상 사용자 ID (UUID)',
                    hintText: 'auth.users.id',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _targetRole,
                  decoration: const InputDecoration(labelText: '권한'),
                  items: const [
                    DropdownMenuItem(value: 'PARENT', child: Text('PARENT')),
                    DropdownMenuItem(value: 'TEACHER', child: Text('TEACHER')),
                    DropdownMenuItem(
                      value: 'GUEST_TEACHER',
                      child: Text('GUEST_TEACHER'),
                    ),
                    DropdownMenuItem(value: 'STAFF', child: Text('STAFF')),
                    DropdownMenuItem(
                      value: 'HOMESCHOOL_ADMIN',
                      child: Text('HOMESCHOOL_ADMIN'),
                    ),
                  ],
                  onChanged: controller.isBusy
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _targetRole = value;
                          });
                        },
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.isBusy ? null : _grantRole,
                      icon: const Icon(Icons.add_moderator),
                      label: const Text('권한 부여'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy ? null : _reloadMembers,
                      icon: const Icon(Icons.refresh),
                      label: const Text('목록 새로고침'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('현재 멤버 권한', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                if (userIds.isEmpty)
                  const Text('멤버십 정보가 없습니다.')
                else
                  ...userIds.map((userId) => _buildUserRow(controller, userId)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserRow(NestController controller, String userId) {
    final rows = controller.membershipsByUser(userId).toList(growable: false)
      ..sort((a, b) => _rolePriority(a.role).compareTo(_rolePriority(b.role)));

    final activeRows = rows
        .where((row) => row.status == 'ACTIVE')
        .toList(growable: false);

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
            Text(userId, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            if (activeRows.isEmpty)
              Text('ACTIVE 권한 없음', style: Theme.of(context).textTheme.bodySmall)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: activeRows
                    .map(
                      (row) => ActionChip(
                        label: Text(row.role),
                        avatar: const Icon(Icons.verified_user, size: 16),
                        onPressed: controller.isBusy
                            ? null
                            : () => _revokeRole(userId: userId, role: row.role),
                      ),
                    )
                    .toList(growable: false),
              ),
          ],
        ),
      ),
    );
  }

  int _rolePriority(String role) {
    return switch (role) {
      'HOMESCHOOL_ADMIN' => 0,
      'STAFF' => 1,
      'TEACHER' => 2,
      'GUEST_TEACHER' => 3,
      'PARENT' => 4,
      _ => 99,
    };
  }

  Future<void> _grantRole() async {
    try {
      await widget.controller.grantMembershipRole(
        targetUserId: _targetUserIdController.text,
        role: _targetRole,
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _revokeRole({
    required String userId,
    required String role,
  }) async {
    try {
      await widget.controller.revokeMembershipRole(
        targetUserId: userId,
        role: role,
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _reloadMembers() async {
    try {
      await widget.controller.loadHomeschoolMemberships();
      _showMessage('멤버 권한 목록을 갱신했습니다.');
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
