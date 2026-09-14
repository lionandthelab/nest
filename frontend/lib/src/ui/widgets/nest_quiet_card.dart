import 'package:flutter/material.dart';

import '../nest_theme.dart';

/// 내용이 없을 때 자리를 지키는 조용한 카드.
///
/// 홈·시간표 화면은 블록이 전부 카드로 쌓여 있는데, 빈 상태만 맨 텍스트로 두면
/// 그 블록만 배경에 떠 보인다. 채워졌을 때와 같은 카드 모양을 유지해 화면의
/// 세로 리듬이 끊기지 않게 한다.
///
/// 폭을 강제하는 이유: [Card] 는 자식 크기에 맞춰 줄어들어서, 글자가 짧으면
/// 옆 카드들보다 좁게 그려진다.
class NestQuietCard extends StatelessWidget {
  const NestQuietCard(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }
}
