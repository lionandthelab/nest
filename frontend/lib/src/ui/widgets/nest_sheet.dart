import 'package:flutter/material.dart';

import '../nest_theme.dart';
import 'nest_motion.dart';

/// 이 너비 미만에서는 모달을 화면 아래에서 전체 너비로 올라오는 바텀시트로 띄운다.
/// 태블릿/데스크톱은 가운데 정렬 다이얼로그를 유지한다.
const double kNestCompactWidth = 720;

/// 시트 표면(둥근 흰 배경 컨테이너)에 붙는 키. 테스트에서 실제 크기를 잰다.
const Key nestSheetSurfaceKey = ValueKey('nest-sheet-surface');

/// 현재 화면이 모바일 폭인지 여부.
bool nestIsCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < kNestCompactWidth;

/// 모바일에서는 전체 너비 바텀시트, 넓은 화면에서는 다이얼로그로 같은 내용을 띄운다.
///
/// [builder]는 보통 [NestSheet]를 돌려준다. 내부 상태가 필요한 화면은
/// `StatefulBuilder`로 감싸면 기존 `showDialog` 코드와 동일하게 쓸 수 있다.
Future<T?> showNestSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double maxWidth = 640,
  bool isDismissible = true,
  bool useRootNavigator = true,
}) {
  NestHaptics.light();
  if (!nestIsCompact(context)) {
    return showDialog<T>(
      context: context,
      barrierDismissible: isDismissible,
      useRootNavigator: useRootNavigator,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 32,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: size.height * 0.9,
            ),
            child: _NestSheetSurface(
              isCompact: false,
              child: builder(dialogContext),
            ),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    showDragHandle: false,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: NestColors.deepWood.withValues(alpha: 0.42),
    // 기본 M3 바텀시트는 640px로 폭이 묶인다. 모바일에서는 전체 너비를 쓴다.
    constraints: const BoxConstraints(),
    useRootNavigator: useRootNavigator,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      return AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.94),
          child: _NestSheetSurface(
            isCompact: true,
            child: builder(sheetContext),
          ),
        ),
      );
    },
  );
}

/// 예/아니오 확인 모달. 닫히거나 취소하면 false.
Future<bool> showNestConfirm({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = '확인',
  String cancelLabel = '취소',
  bool destructive = false,
  IconData? icon,
}) async {
  final result = await showNestSheet<bool>(
    context: context,
    maxWidth: 460,
    builder: (sheetContext) => NestSheet(
      title: title,
      icon:
          icon ??
          (destructive ? Icons.warning_amber_rounded : Icons.help_outline),
      iconColor: destructive ? const Color(0xFFB3261E) : NestColors.clay,
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(sheetContext).pop(false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB3261E),
                  foregroundColor: Colors.white,
                )
              : null,
          onPressed: () => Navigator.of(sheetContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
      child: Text(
        message,
        style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
          height: 1.5,
          color: NestColors.deepWood.withValues(alpha: 0.86),
        ),
      ),
    ),
  );
  return result ?? false;
}

/// 단순 안내 모달.
Future<void> showNestInfo({
  required BuildContext context,
  required String title,
  required String message,
  String closeLabel = '닫기',
  IconData? icon,
}) {
  return showNestSheet<void>(
    context: context,
    maxWidth: 520,
    builder: (sheetContext) => NestSheet(
      title: title,
      icon: icon,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(sheetContext).pop(),
          child: Text(closeLabel),
        ),
      ],
      child: SelectionArea(
        child: Text(
          message,
          style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
            height: 1.5,
            color: NestColors.deepWood.withValues(alpha: 0.86),
          ),
        ),
      ),
    ),
  );
}

/// 시트/다이얼로그 공통 내부 레이아웃.
///
/// 머리글(제목·부제·닫기) + 스크롤 본문 + 항상 보이는 액션 바 구조라서,
/// 본문이 길어져도 저장 버튼이 화면 밖으로 밀려나지 않는다.
class NestSheet extends StatelessWidget {
  const NestSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.iconColor,
    this.actions = const <Widget>[],
    this.destructiveAction,
    this.headerTrailing,
    this.isBusy = false,
    this.showCloseButton = true,
    this.scrollable = true,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;

  /// 주 액션(보통 [취소, 저장]). 모바일에서는 가로 폭을 균등 분할한다.
  final List<Widget> actions;

  /// 삭제처럼 위험한 액션. 모바일에서는 주 액션 아래 전체 너비로,
  /// 넓은 화면에서는 액션 바 왼쪽에 배치한다.
  final Widget? destructiveAction;

  /// 머리글 오른쪽(닫기 버튼 옆)에 놓을 부가 위젯.
  final Widget? headerTrailing;

  final bool isBusy;
  final bool showCloseButton;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final compact = nestIsCompact(context);
    final theme = Theme.of(context);
    final horizontal = compact ? 18.0 : 26.0;
    final bottomInset = compact ? MediaQuery.paddingOf(context).bottom : 0.0;

    final body = Padding(
      padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 18),
      child: child,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 2),
            child: Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: NestColors.deepWood.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            compact ? 8 : 22,
            compact ? 8 : 16,
            10,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (iconColor ?? NestColors.clay).withValues(
                      alpha: 0.14,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor ?? NestColors.clay,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 제목은 말줄임 대신 줄바꿈한다. 모바일에서 제목이
                    // "가정 수…"처럼 잘리던 문제를 없앤다.
                    Text(
                      title,
                      softWrap: true,
                      maxLines: 3,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: compact ? 18 : 19,
                        height: 1.25,
                        color: NestColors.deepWood,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        softWrap: true,
                        maxLines: 4,
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.4,
                          color: NestColors.deepWood.withValues(alpha: 0.66),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ?headerTrailing,
              if (showCloseButton)
                IconButton(
                  tooltip: '닫기',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: NestColors.deepWood.withValues(alpha: 0.6),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
            ],
          ),
        ),
        if (isBusy) const LinearProgressIndicator(minHeight: 2),
        Divider(
          height: 1,
          thickness: 1,
          color: NestColors.roseMist.withValues(alpha: 0.85),
        ),
        Flexible(
          child: scrollable
              ? SingleChildScrollView(primary: false, child: body)
              : body,
        ),
        if (actions.isNotEmpty || destructiveAction != null)
          _NestSheetActionBar(
            compact: compact,
            horizontal: horizontal,
            bottomInset: bottomInset,
            actions: actions,
            destructiveAction: destructiveAction,
          ),
      ],
    );
  }
}

class _NestSheetActionBar extends StatelessWidget {
  const _NestSheetActionBar({
    required this.compact,
    required this.horizontal,
    required this.bottomInset,
    required this.actions,
    required this.destructiveAction,
  });

  final bool compact;
  final double horizontal;
  final double bottomInset;
  final List<Widget> actions;
  final Widget? destructiveAction;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (compact) {
      final rows = <Widget>[];
      if (actions.length == 1) {
        rows.add(SizedBox(width: double.infinity, child: actions.single));
      } else if (actions.length == 2) {
        rows.add(
          Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: actions[i]),
              ],
            ],
          ),
        );
      } else if (actions.length > 2) {
        // 3개 이상은 가로로 나누면 글자가 죄다 말줄임된다.
        // 주 액션(마지막)이 위로 오도록 뒤집어 세로로 쌓는다.
        for (var i = actions.length - 1; i >= 0; i--) {
          if (i < actions.length - 1) rows.add(const SizedBox(height: 8));
          rows.add(SizedBox(width: double.infinity, child: actions[i]));
        }
      }
      if (destructiveAction != null) {
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
        rows.add(SizedBox(width: double.infinity, child: destructiveAction!));
      }
      content = Column(mainAxisSize: MainAxisSize.min, children: rows);
    } else {
      content = Row(
        children: [
          ?destructiveAction,
          const Spacer(),
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            actions[i],
          ],
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: NestColors.creamyWhite.withValues(alpha: 0.7),
        border: Border(
          top: BorderSide(color: NestColors.roseMist.withValues(alpha: 0.85)),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        horizontal,
        12,
        horizontal,
        12 + bottomInset,
      ),
      child: content,
    );
  }
}

class _NestSheetSurface extends StatelessWidget {
  const _NestSheetSurface({required this.isCompact, required this.child});

  final bool isCompact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: nestSheetSurfaceKey,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isCompact
            ? const BorderRadius.vertical(top: Radius.circular(26))
            : BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: NestColors.deepWood.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}
