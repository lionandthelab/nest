import 'package:flutter/material.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

/// Google Drive 연결 카드(관리자 전용).
///
/// 관리자 홈에서는 자주 쓰지 않는 설정이라 기본으로 접혀 있고, 펼치면 루트 폴더
/// 지정과 연결/재연결을 할 수 있다.
class DriveIntegrationCard extends StatefulWidget {
  const DriveIntegrationCard({
    super.key,
    required this.controller,
    this.initiallyExpanded = false,
  });

  final NestController controller;
  final bool initiallyExpanded;

  @override
  State<DriveIntegrationCard> createState() => _DriveIntegrationCardState();
}

class _DriveIntegrationCardState extends State<DriveIntegrationCard> {
  final _rootFolderController = TextEditingController();
  bool _connecting = false;
  late bool _expanded = widget.initiallyExpanded;

  @override
  void initState() {
    super.initState();
    _rootFolderController.text =
        widget.controller.driveIntegration?.rootFolderId ?? '';
  }

  @override
  void dispose() {
    _rootFolderController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _connecting = true);
    final error = await widget.controller.connectGoogleDrive(
      rootFolderId: _rootFolderController.text,
    );
    if (!mounted) return;
    setState(() => _connecting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Google Drive가 연결되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = widget.controller;
    final integration = controller.driveIntegration;
    final connected = integration?.isConnected ?? false;
    final email = integration?.googleEmail;
    final supported = controller.isWebOauthSupported;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  const Icon(Icons.add_to_drive, color: NestColors.dustyRose),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Google Drive 연결',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (controller.isLoadingDriveIntegration)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Chip(
                      label: Text(connected ? '연결됨' : '미연결'),
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(
                        connected ? Icons.check_circle : Icons.cloud_off,
                        size: 16,
                        color: connected
                            ? NestColors.mutedSage
                            : NestColors.deepWood.withValues(alpha: 0.4),
                      ),
                    ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.expand_more),
                  ),
                ],
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !_expanded
                  ? const SizedBox(width: double.infinity)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 10),
                        Text(
                          connected
                              ? '연결됨: ${email != null && email.isNotEmpty ? email : '연결됨'}\n'
                                    '갤러리·커뮤니티에 올린 사진·영상이 Google Drive에도 함께 저장됩니다.'
                              : '연결하면 갤러리·커뮤니티에 올린 사진·영상이 Google Drive에도 함께 저장됩니다.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: NestColors.deepWood.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _rootFolderController,
                          decoration: const InputDecoration(
                            labelText: '루트 폴더 ID (선택)',
                            hintText: '비워두면 Drive 최상위에 저장됩니다.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (!supported)
                          Text(
                            '웹에서 연결할 수 있어요.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: NestColors.deepWood.withValues(alpha: 0.5),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _connecting ? null : _connect,
                              icon: _connecting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.link, size: 18),
                              label: Text(connected ? '다시 연결' : '연결하기'),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
