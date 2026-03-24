import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/nest_models.dart';
import '../../state/nest_controller.dart';
import '../models/child_class_bundle.dart';
import '../nest_theme.dart';
import '../widgets/nest_empty_state.dart';

class ParentHomeTab extends StatefulWidget {
  const ParentHomeTab({
    super.key,
    required this.controller,
    required this.selectedChildId,
    required this.childClassBundles,
    required this.isLoadingChildClasses,
  });

  final NestController controller;
  final String? selectedChildId;
  final Map<String, ChildClassBundle> childClassBundles;
  final bool isLoadingChildClasses;

  @override
  State<ParentHomeTab> createState() => _ParentHomeTabState();
}

class _ParentHomeTabState extends State<ParentHomeTab> {
  bool _showAllAnnouncements = false;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final bundles = widget.childClassBundles;
    final hasChild = widget.selectedChildId != null;
    final noEnrollments =
        hasChild && bundles.isEmpty && !widget.isLoadingChildClasses;

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (noEnrollments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              color: NestColors.roseMist.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: NestColors.clay),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '반 배정 대기 중',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '아이가 아직 반에 배정되지 않았습니다. '
                            '관리자가 반 배정을 완료하면 시간표와 학습 현황을 확인할 수 있습니다.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // ── Announcement banner ──
        _buildAnnouncementBanner(controller),

        const SizedBox(height: 16),

        // ── Homeschool full schedule ──
        _buildHomeschoolSchedule(controller),
      ],
    );
  }

  // ── Announcement banner: latest one + 더 보기 ──

  Widget _buildAnnouncementBanner(NestController controller) {
    final announcements = controller.announcements.toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final left = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final right = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

    if (announcements.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_showAllAnnouncements) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined,
                  size: 20, color: NestColors.deepWood.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text('공지사항',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() => _showAllAnnouncements = false),
                child: const Text('접기'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...announcements.map((a) => _buildAnnouncementCard(a, controller)),
        ],
      );
    }

    // Show only the latest announcement as a banner
    final latest = announcements.first;
    final when = latest.createdAt == null
        ? ''
        : DateFormat('MM/dd').format(latest.createdAt!);
    final classGroupName = latest.classGroupId == null
        ? '전체'
        : controller.findClassGroupName(latest.classGroupId!);

    return Card(
      color: NestColors.roseMist.withValues(alpha: 0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _showAllAnnouncements = true),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.campaign, size: 20, color: NestColors.dustyRose),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (latest.body.trim().isNotEmpty)
                      Text(
                        latest.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  NestColors.deepWood.withValues(alpha: 0.65),
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$classGroupName · $when',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: NestColors.deepWood.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
              ),
              if (announcements.length > 1) ...[
                const SizedBox(width: 4),
                Icon(Icons.expand_more,
                    size: 18,
                    color: NestColors.deepWood.withValues(alpha: 0.5)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(Announcement a, NestController controller) {
    final when = a.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(a.createdAt!);
    final classGroupName = a.classGroupId == null
        ? '전체 공지'
        : controller.findClassGroupName(a.classGroupId!);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (a.pinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(Icons.push_pin,
                        size: 14, color: NestColors.dustyRose),
                  ),
                Expanded(
                  child: Text(
                    a.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              '$classGroupName · $when',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.5),
                  ),
            ),
            if (a.body.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(a.body, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  // ── Academic schedule ──

  Widget _buildHomeschoolSchedule(NestController controller) {
    final currentTerm = controller.terms
        .where((t) => t.id == controller.selectedTermId)
        .firstOrNull;

    final termLabel = currentTerm != null ? currentTerm.name : '학기 정보 없음';
    final termPeriod = currentTerm != null &&
            currentTerm.startDate != null &&
            currentTerm.endDate != null
        ? '${DateFormat('yyyy.MM.dd').format(currentTerm.startDate!)} ~ ${DateFormat('yyyy.MM.dd').format(currentTerm.endDate!)}'
        : '';

    final events = controller.academicEvents.toList()
      ..sort((a, b) => a.eventDate.compareTo(b.eventDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.event_note_outlined,
                size: 20, color: NestColors.deepWood.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text('학사 일정',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
        if (termPeriod.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 26),
            child: Text(
              '$termLabel · $termPeriod',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.55),
                  ),
            ),
          ),
        const SizedBox(height: 10),
        if (events.isEmpty)
          const NestEmptyState(
            icon: Icons.event_note_outlined,
            title: '등록된 학사 일정이 없습니다',
            subtitle: '관리자가 일정을 등록하면 여기서 확인할 수 있습니다.',
          )
        else
          ...events.map((event) {
            final dateLabel = event.endDate != null
                ? '${DateFormat('M/d').format(event.eventDate)} ~ ${DateFormat('M/d').format(event.endDate!)}'
                : DateFormat('M월 d일 (E)', 'ko').format(event.eventDate);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: NestColors.roseMist.withValues(alpha: 0.4),
                      ),
                      child: Center(
                        child: Text(
                          '${event.eventDate.day}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: NestColors.deepWood
                                      .withValues(alpha: 0.55),
                                ),
                          ),
                          if (event.description.trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              event.description,
                              style:
                                  Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
