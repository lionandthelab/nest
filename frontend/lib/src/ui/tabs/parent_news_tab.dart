import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/entity_visuals.dart';
import '../widgets/nest_empty_state.dart';
import '../widgets/nest_refresh.dart';
import '../widgets/nest_skeleton.dart';
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
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 760;
                  final chips = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _sectionChip(
                        id: 'announcements',
                        label: '공지사항',
                        icon: Icons.campaign_outlined,
                      ),
                      _sectionChip(
                        id: 'community',
                        label: 'SNS',
                        icon: Icons.forum_outlined,
                      ),
                    ],
                  );

                  if (compact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(theme),
                        const SizedBox(height: 8),
                        chips,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: _buildHeader(theme)),
                      const SizedBox(width: 10),
                      Flexible(child: chips),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
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

  Widget _buildHeader(ThemeData theme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EntityAvatar(
              label: '소식',
              icon: Icons.notifications_active_outlined,
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('소식', style: theme.textTheme.titleLarge),
                  Text(
                    '공지와 SNS를 먼저 보고, 갤러리는 별도 화면으로 열어 확인합니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        FilledButton.tonalIcon(
          onPressed: _openGalleryPage,
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('갤러리 열기'),
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
      'community' => CommunityFeedTab(
        controller: widget.controller,
        showHeroHeader: false,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  Future<void> _openGalleryPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GalleryPage(controller: widget.controller),
      ),
    );
  }

  Widget _buildAnnouncementsSection() {
    final announcements =
        widget.controller.announcements.toList(growable: false)..sort((a, b) {
          // Pinned first, then by date desc
          if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
          final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return right.compareTo(left);
        });

    if (announcements.isEmpty) {
      if (widget.controller.isBusy) {
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: const [
            NestSkeletonCard(),
            SizedBox(height: 8),
            NestSkeletonCard(),
            SizedBox(height: 8),
            NestSkeletonCard(),
          ],
        );
      }
      return const NestEmptyState(
        icon: Icons.campaign_outlined,
        title: '등록된 공지사항이 없습니다',
        subtitle: '새로운 공지사항이 등록되면 여기서 확인할 수 있습니다.',
      );
    }

    return NestRefreshable(
      onRefresh: () => widget.controller.refreshAll(),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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
                    EntityAvatar(
                      label: classGroupName,
                      icon: a.pinned
                          ? Icons.push_pin_outlined
                          : Icons.campaign_outlined,
                      size: 34,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        a.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (a.pinned)
                      Icon(
                        Icons.push_pin,
                        size: 16,
                        color: NestColors.dustyRose,
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
      ),
    );
  }
}
