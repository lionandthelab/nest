import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lion_auth/lion_auth.dart' show PushPermissionStatus;

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'nest_3d_icon.dart';
import 'notification_settings_panel.dart';

/// 첫 로그인 뒤 한 번 보여주는 알림 설정 화면.
///
/// 기본값을 켠 채로 시작한다. "이대로 시작하기"만 눌러도 알림을 받게 되고,
/// 시간을 바꾸고 싶은 사람만 칩을 건드리면 된다. 빈 화면에서 스위치를 직접
/// 켜라고 하면 대부분 그냥 지나친다.
class NotificationOnboardingSheet extends StatefulWidget {
  const NotificationOnboardingSheet({
    super.key,
    required this.initial,
    required this.onDone,
  });

  final NotificationPrefs initial;

  /// 완료·건너뛰기 모두 이 콜백으로 끝난다. 표시 시각이 이미 채워져 있다.
  final ValueChanged<NotificationPrefs> onDone;

  @override
  State<NotificationOnboardingSheet> createState() =>
      _NotificationOnboardingSheetState();
}

class _NotificationOnboardingSheetState
    extends State<NotificationOnboardingSheet> {
  late NotificationPrefs _prefs = widget.initial.copyWith(
    // 온보딩은 켜는 쪽을 기본으로 제안한다.
    pushEnabled: true,
    morningDigestEnabled: true,
    classReminderEnabled: true,
  );

  void _finish({required bool accepted}) {
    final now = DateTime.now();
    widget.onDone(
      accepted
          ? _prefs.copyWith(notifOnboardedAt: now)
          : widget.initial.copyWith(
              pushEnabled: false,
              notifOnboardedAt: now,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: NestColors.creamyWhite,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: NestColors.roseMist,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.notifications_active_outlined,
                        size: 28,
                        color: NestColors.deepWood,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      '수업을 놓치지 않게\n알림을 받아보세요',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '시간표가 바뀌거나 수업이 시작하기 전에 미리 알려드립니다. '
                      '언제든 설정에서 바꿀 수 있어요.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.65),
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),
                    NotificationSettingsPanel(
                      prefs: _prefs,
                      onChanged: (value) => setState(() => _prefs = value),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => _finish(accepted: true),
                      child: const Text('이대로 시작하기'),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _finish(accepted: false),
                    child: Text(
                      '나중에 할게요',
                      style: TextStyle(
                        color: NestColors.deepWood.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 알림이 하나도 안 켜져 있을 때 홈 위에 올리는 배너.
class NotificationNudgeBanner extends StatelessWidget {
  const NotificationNudgeBanner({
    super.key,
    required this.onOpen,
    required this.onDismiss,
  });

  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: NestColors.roseMist.withValues(alpha: 0.35),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_off_outlined,
                size: 20,
                color: NestColors.clay,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '알림이 꺼져 있어요',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '수업 변경·시작 전 안내를 받지 못합니다',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close,
                  size: 18,
                  color: NestColors.deepWood.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 첫 설치뿐 아니라 앱 업데이트 후에도 기기 푸시 권한이 허용되지 않았거나
/// 푸시 알림이 꺼져 있을 때 홈에서 띄우는 권한 안내 팝업.
Future<void> showPushPermissionDialog({
  required BuildContext context,
  required NestController controller,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => PushPermissionDialog(controller: controller),
  );
}

class PushPermissionDialog extends StatefulWidget {
  const PushPermissionDialog({super.key, required this.controller});

  final NestController controller;

  @override
  State<PushPermissionDialog> createState() => _PushPermissionDialogState();
}

class _PushPermissionDialogState extends State<PushPermissionDialog> {
  bool _requesting = false;
  late bool _showDeniedGuide =
      widget.controller.pushPermissionStatus == PushPermissionStatus.denied;

  Future<void> _handleEnable() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final result = await widget.controller.enablePushFromPermissionPopup();
    if (!mounted) return;
    if (result == PushPermissionStatus.authorized) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('푸시 알림이 켜졌어요.')),
      );
      return;
    }
    setState(() {
      _requesting = false;
      _showDeniedGuide = true;
    });
  }

  Future<void> _handleOpenSettings() async {
    await widget.controller.openDeviceNotificationSettings();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  void _handleDismiss() {
    widget.controller.dismissPushPermissionPopup();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: NestColors.creamyWhite,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: NestColors.roseMist, width: 1.2),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: NestColors.roseMist.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: const Nest3dIcon.bell(size: 48),
              ),
              const SizedBox(height: 16),
              Text(
                _showDeniedGuide
                    ? '기기에서 알림 권한을 허용해 주세요'
                    : '수업·공지 알림을 놓치지 마세요',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: NestColors.deepWood,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _showDeniedGuide
                    ? (kIsWeb
                          ? '브라우저 주소창 왼쪽 자물쇠(사이트 설정)에서 알림을 [허용]으로 바꾼 뒤 새로고침해 주세요.'
                          : '현재 기기 설정에서 Nest 알림이 꺼져 있어요.\n휴대폰 [설정 > 알림 > Nest]에서 알림을 켜면 바로 받을 수 있습니다.')
                    : '오늘 수업 일정, 수업 시작 30분 전 안내, 공지·학사일정 변경 소식을 휴대폰 푸시로 바로 알려드릴게요.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.72),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              if (!_showDeniedGuide)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: NestColors.roseMist),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _BenefitRow(
                        icon: Icons.wb_sunny_outlined,
                        text: '매일 아침 오늘 시간표 브리핑',
                        theme: theme,
                      ),
                      const SizedBox(height: 6),
                      _BenefitRow(
                        icon: Icons.alarm_outlined,
                        text: '수업 시작 전·시간표 변경 즉시 안내',
                        theme: theme,
                      ),
                      const SizedBox(height: 6),
                      _BenefitRow(
                        icon: Icons.campaign_outlined,
                        text: '새 공지·학사일정·선생님 소식 알림',
                        theme: theme,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              if (_showDeniedGuide) ...[
                if (!kIsWeb) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton.icon(
                      onPressed: _handleOpenSettings,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('기기 알림 설정 열기'),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _handleDismiss,
                    child: const Text('확인'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.icon(
                    onPressed: _requesting ? null : _handleEnable,
                    icon: _requesting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.notifications_active_outlined,
                            size: 18,
                          ),
                    label: Text(_requesting ? '권한 확인 중...' : '푸시 알림 켜기'),
                  ),
                ),
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _requesting ? null : _handleDismiss,
                  child: Text(
                    '나중에',
                    style: TextStyle(
                      color: NestColors.deepWood.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.text,
    required this.theme,
  });

  final IconData icon;
  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: NestColors.clay),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
