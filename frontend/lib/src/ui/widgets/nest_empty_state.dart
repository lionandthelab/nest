import 'package:flutter/material.dart';

import '../nest_theme.dart';
import 'nest_3d_icon.dart';
import 'nest_motion.dart';

/// Branded empty state widget with icon, message, and optional CTA.
///
/// 3D 클레이모픽 일러스트([illustration3d] 또는 [NestEmptyState.with3d])를 지원하여
/// 화면이 비어 있을 때도 감각적인 3D 비주얼을 제공합니다.
class NestEmptyState extends StatelessWidget {
  const NestEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.compact = false,
    this.illustration3d,
  });

  /// 3D 클레이모픽 일러스트를 메인으로 사용하는 빈 상태.
  const NestEmptyState.with3d({
    super.key,
    required Widget illustration,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  })  : icon = Icons.info_outline,
        illustration3d = illustration;

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// 섹션 카드 안에 넣을 때 쓰는 축약형.
  final bool compact;

  /// 선택적 3D 일러스트 위젯 ([Nest3dIcon] 등).
  final Widget? illustration3d;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconBox = compact ? 44.0 : 72.0;

    final Widget visual;
    if (illustration3d != null) {
      visual = Floating3DWidget(
        floatDistance: compact ? 3.0 : 6.0,
        child: illustration3d!,
      );
    } else {
      visual = Container(
        width: iconBox,
        height: iconBox,
        decoration: BoxDecoration(
          color: NestColors.roseMist.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(compact ? 14 : 20),
          boxShadow: [
            BoxShadow(
              color: NestColors.dustyRose.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: compact ? 22 : 36,
          color: NestColors.deepWood.withValues(alpha: 0.6),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 20 : 32,
          vertical: compact ? 18 : 36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            visual,
            SizedBox(height: compact ? 10 : 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style:
                  (compact
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.titleMedium)
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: NestColors.deepWood.withValues(alpha: 0.88),
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
              const SizedBox(height: 18),
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
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: NestColors.dustyRose.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
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
                fontWeight: FontWeight.bold,
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
