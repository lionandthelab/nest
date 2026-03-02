import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../state/nest_controller.dart';
import '../nest_theme.dart';

class DriveTab extends StatefulWidget {
  const DriveTab({super.key, required this.controller});

  final NestController controller;

  @override
  State<DriveTab> createState() => _DriveTabState();
}

class _DriveTabState extends State<DriveTab> {
  final _rootFolderController = TextEditingController();
  final _accessTokenController = TextEditingController();
  final _refreshTokenController = TextEditingController();
  final _tokenExpiresAtController = TextEditingController();

  String _folderPolicy = 'TERM_CLASS_DATE';
  String? _lastSyncIntegrationId;

  @override
  void dispose() {
    _rootFolderController.dispose();
    _accessTokenController.dispose();
    _refreshTokenController.dispose();
    _tokenExpiresAtController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncFromController();

    final controller = widget.controller;

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Google Drive Integration',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  'OAuth 팝업과 수동 설정을 모두 지원합니다. 웹에서는 팝업 인증 후 동기화 버튼을 눌러 결과를 반영하세요.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: NestColors.deepWood.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.isBusy ? null : _startOauth,
                      icon: const Icon(Icons.link),
                      label: const Text('OAuth 시작'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy ? null : _syncOauth,
                      icon: const Icon(Icons.sync),
                      label: const Text('OAuth 동기화'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy ? null : _reloadDrive,
                      icon: const Icon(Icons.refresh),
                      label: const Text('상태 갱신'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _rootFolderController,
                  decoration: const InputDecoration(
                    labelText: 'Google Drive Root Folder ID',
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _folderPolicy,
                  decoration: const InputDecoration(labelText: 'Folder Policy'),
                  items: const [
                    DropdownMenuItem(
                      value: 'TERM_CLASS_DATE',
                      child: Text('TERM_CLASS_DATE'),
                    ),
                    DropdownMenuItem(
                      value: 'CLASS_CHILD_DATE',
                      child: Text('CLASS_CHILD_DATE'),
                    ),
                  ],
                  onChanged: controller.isBusy
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _folderPolicy = value;
                          });
                        },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _accessTokenController,
                  decoration: const InputDecoration(
                    labelText: 'Access Token (선택)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _refreshTokenController,
                  decoration: const InputDecoration(
                    labelText: 'Refresh Token (선택)',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _tokenExpiresAtController,
                  decoration: const InputDecoration(
                    labelText: 'Token Expires At ISO (선택)',
                    hintText: '2026-03-02T19:00:00Z',
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: controller.isBusy ? null : _saveSettings,
                      icon: const Icon(Icons.save),
                      label: const Text('설정 저장'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: controller.isBusy ? null : _disconnect,
                      icon: const Icon(Icons.link_off),
                      label: const Text('연동 해제'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('연동 상태', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                if (controller.driveIntegration == null)
                  const Text('연동 정보 없음')
                else
                  _DriveStatusView(controller: controller),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _syncFromController() {
    final integration = widget.controller.driveIntegration;
    if (integration == null) {
      return;
    }

    final shouldSync = _lastSyncIntegrationId != integration.id;
    if (!shouldSync) {
      return;
    }

    _lastSyncIntegrationId = integration.id;
    _rootFolderController.text = integration.rootFolderId ?? '';
    _folderPolicy = integration.folderPolicy ?? 'TERM_CLASS_DATE';
    _accessTokenController.text = integration.googleAccessToken ?? '';
    _refreshTokenController.text = integration.googleRefreshToken ?? '';

    if (integration.googleTokenExpiresAt != null) {
      _tokenExpiresAtController.text = integration.googleTokenExpiresAt!
          .toUtc()
          .toIso8601String();
    } else {
      _tokenExpiresAtController.text = '';
    }
  }

  Future<void> _startOauth() async {
    try {
      await widget.controller.startDriveOauth(
        rootFolderId: _rootFolderController.text,
        folderPolicy: _folderPolicy,
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _syncOauth() async {
    try {
      await widget.controller.syncOauthResult();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _reloadDrive() async {
    try {
      await widget.controller.loadDriveIntegration();
      _showMessage('Drive 상태를 갱신했습니다.');
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _saveSettings() async {
    try {
      await widget.controller.saveDriveSettings(
        rootFolderId: _rootFolderController.text,
        folderPolicy: _folderPolicy,
        accessToken: _accessTokenController.text,
        refreshToken: _refreshTokenController.text,
        tokenExpiresAt: _tokenExpiresAtController.text,
      );
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  Future<void> _disconnect() async {
    try {
      await widget.controller.disconnectDrive();
      _showMessage(widget.controller.statusMessage);
    } catch (_) {
      _showMessage(widget.controller.statusMessage);
    }
  }

  void _showMessage(String text) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _DriveStatusView extends StatelessWidget {
  const _DriveStatusView({required this.controller});

  final NestController controller;

  @override
  Widget build(BuildContext context) {
    final integration = controller.driveIntegration;
    if (integration == null) {
      return const SizedBox.shrink();
    }

    final connectedAt = integration.connectedAt == null
        ? '-'
        : DateFormat('yyyy-MM-dd HH:mm').format(integration.connectedAt!);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: NestColors.roseMist),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('상태: ${integration.status}'),
          const SizedBox(height: 4),
          Text('Root Folder: ${integration.rootFolderId ?? '-'}'),
          const SizedBox(height: 4),
          Text('Folder Policy: ${integration.folderPolicy ?? '-'}'),
          const SizedBox(height: 4),
          Text('Connected At: $connectedAt'),
          const SizedBox(height: 4),
          Text('Access Token: ${integration.hasAccessToken ? '있음' : '없음'}'),
          const SizedBox(height: 4),
          Text('Refresh Token: ${integration.hasRefreshToken ? '있음' : '없음'}'),
          if (integration.googleTokenExpiresAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Token Expires: ${integration.googleTokenExpiresAt!.toUtc().toIso8601String()}',
              ),
            ),
        ],
      ),
    );
  }
}
