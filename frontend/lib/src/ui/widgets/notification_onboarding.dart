import 'package:flutter/material.dart';

import '../../models/nest_models.dart';
import '../nest_theme.dart';
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
