import 'package:flutter/material.dart';

import '../nest_theme.dart';

/// Branded empty state widget with icon, message, and optional CTA.
class NestEmptyState extends StatelessWidget {
  const NestEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 섹션 카드 안에 넣을 때 쓰는 축약형.
  ///
  /// 기본 크기는 탭 전체가 비었을 때(커뮤니티·갤러리 등) 화면 가운데를 채우라고
  /// 잡은 값이라 세로 200pt 가 넘는다. 그대로 카드 안에 넣으면 한 줄짜리 안내에
  /// 휴대폰 화면의 3분의 1을 쓰게 된다.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconBox = compact ? 44.0 : 72.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 20 : 32,
          vertical: compact ? 18 : 40,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: iconBox,
              height: iconBox,
              decoration: BoxDecoration(
                color: NestColors.roseMist.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(compact ? 14 : 20),
              ),
              child: Icon(
                icon,
                size: compact ? 22 : 36,
                color: NestColors.deepWood.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: compact ? 10 : 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  (compact
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.titleMedium)
                      ?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.85),
                      ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.6),
                ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state widget with retry action.
class NestErrorState extends StatelessWidget {
  const NestErrorState({
    super.key,
    this.message = '데이터를 불러오는 중 문제가 발생했습니다',
    this.detail,
    this.onRetry,
  });

  final String message;
  final String? detail;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFCE8E4),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.cloud_off_outlined,
                size: 32,
                color: NestColors.deepWood.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.85),
              ),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.55),
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('다시 시도'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
