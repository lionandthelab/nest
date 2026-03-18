import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class ProfileSettingsTab extends StatefulWidget {
  const ProfileSettingsTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<ProfileSettingsTab> createState() => _ProfileSettingsTabState();
}

class _ProfileSettingsTabState extends State<ProfileSettingsTab> {
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
      ],
    );
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
