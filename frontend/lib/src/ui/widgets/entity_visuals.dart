import 'package:flutter/material.dart';

import '../nest_theme.dart';

class EntityAvatar extends StatelessWidget {
  const EntityAvatar({
    super.key,
    required this.label,
    this.icon = Icons.person_outline,
    this.size = 38,
    this.imageUrl,
  });

  final String label;
  final IconData icon;
  final double size;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromLabel(label);
    final seeded = _seededColors(label);
    final url = imageUrl?.trim() ?? '';
    final hasImage =
        url.isNotEmpty &&
        (url.startsWith('http://') || url.startsWith('https://'));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: seeded),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.94),
          width: 1.2,
        ),
      ),
      child: hasImage
          ? ClipOval(
              child: Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: (size * 2).toInt(),
                cacheHeight: (size * 2).toInt(),
                errorBuilder: (_, _, _) => _fallbackContent(initials),
              ),
            )
          : _fallbackContent(initials),
    );
  }

  Widget _fallbackContent(String initials) {
    final showInitials = initials.isNotEmpty;
    return Center(
      child: showInitials
          ? Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.34,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1,
              ),
            )
          : Icon(icon, size: size * 0.5, color: Colors.white),
    );
  }
}

class LabeledEntityTile extends StatelessWidget {
  const LabeledEntityTile({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.icon = Icons.label_outline,
    this.imageUrl,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final IconData icon;
  final String? imageUrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: NestColors.deepWood.withValues(alpha: 0.72),
            ),
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Row(
        children: [
          EntityAvatar(
            label: title,
            icon: icon,
            imageUrl: imageUrl,
            size: compact ? 30 : 36,
          ),
          const SizedBox(width: 10),
          Expanded(child: content),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

String _initialsFromLabel(String label) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  final words = trimmed
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (words.length == 1) {
    final value = words.first;
    return value.length <= 2
        ? value.toUpperCase()
        : value.substring(0, 2).toUpperCase();
  }
  final first = words.first.substring(0, 1);
  final second = words.last.substring(0, 1);
  return '$first$second'.toUpperCase();
}

List<Color> _seededColors(String seed) {
  const palettes = <List<Color>>[
    [Color(0xFFDCAE96), Color(0xFFB48268)],
    [Color(0xFF8A9A84), Color(0xFF6C7F67)],
    [Color(0xFFC69A82), Color(0xFFA4765F)],
    [Color(0xFF8D7C6D), Color(0xFF675748)],
    [Color(0xFFBFA089), Color(0xFF9C7E68)],
  ];
  if (seed.trim().isEmpty) {
    return palettes.first;
  }
  final hash = seed.codeUnits.fold<int>(0, (acc, value) => acc + value);
  return palettes[hash % palettes.length];
}
