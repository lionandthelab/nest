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
  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    if (!controller.isAdminLike) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('운영 로그', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              const Text('운영 로그는 관리자/스태프 전용입니다.'),
            ],
          ),
        ),
      );
    }

    return ListView(
      children: [
        _buildAuditLogSection(controller),
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

}
