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
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<HubMetric> metrics;
  final List<HubSection> sections;
  final String selectedSectionId;
  final ValueChanged<String> onSelectSection;
  final bool isBusy;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final selected = sections.firstWhere(
      (section) => section.id == selectedSectionId,
      orElse: () => sections.first,
    );

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(icon, size: 22, color: NestColors.clay),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: metrics
                              .map(
                                (metric) => Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: Chip(
                                    avatar: Icon(metric.icon, size: 14),
                                    label: Text(
                                      '${metric.label} ${metric.value}',
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                    ...actions,
                  ],
                ),
                if (isBusy)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: sections
                  .map(
                    (section) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: section.id == selected.id,
                        label: Text(section.label),
                        avatar: Icon(section.icon, size: 17),
                        onSelected: (_) => onSelectSection(section.id),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
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
