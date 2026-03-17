import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';
import '../widgets/nest_empty_state.dart';

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
              Text('운영', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('운영 탭은 관리자/스태프 전용입니다.'),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        _buildAnnouncementSection(controller),
        const SizedBox(height: 12),
        _buildAuditLogSection(controller),
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

  void _openComposerModal(NestController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
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

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '공지 작성',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
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
                    autofocus: true,
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
                              _targetClassGroupId =
                                  next == '__ALL__' ? null : next;
                            });
                            setModalState(() {});
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
                        : (val) {
                            setState(() => _pinned = val);
                            setModalState(() {});
                          },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: controller.isBusy
                            ? null
                            : () async {
                                final navigator = Navigator.of(ctx);
                                await _createAnnouncement();
                                if (mounted) navigator.pop();
                              },
                        icon: const Icon(Icons.campaign),
                        label: const Text('공지 게시'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.tonalIcon(
                        onPressed: controller.isBusy
                            ? null
                            : () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('취소'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnnouncementSection(NestController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '공지 목록',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            FilledButton.icon(
              onPressed:
                  controller.isBusy ? null : () => _openComposerModal(controller),
              icon: const Icon(Icons.campaign, size: 18),
              label: const Text('공지 작성'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: controller.isBusy ? null : _reloadOps,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('새로고침'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (controller.announcements.isEmpty)
          const NestEmptyState(
            icon: Icons.campaign_outlined,
            title: '등록된 공지가 없습니다.',
          )
        else
          ...controller.announcements.map((row) {
            final timeText = row.createdAt == null
                ? '-'
                : DateFormat('yyyy-MM-dd HH:mm').format(row.createdAt!);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NestColors.roseMist),
                ),
                child: Row(
                  children: [
                    if (row.pinned)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Icon(
                          Icons.push_pin,
                          size: 16,
                          color: NestColors.dustyRose,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            row.title,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '$timeText · ${row.classGroupId == null ? '전체' : controller.findClassGroupName(row.classGroupId)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (row.pinned)
                      const Chip(
                        label: Text('고정'),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildAuditLogSection(NestController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('감사 로그', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        if (controller.auditLogs.isEmpty)
          const NestEmptyState(
            icon: Icons.assignment_outlined,
            title: '기록된 감사 로그가 없습니다.',
          )
        else
          ...controller.auditLogs.take(120).map((log) {
            final timeText = log.createdAt == null
                ? '-'
                : DateFormat('MM-dd HH:mm').format(log.createdAt!);
            return InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => _showAuditLogDetail(log),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: NestColors.roseMist.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        timeText,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: NestColors.roseMist,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        log.actionType,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        log.resourceType,
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: NestColors.deepWood.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showAuditLogDetail(dynamic log) {
    final timeText = log.createdAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm:ss').format(log.createdAt!);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${log.actionType} · ${log.resourceType}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('작업', log.actionType),
            _detailRow('대상 유형', log.resourceType),
            _detailRow('대상 ID', log.resourceId),
            _detailRow('시간', timeText),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: NestColors.deepWood.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: NestColors.deepWood)),
          ),
        ],
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
