import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class OpsTab extends StatefulWidget {
  const OpsTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<OpsTab> createState() => _OpsTabState();
}

class _OpsTabState extends State<OpsTab> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _pinned = false;
  String? _targetClassGroupId;
  bool _targetClassInitialized = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    _syncClassTarget(controller);

    if (!controller.isAdminLike) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Operations', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('운영 탭은 관리자/스태프 전용입니다.'),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        _buildAnnouncementComposer(controller),
        const SizedBox(height: 12),
        _buildAnnouncementList(controller),
        const SizedBox(height: 12),
        _buildAuditLogList(controller),
      ],
    );
  }

  void _syncClassTarget(NestController controller) {
    final classIds = controller.classGroups.map((row) => row.id).toSet();
    if (!_targetClassInitialized) {
      _targetClassGroupId = controller.selectedClassGroupId;
      _targetClassInitialized = true;
      return;
    }

    if (_targetClassGroupId != null &&
        !classIds.contains(_targetClassGroupId)) {
      _targetClassGroupId = controller.selectedClassGroupId;
    }
  }

  Widget _buildAnnouncementComposer(NestController controller) {
    final classItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: '__ALL__', child: Text('전체 공지')),
      ...controller.classGroups.map(
        (group) => DropdownMenuItem(
          value: group.id,
          child: Text('반 공지 · ${group.name}'),
        ),
      ),
    ];
    final value = _targetClassGroupId ?? '__ALL__';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('공지 작성', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '학부모/교사에게 공유할 운영 공지를 반 단위 또는 전체로 게시합니다.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: NestColors.deepWood.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '공지 제목'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _bodyController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: '공지 본문'),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              key: ValueKey(value),
              initialValue: value,
              decoration: const InputDecoration(labelText: '공지 범위'),
              items: classItems,
              onChanged: controller.isBusy
                  ? null
                  : (next) {
                      setState(() {
                        _targetClassGroupId = next == '__ALL__' ? null : next;
                      });
                    },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: _pinned,
              title: const Text('상단 고정'),
              onChanged: controller.isBusy
                  ? null
                  : (value) {
                      setState(() {
                        _pinned = value;
                      });
                    },
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: controller.isBusy ? null : _createAnnouncement,
                  icon: const Icon(Icons.campaign),
                  label: const Text('공지 게시'),
                ),
                FilledButton.tonalIcon(
                  onPressed: controller.isBusy ? null : _reloadOps,
                  icon: const Icon(Icons.refresh),
                  label: const Text('운영 데이터 새로고침'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementList(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('공지 목록', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (controller.announcements.isEmpty)
              const Text('등록된 공지가 없습니다.')
            else
              ...controller.announcements.map((row) {
                final timeText = row.createdAt == null
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
                        const SizedBox(height: 6),
                        Text(
                          timeText,
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

  Widget _buildAuditLogList(NestController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('감사 로그', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (controller.auditLogs.isEmpty)
              const Text('기록된 감사 로그가 없습니다.')
            else
              ...controller.auditLogs.take(120).map((log) {
                final timeText = log.createdAt == null
                    ? '-'
                    : DateFormat('yyyy-MM-dd HH:mm:ss').format(log.createdAt!);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: NestColors.roseMist),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${log.actionType} · ${log.resourceType}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text('resource: ${log.resourceId}'),
                        const SizedBox(height: 2),
                        Text(
                          timeText,
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

  Future<void> _createAnnouncement() async {
    try {
      await widget.controller.createAnnouncement(
        title: _titleController.text,
        body: _bodyController.text,
        classGroupId: _targetClassGroupId,
        pinned: _pinned,
      );
      _titleController.clear();
      _bodyController.clear();
      setState(() {
        _pinned = false;
      });
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _reloadOps() async {
    try {
      await widget.controller.loadAnnouncements();
      await widget.controller.loadAuditLogs();
      _showMessage('공지/감사로그를 새로고침했습니다.');
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  void _showMessage(String text) {
    if (!mounted || text.isEmpty) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
