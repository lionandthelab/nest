import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/app_config.dart';
import '../../services/pwa_install_helper.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/nest_empty_state.dart';

class ProfileSettingsTab extends StatefulWidget {
  const ProfileSettingsTab({
    super.key,
    required this.controller,
    this.selectedChildId,
    this.childClassBundles,
  });

  final NestController controller;
  final String? selectedChildId;
  final Map<String, ChildClassBundle>? childClassBundles;

  @override
  State<ProfileSettingsTab> createState() => _ProfileSettingsTabState();
}

class _ProfileSettingsTabState extends State<ProfileSettingsTab> {
  final _unavailabilityStartController = TextEditingController(text: '09:00');
  final _unavailabilityEndController = TextEditingController(text: '10:00');
  final _unavailabilityNoteController = TextEditingController();
  int _selectedUnavailabilityDay = 1;
  final _pwaHelper = createPwaInstallHelper();

  @override
  void dispose() {
    _unavailabilityStartController.dispose();
    _unavailabilityEndController.dispose();
    _unavailabilityNoteController.dispose();
    super.dispose();
  }

  String _displayName(NestController controller) {
    final metadata = controller.user?.userMetadata ?? const <String, dynamic>{};
    final metadataName = metadata['full_name'] ?? metadata['name'];
    if (metadataName is String && metadataName.trim().isNotEmpty) {
      return metadataName.trim();
    }
    final fromDirectory = controller.findMemberDisplayName(controller.user?.id);
    if (fromDirectory.trim().isNotEmpty && fromDirectory != controller.user?.id) {
      return fromDirectory;
    }
    final email = controller.user?.email ?? '';
    if (email.contains('@')) return email.split('@').first;
    return '사용자';
  }

  String _phoneNumber(NestController controller) {
    final metadata = controller.user?.userMetadata ?? const <String, dynamic>{};
    final phone = metadata['phone_number'];
    if (phone is String && phone.trim().isNotEmpty) return phone.trim();
    return '';
  }

  String _roleLabel(String? role) {
    return switch (role) {
      'HOMESCHOOL_ADMIN' => '홈스쿨 관리자',
      'PARENT' => '학부모',
      'TEACHER' => '교사',
      'GUEST_TEACHER' => '게스트 교사',
      'STAFF' => '스태프',
      _ => role ?? '-',
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final theme = Theme.of(context);
    final displayName = _displayName(controller);
    final email = controller.user?.email ?? '-';
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
    final phone = _phoneNumber(controller);
    final isParent = controller.isParentView;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 20),
        // ── Profile Avatar ──
        Center(
          child: Stack(
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor: NestColors.roseMist,
                child: Text(
                  initial,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: NestColors.deepWood,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: NestColors.dustyRose,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            displayName,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Center(
          child: Text(
            _roleLabel(controller.currentRole),
            style: theme.textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // ── Profile Settings Section ──
        Text(
          '프로필 설정',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _SettingsTile(
          icon: Icons.person_outlined,
          label: '닉네임',
          value: displayName,
          onTap: () => _editField(
            title: '닉네임 변경',
            currentValue: displayName,
            hint: '앱에서 표시될 이름',
            onSave: (value) async {
              await controller.updateDisplayName(value);
              if (mounted) _showMessage('닉네임이 변경되었습니다.');
            },
          ),
        ),
        _SettingsTile(
          icon: Icons.email_outlined,
          label: '이메일',
          value: email,
          onTap: null,
        ),
        _SettingsTile(
          icon: Icons.phone_outlined,
          label: '연락처',
          value: phone.isEmpty ? '미설정' : phone,
          valueColor: phone.isEmpty
              ? NestColors.deepWood.withValues(alpha: 0.4)
              : null,
          onTap: () => _editField(
            title: '연락처 변경',
            currentValue: phone,
            hint: '010-0000-0000',
            keyboardType: TextInputType.phone,
            onSave: (value) async {
              await controller.updatePhoneNumber(value);
              if (mounted) _showMessage('연락처가 변경되었습니다.');
            },
          ),
        ),
        _SettingsTile(
          icon: Icons.shield_outlined,
          label: '역할',
          value: _roleLabel(controller.currentRole),
          onTap: null,
        ),

        // ── Parent: 내 불가 시간 section ──
        if (isParent) ...[
          const SizedBox(height: 28),
          _buildUnavailabilitySection(controller),
        ],

        const SizedBox(height: 28),
        Text(
          '앱 정보',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        _SettingsTile(
          icon: Icons.info_outline,
          label: '버전',
          value: 'v${AppConfig.appVersion}',
          onTap: null,
        ),
        _SettingsTile(
          icon: Icons.business_outlined,
          label: '홈스쿨 ID',
          value: controller.selectedHomeschoolId ?? '-',
          onTap: null,
        ),

        // ── PWA Install ──
        if (!_pwaHelper.isRunningAsPwa &&
            (_pwaHelper.isInstallable || _pwaHelper.isIos)) ...[
          const SizedBox(height: 28),
          Text(
            '앱 설치',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: NestColors.roseMist.withValues(alpha: 0.35),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.install_mobile,
                        size: 24, color: NestColors.clay),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '홈 화면에 Nest 추가',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _pwaHelper.isIos && !_pwaHelper.isInstallable
                      ? '하단 공유 버튼(□↑)을 누른 뒤 "홈 화면에 추가"를 선택하세요.'
                      : '앱처럼 빠르게 접근할 수 있습니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.7),
                  ),
                ),
                if (_pwaHelper.isInstallable) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final installed = await _pwaHelper.promptInstall();
                        if (installed && mounted) setState(() {});
                      },
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('설치하기'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],

        if (controller.memberships.isNotEmpty) ...[
          const SizedBox(height: 28),
          Text(
            '홈스쿨 관리',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade200),
              ),
              onPressed: controller.isBusy ? null : _confirmLeaveHomeschool,
              icon: const Icon(Icons.exit_to_app),
              label: Text(
                '${controller.memberships.firstWhere(
                      (m) => m.homeschoolId == controller.selectedHomeschoolId,
                      orElse: () => controller.memberships.first,
                    ).homeschool.name} 탈퇴',
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Unavailability management for parents ──

  Widget _buildUnavailabilitySection(NestController controller) {
    final currentUserId = controller.user?.id;
    if (currentUserId == null) return const SizedBox.shrink();

    final blocks = controller.memberUnavailabilityBlocks
        .where(
          (row) =>
              row.ownerKind == 'MEMBER_USER' && row.ownerId == currentUserId,
        )
        .toList()
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) return day;
        return a.startTime.compareTo(b.startTime);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '수업 불가 시간 설정',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '등록한 시간은 시간표 생성 시 자동으로 회피됩니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: controller.isBusy
                  ? null
                  : () => _openAddUnavailabilityModal(currentUserId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('추가'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (blocks.isEmpty)
          const NestEmptyState(
            icon: Icons.calendar_today,
            title: '등록된 불가 시간이 없습니다',
          )
        else
          ...blocks.map((block) {
            final day = _dayLabel(block.dayOfWeek);
            final start = _shortTime(block.startTime);
            final end = _shortTime(block.endTime);
            final note = block.note.trim();

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: NestColors.roseMist),
                ),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.schedule),
                  title: Text('$day · $start - $end'),
                  subtitle: note.isEmpty ? null : Text(note),
                  trailing: IconButton(
                    onPressed: controller.isBusy
                        ? null
                        : () => _deleteBlock(block.id),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  void _openAddUnavailabilityModal(String userId) {
    final controller = widget.controller;
    // Reset fields for fresh input
    _selectedUnavailabilityDay = 1;
    _unavailabilityStartController.text = '09:00';
    _unavailabilityEndController.text = '10:00';
    _unavailabilityNoteController.clear();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '불가 시간 추가',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: _selectedUnavailabilityDay,
                    decoration: const InputDecoration(
                      labelText: '요일',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('일')),
                      DropdownMenuItem(value: 1, child: Text('월')),
                      DropdownMenuItem(value: 2, child: Text('화')),
                      DropdownMenuItem(value: 3, child: Text('수')),
                      DropdownMenuItem(value: 4, child: Text('목')),
                      DropdownMenuItem(value: 5, child: Text('금')),
                      DropdownMenuItem(value: 6, child: Text('토')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      _selectedUnavailabilityDay = value;
                      setSheetState(() {});
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _unavailabilityStartController,
                          decoration: const InputDecoration(
                            labelText: '시작 (HH:MM)',
                            prefixIcon: Icon(Icons.access_time),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _unavailabilityEndController,
                          decoration: const InputDecoration(
                            labelText: '종료 (HH:MM)',
                            prefixIcon: Icon(Icons.access_time),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _unavailabilityNoteController,
                    decoration: const InputDecoration(
                      labelText: '메모 (선택)',
                      prefixIcon: Icon(Icons.edit_note),
                      isDense: true,
                    ),
                    minLines: 1,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: controller.isBusy
                          ? null
                          : () async {
                              await _createBlock(userId);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                      icon: const Icon(Icons.add),
                      label: const Text('추가'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _createBlock(String userId) async {
    try {
      await widget.controller.createMemberUnavailabilityBlock(
        ownerKind: 'MEMBER_USER',
        ownerId: userId,
        dayOfWeek: _selectedUnavailabilityDay,
        startTime: _unavailabilityStartController.text,
        endTime: _unavailabilityEndController.text,
        note: _unavailabilityNoteController.text,
      );
      _unavailabilityNoteController.clear();
      if (mounted) {
        _showMessage(widget.controller.statusMessage);
        setState(() {});
      }
    } catch (_) {
      if (mounted) _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _deleteBlock(String blockId) async {
    try {
      await widget.controller.deleteMemberUnavailabilityBlock(blockId: blockId);
      if (mounted) {
        _showMessage(widget.controller.statusMessage);
        setState(() {});
      }
    } catch (_) {
      if (mounted) _showMessage(widget.controller.statusMessage);
    }
  }

  String _dayLabel(int dayOfWeek) {
    const labels = <int, String>{
      0: '일', 1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토',
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

  Future<void> _editField({
    required String title,
    required String currentValue,
    required String hint,
    required Future<void> Function(String value) onSave,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final textController = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: textController,
          autofocus: true,
          keyboardType: keyboardType,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(textController.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (result == null || result.isEmpty || result == currentValue) return;

    try {
      await onSave(result);
      setState(() {});
    } catch (_) {
      if (mounted) _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _confirmLeaveHomeschool() async {
    final controller = widget.controller;
    final homeschoolName = controller.memberships
        .firstWhere(
          (m) => m.homeschoolId == controller.selectedHomeschoolId,
          orElse: () => controller.memberships.first,
        )
        .homeschool
        .name;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('홈스쿨 탈퇴'),
        content: Text(
          '$homeschoolName에서 탈퇴하시겠습니까?\n\n'
          '탈퇴하면 이 홈스쿨의 모든 데이터에 접근할 수 없게 됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await controller.leaveHomeschool();
      if (mounted) _showMessage('홈스쿨에서 탈퇴했습니다.');
      setState(() {});
    } catch (e) {
      if (mounted) _showMessage(e.toString().replaceFirst('StateError: ', ''));
    }
  }

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: NestColors.roseMist.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: NestColors.deepWood.withValues(alpha: 0.7)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.55),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: valueColor,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: NestColors.deepWood.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}
