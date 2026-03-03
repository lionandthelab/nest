import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class ParentHubTab extends StatefulWidget {
  const ParentHubTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<ParentHubTab> createState() => _ParentHubTabState();
}

class _ParentHubTabState extends State<ParentHubTab> {
  final _unavailabilityStartController = TextEditingController(text: '09:00');
  final _unavailabilityEndController = TextEditingController(text: '10:00');
  final _unavailabilityNoteController = TextEditingController();
  int _selectedUnavailabilityDay = 1;

  @override
  void dispose() {
    _unavailabilityStartController.dispose();
    _unavailabilityEndController.dispose();
    _unavailabilityNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final sessions = controller.sessions.length;
    final gallery = controller.galleryItems.length;
    final announcements = controller.announcements.length;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parent Hub',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '우리 아이 반 운영 상황, 공지, 활동 기록을 한 곳에서 확인합니다.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _MetricCard(label: '이번 반 수업 수', value: '$sessions'),
                    _MetricCard(label: '갤러리 항목', value: '$gallery'),
                    _MetricCard(label: '공지', value: '$announcements'),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildMyUnavailabilityCard(controller),
        const SizedBox(height: 12),
        _AnnouncementCard(controller: controller),
        const SizedBox(height: 12),
        _ActivityTimelineCard(controller: controller),
      ],
    );
  }

  Widget _buildMyUnavailabilityCard(NestController controller) {
    final currentUserId = controller.user?.id;
    final blocks =
        controller.memberUnavailabilityBlocks
            .where(
              (row) =>
                  row.ownerKind == 'MEMBER_USER' &&
                  currentUserId != null &&
                  row.ownerId == currentUserId,
            )
            .toList(growable: false)
          ..sort((a, b) {
            final day = a.dayOfWeek.compareTo(b.dayOfWeek);
            if (day != 0) {
              return day;
            }
            return a.startTime.compareTo(b.startTime);
          });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('내 불가 시간', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '등록한 불가 시간은 관리자 시간표 초안 생성 시 자동 회피됩니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            if (currentUserId == null)
              const Text('로그인 정보를 확인할 수 없습니다.')
            else ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _selectedUnavailabilityDay,
                      decoration: const InputDecoration(labelText: '요일'),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('Sun')),
                        DropdownMenuItem(value: 1, child: Text('Mon')),
                        DropdownMenuItem(value: 2, child: Text('Tue')),
                        DropdownMenuItem(value: 3, child: Text('Wed')),
                        DropdownMenuItem(value: 4, child: Text('Thu')),
                        DropdownMenuItem(value: 5, child: Text('Fri')),
                        DropdownMenuItem(value: 6, child: Text('Sat')),
                      ],
                      onChanged: controller.isBusy
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }
                              setState(() {
                                _selectedUnavailabilityDay = value;
                              });
                            },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _unavailabilityStartController,
                      decoration: const InputDecoration(
                        labelText: '시작 (HH:MM)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _unavailabilityEndController,
                      decoration: const InputDecoration(
                        labelText: '종료 (HH:MM)',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _unavailabilityNoteController,
                decoration: const InputDecoration(labelText: '메모 (선택)'),
                minLines: 1,
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () => _createParentUnavailabilityBlock(currentUserId),
                icon: const Icon(Icons.block),
                label: const Text('불가 시간 추가'),
              ),
              const SizedBox(height: 10),
              Text('등록된 항목', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              if (blocks.isEmpty)
                const Text('등록된 불가 시간이 없습니다.')
              else
                ...blocks.map((block) {
                  final day = _dayLabel(block.dayOfWeek);
                  final start = _shortTime(block.startTime);
                  final end = _shortTime(block.endTime);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: NestColors.roseMist),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '$day $start-$end${block.note.trim().isEmpty ? '' : ' · ${block.note.trim()}'}',
                            ),
                          ),
                          IconButton(
                            onPressed: controller.isBusy
                                ? null
                                : () => _deleteUnavailabilityBlock(block.id),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _createParentUnavailabilityBlock(String userId) async {
    try {
      await widget.controller.createMemberUnavailabilityBlock(
        ownerKind: 'MEMBER_USER',
        ownerId: userId,
        dayOfWeek: _selectedUnavailabilityDay,
        startTime: _unavailabilityStartController.text,
        endTime: _unavailabilityEndController.text,
        note: _unavailabilityNoteController.text,
      );
      _unavailabilityNoteController.clear();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _deleteUnavailabilityBlock(String blockId) async {
    try {
      await widget.controller.deleteMemberUnavailabilityBlock(blockId: blockId);
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  String _dayLabel(int dayOfWeek) {
    const labels = <int, String>{
      0: 'Sun',
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
    };
    return labels[dayOfWeek] ?? '$dayOfWeek';
  }

  String _shortTime(String value) {
    final parsed = DateFormat('HH:mm:ss').tryParse(value);
    if (parsed == null) {
      final fallback = DateFormat('HH:mm').tryParse(value);
      return fallback == null ? value : DateFormat('HH:mm').format(fallback);
    }
    return DateFormat('HH:mm').format(parsed);
  }

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('공지', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (controller.announcements.isEmpty)
              const Text('등록된 공지가 없습니다.')
            else
              ...controller.announcements.take(20).map((row) {
                final when = row.createdAt == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt!);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NestColors.roseMist),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (row.pinned) const Chip(label: Text('PINNED')),
                            Chip(
                              label: Text(
                                row.classGroupId == null
                                    ? '전체'
                                    : controller.findClassGroupName(
                                        row.classGroupId,
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          row.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(row.body),
                        const SizedBox(height: 4),
                        Text(
                          when,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ActivityTimelineCard extends StatelessWidget {
  const _ActivityTimelineCard({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final logs = controller.studentActivityLogs.toList(growable: false)
      ..sort((a, b) {
        final left = a.recordedAt?.millisecondsSinceEpoch ?? 0;
        final right = b.recordedAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('아동 활동 기록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              const Text('등록된 활동 기록이 없습니다.')
            else
              ...logs.take(40).map((log) {
                final childName =
                    controller.children
                        .where((child) => child.id == log.childId)
                        .map((child) => child.name)
                        .firstOrNull ??
                    log.childId;
                final when = log.recordedAt == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd HH:mm').format(log.recordedAt!);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('$childName · ${log.activityType}'),
                  subtitle: Text(log.content),
                  trailing: Text(
                    when,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
