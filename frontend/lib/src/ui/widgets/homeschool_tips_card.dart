import 'package:flutter/material.dart';

import '../models/homeschool_start_tips.dart';
import '../nest_theme.dart';
import 'nest_3d_icon.dart';
import 'nest_motion.dart';

/// 우리집 홈스쿨을 처음 여는 부모님을 위한 짧은 팁.
///
/// [HomeschoolTipsDensity.onboard]는 시작하기 화면,
/// [HomeschoolTipsDensity.compact]는 학부모/관리자 홈의 오늘의 팁이다.
class HomeschoolTipsCard extends StatefulWidget {
  const HomeschoolTipsCard({
    super.key,
    this.density = HomeschoolTipsDensity.onboard,
    this.now,
  });

  final HomeschoolTipsDensity density;
  final DateTime? now;

  @override
  State<HomeschoolTipsCard> createState() => _HomeschoolTipsCardState();
}

enum HomeschoolTipsDensity { onboard, compact }

class _HomeschoolTipsCardState extends State<HomeschoolTipsCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final featured = HomeschoolStartTips.tipOfTheDay(widget.now);
    final rest = HomeschoolStartTips.moreTips(widget.now);
    final isOnboard = widget.density == HomeschoolTipsDensity.onboard;

    return Card(
      color: isOnboard ? null : NestColors.creamyWhite,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const _TipGlyph(icon: Icons.auto_stories_outlined, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isOnboard ? '우리집 홈스쿨, 이렇게 시작해요' : '오늘의 한 줄',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOnboard
                            ? '완벽한 학교 흉내가 아니라, 우리집 리듬을 만드는 일이에요.'
                            : '오늘 하나만 챙겨도 충분해요.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TipRow(tip: featured, featured: true),
            if (_expanded) ...[
              const SizedBox(height: 8),
              ...rest.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TipRow(tip: tip),
                ),
              ),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: NestPressable(
                child: TextButton.icon(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                  ),
                  label: Text(_expanded ? '접기' : '다른 이야기'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.tip, this.featured = false});

  final HomeschoolTip tip;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBadge = tip.badgeText != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: featured
            ? NestColors.roseMist.withValues(alpha: 0.55)
            : hasBadge
                ? NestColors.creamyWhite
                : Colors.white,
        border: Border.all(
          color: hasBadge
              ? NestColors.dustyRose.withValues(alpha: 0.5)
              : NestColors.roseMist,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TipGlyph(
            icon: tip.icon,
            size: featured ? 40 : 34,
            tipId: tip.id,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tip.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: NestColors.deepWood,
                        ),
                      ),
                    ),
                    if (tip.badgeText != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: NestColors.dustyRose.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: NestColors.dustyRose.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          tip.badgeText!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: NestColors.dustyRose,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tip.body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.82),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TipGlyph extends StatelessWidget {
  const _TipGlyph({required this.icon, this.size = 38, this.tipId});

  final IconData icon;
  final double size;
  final String? tipId;

  @override
  Widget build(BuildContext context) {
    if (tipId == 'portfolio-preview') {
      return Nest3dIcon.achievement(
        size: size,
        floating: true,
      );
    }
    return Nest3dIcon.lightbulb(
      size: size,
      floating: true,
    );
  }
}
