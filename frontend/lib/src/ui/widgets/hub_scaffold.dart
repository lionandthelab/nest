import 'package:flutter/material.dart';

import '../nest_theme.dart';
import 'nest_motion.dart';

class HubMetric {
  const HubMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

class HubSection {
  const HubSection({
    required this.id,
    required this.label,
    required this.icon,
    required this.content,
  });

  final String id;
  final String label;
  final IconData icon;
  final Widget content;
}

class HubScaffold extends StatelessWidget {
  const HubScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.metrics,
    required this.sections,
    required this.selectedSectionId,
    required this.onSelectSection,
    this.isBusy = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<HubMetric> metrics;
  final List<HubSection> sections;
  final String selectedSectionId;
  final ValueChanged<String> onSelectSection;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final selected = sections.firstWhere(
      (section) => section.id == selectedSectionId,
      orElse: () => sections.first,
    );

    return ListView(
      children: [
        _HubHeader(
          title: title,
          subtitle: subtitle,
          icon: icon,
          metrics: metrics,
          isBusy: isBusy,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sections
                  .map(
                    (section) => ChoiceChip(
                      selected: section.id == selected.id,
                      label: Text(section.label),
                      avatar: Icon(section.icon, size: 17),
                      onSelected: (_) => onSelectSection(section.id),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) =>
              nestFadeSlideTransition(child, animation),
          child: KeyedSubtree(
            key: ValueKey(selected.id),
            child: selected.content,
          ),
        ),
      ],
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.metrics,
    required this.isBusy,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<HubMetric> metrics;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: NestColors.roseMist,
                  ),
                  child: Icon(icon, color: NestColors.deepWood),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isBusy) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(minHeight: 3),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: metrics
                  .map(
                    (metric) => _HubMetricTile(
                      label: metric.label,
                      value: metric.value,
                      icon: metric.icon,
                    ),
                  )
                  .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubMetricTile extends StatelessWidget {
  const _HubMetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 152),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: NestColors.deepWood),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.68),
                ),
              ),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ],
      ),
    );
  }
}
