import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/hub_scaffold.dart';

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
  String _sectionId = 'overview';

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

    return HubScaffold(
      title: 'Parent Hub',
      subtitle: '아이의 일정과 공지를 빠르게 확인하고, 참여 불가 시간을 간단히 관리합니다.',
      icon: Icons.family_restroom,
      isBusy: controller.isBusy,
      metrics: [
        HubMetric(
          label: '이번 학기 수업',
          value: '${controller.sessions.length}',
          icon: Icons.view_week,
        ),
        HubMetric(
          label: '공지',
          value: '${controller.announcements.length}',
          icon: Icons.campaign,
        ),
        HubMetric(
          label: '활동 기록',
          value: '${controller.studentActivityLogs.length}',
          icon: Icons.history_edu,
        ),
      ],
      sections: [
        HubSection(
          id: 'overview',
          label: '개요',
          icon: Icons.home_outlined,
          content: Column(
            children: [
              _buildAnnouncementCard(controller),
              const SizedBox(height: 12),
              _buildRecentActivityCard(controller),
            ],
          ),
        ),
        HubSection(
          id: 'availability',
          label: '내 불가 시간',
          icon: Icons.block,
          content: _buildMyUnavailabilityCard(controller),
        ),
        HubSection(
          id: 'timeline',
          label: '활동 타임라인',
          icon: Icons.timeline,
          content: _buildActivityTimelineCard(controller),
        ),
      ],
      selectedSectionId: _sectionId,
      onSelectSection: (value) {
        setState(() {
          _sectionId = value;
        });
      },
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
            Text('내 불가 시간 설정', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '등록된 시간은 시간표 생성 시 자동으로 피해서 배정됩니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 12),
            if (currentUserId == null)
              const Text('로그인 정보를 확인할 수 없습니다.')
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 740;
                  if (compact) {
                    return Column(
                      children: [
                        _buildDayField(controller),
                        const SizedBox(height: 8),
                        _buildTimeField(
                          controller: _unavailabilityStartController,
                          label: '시작 (HH:MM)',
                        ),
                        const SizedBox(height: 8),
                        _buildTimeField(
                          controller: _unavailabilityEndController,
                          label: '종료 (HH:MM)',
                        ),
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(flex: 3, child: _buildDayField(controller)),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildTimeField(
                          controller: _unavailabilityStartController,
                          label: '시작 (HH:MM)',
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: _buildTimeField(
                          controller: _unavailabilityEndController,
                          label: '종료 (HH:MM)',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _unavailabilityNoteController,
                decoration: const InputDecoration(
                  labelText: '메모 (선택)',
                  prefixIcon: Icon(Icons.edit_note),
                ),
                minLines: 1,
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: controller.isBusy
                    ? null
                    : () => _createParentUnavailabilityBlock(currentUserId),
                icon: const Icon(Icons.add),
                label: const Text('불가 시간 추가'),
              ),
            ],
            const SizedBox(height: 14),
            Text('등록 항목', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (blocks.isEmpty)
              _buildEmptyHint('등록된 불가 시간이 없습니다.')
            else
              ...blocks.map((block) {
                final day = _dayLabel(block.dayOfWeek);
                final start = _shortTime(block.startTime);
                final end = _shortTime(block.endTime);
                final note = block.note.trim();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NestColors.roseMist),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.schedule),
                      title: Text('$day · $start - $end'),
                      subtitle: note.isEmpty ? null : Text(note),
                      trailing: IconButton(
                        onPressed: controller.isBusy
                            ? null
                            : () => _deleteUnavailabilityBlock(block.id),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildDayField(NestController controller) {
    return DropdownButtonFormField<int>(
      initialValue: _selectedUnavailabilityDay,
      decoration: const InputDecoration(
        labelText: '요일',
        prefixIcon: Icon(Icons.calendar_today_outlined),
      ),
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
    );
  }

  Widget _buildTimeField({
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.access_time),
      ),
    );
  }

  Widget _buildAnnouncementCard(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('최근 공지', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (controller.announcements.isEmpty)
              _buildEmptyHint('등록된 공지가 없습니다.')
            else
              ...controller.announcements.take(8).map((row) {
                final when = row.createdAt == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt!);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
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
                                    : widget.controller.findClassGroupName(
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

  Widget _buildRecentActivityCard(NestController controller) {
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
            Text('최근 활동 요약', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              _buildEmptyHint('최근 활동 기록이 없습니다.')
            else
              ...logs.take(6).map((log) {
                final childName =
                    controller.children
                        .where((child) => child.id == log.childId)
                        .map((child) => child.name)
                        .firstOrNull ??
                    log.childId;
                final when = log.recordedAt == null
                    ? '-'
                    : DateFormat('MM-dd HH:mm').format(log.recordedAt!);
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle_outline, size: 18),
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

  Widget _buildActivityTimelineCard(NestController controller) {
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
            Text('아동 활동 타임라인', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              _buildEmptyHint('등록된 활동 기록이 없습니다.')
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
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NestColors.roseMist),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.brightness_1, size: 10),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$childName · ${log.activityType}',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 3),
                              Text(log.content),
                              const SizedBox(height: 4),
                              Text(
                                when,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
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

  Widget _buildEmptyHint(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: NestColors.roseMist.withValues(alpha: 0.36),
      ),
      child: Text(message),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
