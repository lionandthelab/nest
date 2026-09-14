import 'package:flutter/material.dart';

import '../nest_theme.dart';

/// "제목 + 개수 배지 + 액션 버튼" 형태의 섹션 머리글.
///
/// 좁은 폭에서 제목과 버튼을 한 줄에 몰아넣으면 글자가 잘리거나 가로로
/// 넘치므로, 폭이 모자라면 제목 줄과 버튼 줄을 분리하고 버튼은 남은 폭을
/// 균등하게 나눠 쓴다.
class NestSectionHeader extends StatelessWidget {
  const NestSectionHeader({
    super.key,
    required this.title,
    this.badge,
    this.description,
    this.actions = const <Widget>[],
  });

  /// 이 폭 아래에서는 제목과 액션을 위아래로 나눈다.
  static const double stackBelow = 560;

  final String title;
  final Widget? badge;
  final String? description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget titleLine() => Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        ?badge,
      ],
    );

    Widget descriptionLine() => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        description!,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: NestColors.deepWood.withValues(alpha: 0.72),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < stackBelow;
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

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleLine(),
            if (description != null && description!.isNotEmpty)
              descriptionLine(),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: actions[i]),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
