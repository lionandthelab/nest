import 'package:flutter/material.dart';

import '../nest_theme.dart';

/// "제목 + 개수 배지 + 액션 버튼" 형태의 섹션 머리글.
///
/// 좁은 폭에서 제목과 버튼을 억지로 `Expanded` 한 줄에 구겨 넣으면 버튼 안의
/// 글자가 2~3줄로 깨지므로, 모바일 폭에서는 버튼 패딩/글씨 크기를 줄여 한 줄
/// 캡슐 버튼으로 유지하고, 액션이 1개면 제목 줄 오른쪽에 바로 배치해 세로
/// 공간을 아낀다.
class NestSectionHeader extends StatelessWidget {
  const NestSectionHeader({
    super.key,
    required this.title,
    this.badge,
    this.description,
    this.actions = const <Widget>[],
  });

  /// 이 폭 아래에서는 모바일 컴팩트 헤더 레이아웃을 사용한다.
  static const double stackBelow = 560;

  final String title;
  final Widget? badge;
  final String? description;
  final List<Widget> actions;

  static final ButtonStyle _compactButtonStyle = ButtonStyle(
    visualDensity: VisualDensity.compact,
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),
    minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
    iconSize: const WidgetStatePropertyAll(15),
    textStyle: const WidgetStatePropertyAll(
      TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.1),
    ),
  );

  Widget _withCompactButtons(BuildContext context, Widget child) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: _compactButtonStyle.merge(theme.elevatedButtonTheme.style),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: _compactButtonStyle.merge(theme.filledButtonTheme.style),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: _compactButtonStyle.merge(theme.outlinedButtonTheme.style),
        ),
        textButtonTheme: TextButtonThemeData(
          style: _compactButtonStyle.merge(theme.textButtonTheme.style),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < stackBelow;

        Widget titleLine() => Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: stacked
                  ? theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    )
                  : theme.textTheme.titleLarge,
            ),
            ?badge,
          ],
        );

        Widget descriptionLine() => Padding(
          padding: EdgeInsets.only(top: stacked ? 3 : 6),
          child: Text(
            description!,
            maxLines: stacked ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: (stacked
                    ? theme.textTheme.bodySmall?.copyWith(fontSize: 12)
                    : theme.textTheme.bodyMedium)
                ?.copyWith(color: NestColors.deepWood.withValues(alpha: 0.72)),
          ),
        );

        if (!stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: titleLine()),
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    actions[i],
                  ],
                ],
              ),
              if (description != null && description!.isNotEmpty)
                descriptionLine(),
            ],
          );
        }

        // 모바일 폭에서 액션이 1개뿐이면 제목 오른쪽에 바로 배치해 줄바꿈을 줄인다.
        if (actions.length == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: titleLine()),
                  const SizedBox(width: 8),
                  _withCompactButtons(context, actions.first),
                ],
              ),
              if (description != null && description!.isNotEmpty)
                descriptionLine(),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleLine(),
            if (description != null && description!.isNotEmpty)
              descriptionLine(),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _withCompactButtons(
                context,
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: actions,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
