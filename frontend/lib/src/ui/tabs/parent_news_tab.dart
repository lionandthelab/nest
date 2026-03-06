import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import 'community_feed_tab.dart';
import 'gallery_tab.dart';

class ParentNewsTab extends StatefulWidget {
  const ParentNewsTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<ParentNewsTab> createState() => _ParentNewsTabState();
}

class _ParentNewsTabState extends State<ParentNewsTab> {
  String _sectionId = 'announcements';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Section chips
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Row(
            children: [
              Text('소식', style: theme.textTheme.titleLarge),
              const Spacer(),
              Wrap(
                spacing: 8,
                children: [
                  _sectionChip(
                    id: 'announcements',
                    label: '공지사항',
                    icon: Icons.campaign_outlined,
                  ),
                  _sectionChip(
                    id: 'community',
                    label: '커뮤니티',
                    icon: Icons.forum_outlined,
                  ),
                  _sectionChip(
                    id: 'gallery',
                    label: '갤러리',
                    icon: Icons.photo_library_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Content
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(
              key: ValueKey(_sectionId),
              child: _buildSection(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionChip({
    required String id,
    required String label,
    required IconData icon,
  }) {
    final selected = _sectionId == id;
    return ChoiceChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _sectionId = id),
    );
  }

  Widget _buildSection() {
    return switch (_sectionId) {
      'announcements' => _buildAnnouncementsSection(),
      'community' => CommunityFeedTab(controller: widget.controller),
      'gallery' => GalleryTab(controller: widget.controller),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildAnnouncementsSection() {
    final announcements = widget.controller.announcements
        .toList(growable: false)
      ..sort((a, b) {
        // Pinned first, then by date desc
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

    if (announcements.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.campaign_outlined,
                size: 48,
                color: NestColors.deepWood.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                '등록된 공지사항이 없습니다.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: NestColors.deepWood.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: announcements.length,
      itemBuilder: (context, index) {
        final a = announcements[index];
        final when = a.createdAt == null
            ? '-'
            : DateFormat('yyyy-MM-dd HH:mm').format(a.createdAt!);
        final classGroupName = a.classGroupId == null
            ? '전체 공지'
            : widget.controller.findClassGroupName(a.classGroupId!);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (a.pinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.push_pin,
                          size: 16,
                          color: NestColors.dustyRose,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        a.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    Text(
                      classGroupName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      when,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: NestColors.deepWood.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                if (a.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(a.body),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
