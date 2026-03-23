import 'package:flutter/material.dart';

import '../nest_theme.dart';

class SelectSheetOption<T> {
  const SelectSheetOption({
    required this.value,
    required this.title,
    this.subtitle = '',
    this.keywords = '',
  });

  final T value;
  final String title;
  final String subtitle;
  final String keywords;
}

Future<T?> showSelectSheet<T>({
  required BuildContext context,
  required String title,
  required String helpText,
  required List<SelectSheetOption<T>> options,
  required T? currentValue,
}) async {
  if (options.isEmpty) {
    return null;
  }

  var query = '';
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          final normalizedQuery = query.trim().toLowerCase();
          final filtered = normalizedQuery.isEmpty
              ? options
              : options
                    .where((option) {
                      final haystack = [
                        option.title,
                        option.subtitle,
                        option.keywords,
                      ].join(' ').toLowerCase();
                      return haystack.contains(normalizedQuery);
                    })
                    .toList();

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  helpText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  onChanged: (value) => setSheetState(() => query = value),
                  decoration: const InputDecoration(
                    labelText: '검색',
                    hintText: '이름/메모로 찾기',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: filtered.isEmpty
                      ? const Center(child: Text('검색 결과가 없습니다.'))
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final option = filtered[index];
                            final selected = option.value == currentValue;
                            return ListTile(
                              dense: true,
                              leading: selected
                                  ? const Icon(Icons.check_circle)
                                  : const Icon(Icons.circle_outlined),
                              title: Text(option.title),
                              subtitle: option.subtitle.isEmpty
                                  ? null
                                  : Text(option.subtitle),
                              onTap: () =>
                                  Navigator.of(context).pop(option.value),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

class SelectFieldCard extends StatelessWidget {
  const SelectFieldCard({
    super.key,
    required this.label,
    required this.hintText,
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.value,
    this.helpText,
    this.trailing,
  });

  final String label;
  final String hintText;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final String? value;
  final String? helpText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final valueText = value?.trim();
    final hasValue = valueText != null && valueText.isNotEmpty;

    return Opacity(
      opacity: enabled ? 1 : 0.62,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: enabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: NestColors.roseMist),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: NestColors.deepWood),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      hasValue ? valueText : hintText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: hasValue
                          ? textTheme.bodyMedium
                          : textTheme.bodyMedium?.copyWith(
                              color: NestColors.deepWood.withValues(alpha: 0.5),
                            ),
                    ),
                    if (helpText != null && helpText!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        helpText!,
                        style: textTheme.bodySmall?.copyWith(
                          color: NestColors.deepWood.withValues(alpha: 0.62),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ?? const SizedBox.shrink(),
              const SizedBox(width: 4),
              const Icon(Icons.unfold_more, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
