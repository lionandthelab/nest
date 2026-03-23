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
  String? _selectedUserId;
  final _inviteEmailController = TextEditingController();
  String _targetRole = 'TEACHER';
  String _inviteRole = 'PARENT';
  int _inviteExpireDays = 14;
  bool _showCancelled = false;

  @override
  void dispose() {
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
                '멤버 관리',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              const Text('홈스쿨 관리자만 권한 관리를 할 수 있습니다.'),
            ],
          ),
        ),
      );
    }

    final pendingRequests =
        controller.joinRequests.where((r) => r.isPending).toList();

    return ListView(
      children: [
        if (pendingRequests.isNotEmpty) ...[
          _buildJoinRequestCard(controller, pendingRequests),
          const SizedBox(height: 12),
        ],
        _buildRoleGrantCard(controller),
        const SizedBox(height: 12),
        _buildInviteCreateCard(controller),
        const SizedBox(height: 12),
        _buildMemberListCard(controller),
      ],
    );
  }

  Widget _buildJoinRequestCard(
    NestController controller,
    List<HomeschoolJoinRequest> requests,
  ) {
    return Card(
      color: NestColors.roseMist.withValues(alpha: 0.15),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_add, size: 20, color: NestColors.clay),
                const SizedBox(width: 8),
                Text(
                  '가입 요청 (${requests.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '새로운 멤버가 홈스쿨 가입을 요청했습니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            ...requests.map((req) => _buildJoinRequestRow(controller, req)),
          ],
        ),
      ),
    );
  }

  Widget _buildJoinRequestRow(
    NestController controller,
    HomeschoolJoinRequest req,
  ) {
    final created = req.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(req.createdAt!);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  req.requesterName ?? req.requesterEmail,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            req.requesterEmail,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (req.requestNote != null && req.requestNote!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '메모: ${req.requestNote}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          Text(
            '요청일: $created',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () => _rejectRequest(req.id),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('거절'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () => _approveRequest(req.id, req.requesterUserId),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('승인'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(String requestId, String userId) async {
    try {
      await widget.controller.approveJoinRequest(
        requestId: requestId,
        requesterUserId: userId,
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      await widget.controller.rejectJoinRequest(requestId: requestId);
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Widget _buildRoleGrantCard(NestController controller) {
    // Build member selector items from existing members
    final userIds = controller.membershipUserIds.toList(growable: false);
    final memberItems = <DropdownMenuItem<String>>[];
    for (final uid in userIds) {
      final name = controller.findMemberDisplayName(uid);
      memberItems.add(DropdownMenuItem(
        value: uid,
        child: Text(name, overflow: TextOverflow.ellipsis),
      ));
    }
    // Sort by display name
    memberItems.sort((a, b) => (a.child as Text)
        .data!
        .toLowerCase()
        .compareTo((b.child as Text).data!.toLowerCase()));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '멤버 권한 관리',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              '기존 멤버를 선택하여 권한을 부여/회수합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedUserId,
              decoration: const InputDecoration(labelText: '대상 멤버'),
              isExpanded: true,
              items: memberItems,
              onChanged: controller.isBusy
                  ? null
                  : (value) {
                      setState(() {
                        _selectedUserId = value;
                      });
                    },
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
                  onPressed: controller.isBusy || _selectedUserId == null
                      ? null
                      : _grantRole,
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
    final invites = controller.homeschoolInvites.toList(growable: false)
      ..sort((a, b) {
        final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });
    final pendingCount =
        invites.where((i) => i.status == 'PENDING').length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('이메일 초대',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
                ActionChip(
                  avatar: Icon(
                    Icons.mail_outline,
                    size: 16,
                    color: pendingCount > 0
                        ? NestColors.clay
                        : NestColors.deepWood.withValues(alpha: 0.5),
                  ),
                  label: Text(
                    '초대 현황${pendingCount > 0 ? ' ($pendingCount)' : ''}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  onPressed: () => _showInviteStatusDialog(invites),
                ),
              ],
            ),
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

  void _showInviteStatusDialog(List<HomeschoolInvite> invites) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = _showCancelled
                ? invites
                : invites
                    .where((i) => i.status != 'CANCELED')
                    .toList(growable: false);

            return AlertDialog(
              title: Row(
                children: [
                  const Expanded(child: Text('초대 현황')),
                  FilterChip(
                    selected: _showCancelled,
                    label: const Text('취소됨 포함'),
                    onSelected: (v) {
                      setState(() => _showCancelled = v);
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: filtered.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: NestEmptyState(
                          icon: Icons.mail_outline,
                          title: '초대 내역이 없습니다.',
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final invite = filtered[index];
                          return _buildInviteRow(invite);
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('닫기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInviteRow(HomeschoolInvite invite) {
    final created = invite.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(invite.createdAt!);
    final expires = invite.expiresAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd').format(invite.expiresAt!);

    return Container(
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
                label: Text(_statusLabel(invite.status)),
                backgroundColor: _statusColor(invite.status),
              ),
              Chip(label: Text(_roleLabel(invite.role))),
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
                onPressed: widget.controller.isBusy
                    ? null
                    : () {
                        _cancelInvite(invite.id);
                        Navigator.of(context).pop();
                      },
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('초대 취소'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMemberListCard(NestController controller) {
    final userIds = controller.membershipUserIds.toList(growable: false);

    // Build a map: role -> list of (userId, displayName)
    final roleMap = <String, List<({String userId, String name})>>{};
    for (final uid in userIds) {
      final memberships = controller.membershipsByUser(uid);
      final name = controller.findMemberDisplayName(uid);
      for (final m in memberships) {
        if (m.status != 'ACTIVE') continue;
        roleMap.putIfAbsent(m.role, () => []);
        roleMap[m.role]!.add((userId: uid, name: name));
      }
    }

    // Sort roles by priority, members by name within each role
    final sortedRoles = roleMap.keys.toList()
      ..sort((a, b) => _rolePriority(a).compareTo(_rolePriority(b)));

    for (final role in sortedRoles) {
      roleMap[role]!.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('현재 멤버 권한',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (sortedRoles.isEmpty)
              const NestEmptyState(
                icon: Icons.people_outline,
                title: '멤버십 정보가 없습니다.',
              )
            else
              ...sortedRoles.map((role) {
                final members = roleMap[role]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: NestColors.roseMist.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${_roleLabel(role)} (${members.length})',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...members.map((m) => Padding(
                            padding: const EdgeInsets.only(
                                left: 8, bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.person_outline, size: 18),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    m.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                  ),
                                ),
                                ActionChip(
                                  label: const Text('회수'),
                                  avatar: const Icon(
                                      Icons.remove_circle_outline,
                                      size: 16),
                                  onPressed: controller.isBusy
                                      ? null
                                      : () => _revokeRole(
                                          userId: m.userId, role: role),
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                );
              }),
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
    DropdownMenuItem(value: 'PARENT', child: Text('부모')),
    DropdownMenuItem(value: 'TEACHER', child: Text('교사')),
    DropdownMenuItem(value: 'GUEST_TEACHER', child: Text('외부교사')),
    DropdownMenuItem(value: 'STAFF', child: Text('스태프')),
    DropdownMenuItem(
      value: 'HOMESCHOOL_ADMIN',
      child: Text('관리자'),
    ),
  ];

  String _statusLabel(String status) {
    return switch (status) {
      'PENDING' => '대기 중',
      'ACCEPTED' => '수락됨',
      'CANCELED' => '취소됨',
      'EXPIRED' => '만료됨',
      _ => status,
    };
  }

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
    if (_selectedUserId == null) return;
    try {
      await widget.controller.grantMembershipRole(
        targetUserId: _selectedUserId!,
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
