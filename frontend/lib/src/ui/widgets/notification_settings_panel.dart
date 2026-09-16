import 'package:flutter/material.dart';

import '../../models/nest_models.dart';
import '../nest_theme.dart';

/// 알림 설정 한 덩어리. 설정 화면과 첫 온보딩이 이 위젯을 같이 쓴다.
///
/// 한 곳에 모은 이유: 온보딩에서 켠 것과 설정에서 보이는 것이 다르면 사용자가
/// 자기가 뭘 켰는지 알 수 없다. 문구·선택지·기본값을 한 군데서만 정한다.
///
/// 저장은 하지 않는다. 바뀐 [NotificationPrefs] 를 [onChanged] 로 올려보내고,
/// 실제 저장은 쓰는 쪽(설정 화면은 즉시 저장, 온보딩은 완료 시 저장)이 정한다.
class NotificationSettingsPanel extends StatelessWidget {
  const NotificationSettingsPanel({
    super.key,
    required this.prefs,
    required this.onChanged,
    this.enabled = true,
    this.onSendTest,
  });

  final NotificationPrefs prefs;
  final ValueChanged<NotificationPrefs> onChanged;

  /// 저장 중에는 꺼서 연타를 막는다.
  final bool enabled;

  /// 본인 기기로 확인용 푸시를 보낸다. null 이면 버튼을 숨긴다
  /// (온보딩은 아직 저장 전이라 보낼 수 없다).
  final VoidCallback? onSendTest;

  /// 기본 조용한 시간. 켤 때 이 값으로 시작한다.
  static const String defaultQuietStart = '21:00';
  static const String defaultQuietEnd = '07:00';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 푸시 자체가 꺼져 있으면 아래 항목은 의미가 없다.
    final subEnabled = enabled && prefs.pushEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Tile(
          icon: Icons.notifications_active_outlined,
          title: '푸시 알림',
          subtitle: '수업 변경·결석처럼 놓치면 곤란한 소식을 기기로 받습니다',
          value: prefs.pushEnabled,
          onChanged: enabled
              ? (value) => onChanged(prefs.copyWith(pushEnabled: value))
              : null,
        ),
        if (!prefs.pushEnabled)
          _Notice(
            icon: Icons.notifications_off_outlined,
            text: '푸시가 꺼져 있어 지금은 아무 알림이 오지 않습니다.',
          ),

        const SizedBox(height: 8),
        _Tile(
          icon: Icons.wb_sunny_outlined,
          title: '아침 오늘 일정',
          subtitle: '매일 아침 ${prefs.morningDigestLabel}',
          value: prefs.morningDigestEnabled,
          onChanged: subEnabled
              ? (value) =>
                    onChanged(prefs.copyWith(morningDigestEnabled: value))
              : null,
        ),
        if (prefs.morningDigestEnabled) ...[
          // 어떤 알림이 오는지 보여줘야 켤 이유가 생긴다.
          const _Preview('오늘 수업 3개 · 첫 수업 9:00 국어'),
          const SizedBox(height: 6),
          _ChipRow(
            labels: {
              for (final at in NotificationPrefs.morningMinChoices)
                at: NotificationPrefs(morningDigestMin: at).morningDigestLabel,
            },
            value: prefs.morningDigestMin,
            enabled: subEnabled,
            onSelected: (at) => onChanged(prefs.copyWith(morningDigestMin: at)),
          ),
        ],

        const SizedBox(height: 8),
        _Tile(
          icon: Icons.alarm_outlined,
          title: '수업 전 알림',
          subtitle: '수업이 시작하기 전에 미리',
          value: prefs.classReminderEnabled,
          onChanged: subEnabled
              ? (value) =>
                    onChanged(prefs.copyWith(classReminderEnabled: value))
              : null,
        ),
        if (prefs.classReminderEnabled) ...[
          _Preview('국어 ${prefs.classReminderLeadMin}분 전 · 3층 사랑방'),
          const SizedBox(height: 6),
          _ChipRow(
            labels: {
              for (final lead in NotificationPrefs.leadMinChoices)
                lead: '$lead분',
            },
            value: prefs.classReminderLeadMin,
            enabled: subEnabled,
            onSelected: (lead) =>
                onChanged(prefs.copyWith(classReminderLeadMin: lead)),
          ),
        ],

        const SizedBox(height: 8),
        _Tile(
          icon: Icons.bedtime_outlined,
          title: '조용한 시간',
          subtitle: prefs.hasQuietHours
              ? '${prefs.quietHoursStart} ~ ${prefs.quietHoursEnd} 에는 보내지 않습니다'
              : '밤·새벽에 알림을 멈춥니다',
          value: prefs.hasQuietHours,
          onChanged: subEnabled
              ? (value) => onChanged(
                  value
                      ? prefs.copyWith(
                          quietHoursStart: defaultQuietStart,
                          quietHoursEnd: defaultQuietEnd,
                        )
                      : prefs.clearQuietHours(),
                )
              : null,
        ),

        if (onSendTest != null) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: subEnabled ? onSendTest : null,
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const Text('테스트 알림 보내기'),
            ),
          ),
        ],

        const SizedBox(height: 12),
        Text(
          '알림은 기기 설정에서도 허용되어 있어야 옵니다. '
          '설정을 켰는데도 오지 않으면 휴대폰의 알림 권한을 확인해 주세요.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: NestColors.deepWood.withValues(alpha: 0.5),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// 스위치 한 줄. 탭 영역을 줄 전체로 넓혀 휴대폰에서 누르기 쉽게 한다.
class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dimmed = onChanged == null;
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      secondary: Icon(
        icon,
        size: 22,
        color: NestColors.deepWood.withValues(alpha: dimmed ? 0.3 : 0.7),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: NestColors.deepWood.withValues(alpha: dimmed ? 0.4 : 1),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: NestColors.deepWood.withValues(alpha: dimmed ? 0.3 : 0.55),
        ),
      ),
    );
  }
}

/// 실제로 들어올 알림 문구를 그대로 보여주는 작은 미리보기.
class _Preview extends StatelessWidget {
  const _Preview(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, right: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 13,
            color: NestColors.clay.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: NestColors.clay,
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    const color = NestColors.clay;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

/// 값 하나를 고르는 칩 줄. 아침 시각과 수업 전 분수가 같이 쓴다.
class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.labels,
    required this.value,
    required this.enabled,
    required this.onSelected,
  });

  /// 값 → 화면에 보일 라벨. 순서가 그대로 칩 순서가 된다.
  final Map<int, String> labels;
  final int value;
  final bool enabled;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    // Wrap 으로 두면 칩 폭이 글자에 따라 들쭉날쭉해서, 4개가 가용 폭을 아슬아슬
    // 넘길 때 3+1 로 접힌다(실측 385.2 vs 385.0). 폭을 똑같이 나눠 가지면
    // 폰 크기와 글꼴에 상관없이 한 줄로 유지된다.
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Row(
        children: [
          for (final entry in labels.entries) ...[
            if (entry.key != labels.keys.first) const SizedBox(width: 6),
            Expanded(
              child: ChoiceChip(
                label: SizedBox(
                  width: double.infinity,
                  child: Text(entry.value, textAlign: TextAlign.center),
                ),
                selected: entry.key == value,
                onSelected: enabled ? (_) => onSelected(entry.key) : null,
                // 선택 표시를 체크마크로 하면 그 칩만 넓어진다. 색으로 구분한다.
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                labelPadding: const EdgeInsets.symmetric(horizontal: 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
