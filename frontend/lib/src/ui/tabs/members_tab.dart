import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/nest_empty_state.dart';

class MembersTab extends StatefulWidget {
  const MembersTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<MembersTab> {
  final _targetUserIdController = TextEditingController();
  final _inviteEmailController = TextEditingController();
  String _targetRole = 'TEACHER';
  String _inviteRole = 'PARENT';
  int _inviteExpireDays = 14;

  @override
  void dispose() {
    _targetUserIdController.dispose();
    _inviteEmailController.dispose();
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
    final invites = controller.homeschoolInvites.toList(growable: false)
      ..sort((a, b) {
        final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

    return ListView(
      children: [
        _buildMyRoleSwitchCard(controller),
        const SizedBox(height: 12),
        _buildRoleGrantCard(controller),
        const SizedBox(height: 12),
        _buildInviteCreateCard(controller),
        const SizedBox(height: 12),
        _buildInviteListCard(controller, invites),
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
                  const NestEmptyState(
                    icon: Icons.people_outline,
                    title: '멤버십 정보가 없습니다.',
                  )
                else
                  ...userIds.map((userId) => _buildUserRow(controller, userId)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyRoleSwitchCard(NestController controller) {
    final currentUser = controller.user;
    if (currentUser == null) {
      return const SizedBox.shrink();
    }

    final activeRoles = controller
        .membershipsByUser(currentUser.id)
        .where((row) => row.status == 'ACTIVE')
        .map((row) => row.role)
        .toSet();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('내 계정 역할 전환', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '관리자 계정에 부모/교사 권한을 함께 부여하면, 홈 상단에서 뷰 역할을 즉시 전환할 수 있습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: NestColors.roseMist),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentUser.email ?? currentUser.id,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  SelectableText(
                    currentUser.id,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selfSwitchRoles
                  .map((role) {
                    final enabled = activeRoles.contains(role);
                    return FilterChip(
                      selected: enabled,
                      label: Text(_roleLabel(role)),
                      avatar: Icon(
                        enabled ? Icons.check_circle : Icons.add_circle_outline,
                        size: 16,
                      ),
                      onSelected: controller.isBusy
                          ? null
                          : (selected) =>
                                _toggleMyRole(role: role, enable: selected),
                    );
                  })
                  .toList(growable: false),
            ),
            const SizedBox(height: 8),
            Text(
              '역할 추가 후 홈 헤더의 "뷰 전환" 버튼으로 관리자/부모/교사 모드를 오갈 수 있습니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleGrantCard(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Member Role Admin',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '기존 가입 사용자는 사용자 ID(UUID) 기준으로 권한을 부여/회수합니다. '
              '관리자 본인 다중 역할은 위 카드에서 빠르게 설정하세요.',
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
              items: _roleItems,
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
    );
  }

  Widget _buildInviteCreateCard(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email Invite', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '아직 가입하지 않은 부모/교사를 이메일로 초대하고 권한을 미리 지정합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inviteEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '초대 이메일',
                hintText: 'parent@nest.com',
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _inviteRole,
              decoration: const InputDecoration(labelText: '초대 권한'),
              items: _roleItems,
              onChanged: controller.isBusy
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _inviteRole = value;
                      });
                    },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<int>(
              initialValue: _inviteExpireDays,
              decoration: const InputDecoration(labelText: '만료 기간'),
              items: const [
                DropdownMenuItem(value: 7, child: Text('7일')),
                DropdownMenuItem(value: 14, child: Text('14일')),
                DropdownMenuItem(value: 30, child: Text('30일')),
              ],
              onChanged: controller.isBusy
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _inviteExpireDays = value;
                      });
                    },
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.isBusy ? null : _createInvite,
                  icon: const Icon(Icons.outgoing_mail),
                  label: const Text('초대 생성'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy ? null : _reloadInvites,
                  icon: const Icon(Icons.refresh),
                  label: const Text('초대 목록 갱신'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteListCard(
    NestController controller,
    List<HomeschoolInvite> invites,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('초대 현황', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (invites.isEmpty)
              const NestEmptyState(
                icon: Icons.mail_outline,
                title: '초대 내역이 없습니다.',
              )
            else
              ...invites.map((invite) {
                final created = invite.createdAt == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd HH:mm').format(invite.createdAt!);
                final expires = invite.expiresAt == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd').format(invite.expiresAt!);

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
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(
                              label: Text(invite.status),
                              backgroundColor: _statusColor(invite.status),
                            ),
                            Chip(label: Text(invite.role)),
                            Chip(label: Text('만료: $expires')),
                            Text(
                              '생성: $created',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        SelectableText(invite.inviteEmail),
                        const SizedBox(height: 6),
                        Text(
                          invite.homeschoolName,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (invite.status == 'PENDING')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: FilledButton.tonalIcon(
                              onPressed: controller.isBusy
                                  ? null
                                  : () => _cancelInvite(invite.id),
                              icon: const Icon(Icons.cancel_outlined),
                              label: const Text('초대 취소'),
                            ),
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

  String _roleLabel(String role) {
    return switch (role) {
      'HOMESCHOOL_ADMIN' => '관리자',
      'STAFF' => '스태프',
      'TEACHER' => '교사',
      'GUEST_TEACHER' => '외부교사',
      'PARENT' => '부모',
      _ => role,
    };
  }

  static const List<DropdownMenuItem<String>> _roleItems = [
    DropdownMenuItem(value: 'PARENT', child: Text('PARENT')),
    DropdownMenuItem(value: 'TEACHER', child: Text('TEACHER')),
    DropdownMenuItem(value: 'GUEST_TEACHER', child: Text('GUEST_TEACHER')),
    DropdownMenuItem(value: 'STAFF', child: Text('STAFF')),
    DropdownMenuItem(
      value: 'HOMESCHOOL_ADMIN',
      child: Text('HOMESCHOOL_ADMIN'),
    ),
  ];

  static const List<String> _selfSwitchRoles = [
    'PARENT',
    'TEACHER',
    'GUEST_TEACHER',
  ];

  Color _statusColor(String status) {
    return switch (status) {
      'PENDING' => NestColors.roseMist.withValues(alpha: 0.75),
      'ACCEPTED' => NestColors.mutedSage.withValues(alpha: 0.5),
      'CANCELED' => Colors.grey.shade300,
      'EXPIRED' => Colors.amber.shade100,
      _ => Colors.grey.shade200,
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

  Future<void> _toggleMyRole({
    required String role,
    required bool enable,
  }) async {
    final userId = widget.controller.user?.id;
    if (userId == null || userId.isEmpty) {
      _showMessage('로그인 사용자 정보를 찾지 못했습니다.');
      return;
    }

    try {
      if (enable) {
        await widget.controller.grantMembershipRole(
          targetUserId: userId,
          role: role,
        );
      } else {
        await widget.controller.revokeMembershipRole(
          targetUserId: userId,
          role: role,
        );
      }
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
      await widget.controller.loadHomeschoolInvites();
      _showMessage('멤버 권한 목록을 갱신했습니다.');
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _createInvite() async {
    try {
      await widget.controller.createHomeschoolInvite(
        inviteEmail: _inviteEmailController.text,
        role: _inviteRole,
        expirationDays: _inviteExpireDays,
      );
      _inviteEmailController.clear();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _reloadInvites() async {
    try {
      await widget.controller.loadHomeschoolInvites();
      _showMessage('초대 목록을 갱신했습니다.');
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _cancelInvite(String inviteId) async {
    try {
      await widget.controller.cancelHomeschoolInvite(inviteId);
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
